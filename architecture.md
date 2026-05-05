# Architecture

## System Overview

The pipeline is a linear agentic workflow that takes an inbound support message, enriches it with LLM-based classification and extraction, applies deterministic escalation and routing rules, and writes the result to a structured queue. It is built in n8n (self-hosted) and uses GPT-4o-mini for the LLM step.

---

## Node-by-Node Design

### Webhook Trigger
Listens on `/webhook/intake` for HTTP POST requests. Any source system — an email parser, support portal, or form integration — posts a normalized payload here. The trigger is the only node that changes if the input source changes; everything downstream operates on the same internal contract.

### Set Node (Normalize)
Produces a clean 4-field object: `ticket_id`, `source`, `raw_message`, `received_at`. The `ticket_id` is generated here using timestamp + random suffix. Keeping normalization in its own node means the data contract for all downstream nodes is explicit and stable.

Note: column mapping in the Google Sheets nodes uses `{{ $json.ticket_id }}` referencing this node's output directly. An earlier version used `$('Edit Fields').item.json` by node name which caused the field to not appear in the variable picker — switching to `$json` resolved this.

### OpenAI Node (GPT-4o-mini)
Single combined call that returns classification, entity extraction, and summary in one JSON response. GPT-4o-mini was chosen over GPT-4o because this task — short-message classification and extraction — is well within mini's capability at roughly 20x lower cost. JSON mode is enabled to reduce malformed output.

### Code Node — Parse + Validate
Reads the LLM output from `$input.first().json.output[0].content[0].text` (the actual response path in n8n's OpenAI node output), parses the JSON, and validates that all required fields are present. On any failure — parse error or missing fields — the node sets `escalation_flag: true` and `escalation_reason: "parse failure"` so the record still flows through and lands in the escalation queue. Nothing is silently dropped.

### Code Node — Escalation Rules
Applies three escalation triggers independently:
- `confidence < 0.7` — catches ambiguous inputs the model itself flagged as uncertain
- keyword regex match on the raw message — catches outage and multi-user impact language even when the model classifies with high confidence
- `category === "Billing Issue" && amount_usd > 500` — catches high-dollar disputes

All three can fire on the same ticket; the `escalation_reason` field concatenates the reasons so reviewers know exactly why a ticket was flagged.

### Code Node — Routing
Maps category to destination using a simple lookup object. Runs after escalation so the `routing_destination` field reflects the actual queue — escalated tickets get `"Escalation"`, others get their team name. Keeping routing in a separate node from escalation means the two concerns are independently readable and testable.

### IF Node
Branches on `escalation_flag`. True → escalation_queue tab. False → main_queue tab. Single branch point keeps the graph clean.

### Google Sheets Nodes
One node per tab, identical column mapping. Both use Service Account credentials — OAuth2 is not viable for localhost n8n since Google requires a public redirect URI. Service Account has no such requirement.

---

## Key Design Decisions

**Single LLM call vs. chained calls.** One call handles classification, extraction, and summarization together. The tradeoff is that a parse failure loses all three outputs at once, but this is mitigated by the defensive parser routing failures to escalation. The benefits — lower cost, lower latency, internal consistency across outputs — outweigh this risk for the current scale.

**Deterministic routing vs. LLM-decided routing.** The routing map is a hardcoded lookup, not an LLM decision. This keeps classification and routing as separate concerns: if a ticket is misrouted, I can immediately tell whether the cause is a wrong category (LLM problem) or a wrong mapping (routing problem). LLM-decided routing conflates the two and makes debugging harder.

**Rules + confidence for escalation.** Confidence alone misses cases where the model is wrongly confident — a common LLM failure mode. Rules alone are brittle to natural language variation. Together they cover both: rules encode known business judgment, confidence catches everything else.

**Escalation as a queue, not a dead-letter box.** Escalated tickets land in a structured tab with the same schema as the main queue, plus `escalation_reason`. They're not lost or unprocessed — they're waiting for human review before being routed. This is an important operational distinction.

---

## What Changes at Production Scale

**Async ingestion.** The current webhook is synchronous — the caller waits for the full LLM round-trip. At volume, this creates backpressure and risk of dropped requests during spikes. Production architecture would separate ingestion (webhook writes to a queue) from processing (workers consume from the queue), giving proper retry semantics and horizontal scaling.

**Observability.** Every execution needs structured logging with a correlation ID so any ticket can be traced end-to-end. Current n8n execution logs are sufficient for a demo but not for a production support system where "why did this ticket go to the wrong team?" needs a clear answer.

**Prompt versioning and eval.** Changing the prompt changes the system's behavior across all future tickets. Production requires: version-controlled prompts, a labeled eval set, and automated scoring that runs before any prompt change is deployed. Without this, prompt improvements can silently regress other categories.

**Confidence calibration.** GPT-4o-mini's self-reported confidence scores are directionally useful but not well-calibrated — the model tends toward overconfidence. Before using the 0.7 threshold in production, I'd validate it against a labeled set: compare self-reported confidence to actual correctness, and adjust the threshold or apply a calibration function.

**Idempotency.** If the same webhook fires twice (network retry, upstream bug), the current workflow creates two records. Production needs an idempotency key — check if `ticket_id` already exists before writing.

---

## Phase 2 Ideas

- **Feedback loop:** when a human re-routes a misclassified ticket, log the disagreement as training signal. Periodically review for prompt improvements.
- **Semantic escalation:** replace keyword regex with a lightweight "is this an outage?" LLM check. More robust to language variation, easier to maintain.
- **Deduplication:** when multiple customers report the same issue in a short window, detect via message similarity and group as related tickets rather than creating independent records.
- **Cascade model routing:** mini for confident cases, larger model only for low-confidence ones. Captures most quality at a fraction of the cost.
- **Per-category SLA tracking:** time-to-first-response and time-to-resolution by category and priority, feeding back into routing priority over time.