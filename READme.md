# ArcVault Intake & Triage Pipeline

An agentic intake and triage workflow built for the Valsoft AI Engineer assessment. The pipeline automatically classifies, enriches, and routes inbound B2B support messages using n8n and GPT-4o-mini.

---

## What it does

When a support message arrives via webhook, the workflow:
1. Normalizes the input and generates a ticket ID
2. Sends the message to GPT-4o-mini which returns a structured JSON object: category, priority, confidence, entity extraction, and a summary written for the receiving team
3. Validates and parses the LLM output defensively — parse failures route to escalation automatically
4. Applies escalation rules (confidence threshold, keyword matching, billing amount)
5. Routes the ticket to the correct destination based on category
6. Writes the record to Google Sheets — main queue or escalation queue depending on the outcome

---

## Workflow

```
Webhook
  → Set (Normalize + ticket_id)
  → OpenAI gpt-4o-mini
  → Code (Parse + Validate)
  → Code (Escalation Rules)
  → Code (Routing)
  → IF (escalation_flag)
      ├── TRUE  → Google Sheets: escalation_queue
      └── FALSE → Google Sheets: main_queue
```

---

## Prerequisites

- Docker + n8n running at `localhost:5678`
- OpenAI API key (gpt-4o-mini)
- Google Cloud Service Account with Sheets API enabled
- Google Sheet with two tabs: `main_queue` and `escalation_queue`

---

## Running locally

1. Import `workflow.json` into n8n (top right menu → Import)
2. Add your OpenAI credential in n8n
3. Add your Google Sheets Service Account credential in n8n
4. Update the Google Sheet ID in both Sheets nodes
5. Activate the workflow (toggle top right → green)
6. Run the samples:

```bash
chmod +x samples.sh
./samples.sh
```

---

## Routing map

| Category | Destination |
|----------|-------------|
| Bug Report | Engineering |
| Feature Request | Product |
| Billing Issue | Billing |
| Technical Question | IT/Security |
| Incident/Outage | Engineering |

Escalation overrides routing when: confidence < 0.7, outage/multiple users keyword match, billing amount > $500, or JSON parse failure.

---

## Deliverables

- `workflow.json` — n8n workflow export
- `prompts.md` — system prompt + design reasoning
- `architecture.md` — system design write-up
- `samples.sh` — 5 sample inputs to test the pipeline
- `outputs.json` — processed results for all 5 samples
- Google Sheet: [link]
- Loom recording: [link]