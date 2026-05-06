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

## Setup

### Step 1 — n8n

**Option A: Self-hosted via Docker (used in this project)**
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```
Then open `http://localhost:5678` in your browser.

**Option B: n8n Cloud (no Docker required)**
Create a free account at [n8n.io](https://n8n.io). The workflow imports and runs the same way — the only difference is the webhook URL will be a public cloud URL instead of `localhost:5678`.

---

### Step 2 — OpenAI API Key

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys) and create a new secret key
2. In n8n, go to **Settings → Credentials → Add Credential → OpenAI**
3. Paste your API key and save
4. The workflow uses `gpt-4o-mini` — make sure your account has access to it (available on all paid tiers)

---

### Step 3 — Google Sheets (Service Account)

OAuth2 was not used because it requires a public redirect URI, which is not available when running n8n on localhost. A Service Account has no such requirement and works in both local and cloud environments.

**3a. Create a Google Cloud project and enable APIs**
1. Go to [console.cloud.google.com](https://console.cloud.google.com) and create a new project
2. In the left menu go to **APIs & Services → Library**
3. Search for and enable **Google Sheets API**
4. Search for and enable **Google Drive API** (required by n8n to list and access spreadsheets)

**3b. Create a Service Account**
1. Go to **APIs & Services → Credentials → Create Credentials → Service Account**
2. Give it a name (e.g. `n8n-sheets`) and click Create
3. No special roles needed — click Done
4. Click on the service account you just created → **Keys → Add Key → Create new key → JSON**
5. Download the JSON key file — keep it safe

**3c. Add the credential in n8n**
1. In n8n go to **Settings → Credentials → Add Credential → Google Sheets (Service Account)**
2. Open the downloaded JSON key file and copy-paste:
   - `client_email` → into the Email field
   - `private_key` → into the Private Key field
3. Save the credential

**3d. Share your Google Sheet with the Service Account**
1. Open your Google Sheet
2. Click **Share**
3. Paste the `client_email` from your JSON key file (looks like `name@project.iam.gserviceaccount.com`)
4. Set permission to **Editor** and click Send

---

### Step 4 — Google Sheet setup

Create a new Google Sheet with two tabs named exactly:
- `main_queue`
- `escalation_queue`

Add these column headers in row 1 of **both tabs** (order matters):

```
ticket_id | received_at | source | category | priority | confidence | escalation_flag | escalation_reason | routing_destination | core_issue | summary | account_id | invoice_number | error_code | amount_usd | affected_users
```

Copy the Sheet ID from the URL — it is the long string between `/d/` and `/edit` in the browser address bar:
```
https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID_HERE/edit
```
Paste this ID into both Google Sheets nodes in the workflow.

---

## Sample inputs

Five synthetic messages are included in `samples.sh`, each designed to test a specific path through the workflow:

| # | Source | Category | Purpose |
|---|--------|----------|---------|
| 1 | Email | Bug Report | Tests clean routing — high confidence, single user blocked, no escalation triggers. Routes to Engineering. |
| 2 | Web Form | Feature Request | Tests low-priority path — no urgency, no entities to extract, no escalation. Routes to Product. |
| 3 | Support Portal | Billing Issue | Tests billing escalation — invoice number and dollar amount extracted, $1,240 exceeds the $500 threshold. Routes to Escalation. |
| 4 | Email | Technical Question | Tests pre-sales/evaluation path — capability question, no broken behavior, no urgency. Routes to IT/Security. |
| 5 | Web Form | Incident/Outage | Tests keyword escalation — "multiple users affected" triggers the regex rule regardless of confidence. Routes to Escalation. |

Samples 3 and 5 are intentionally designed to hit different escalation triggers so both reasons appear in the escalation queue.

---

## Running the workflow

1. Import `My_workflow.json` into n8n (top right menu → **Import from file**)
2. Attach your OpenAI credential to the **Message a model** node
3. Attach your Google Sheets credential to both **Append row** nodes
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

- `My_workflow.json` — n8n workflow export
- `Prompts.md` — system prompt + design reasoning
- `architecture.md` — system design write-up
- `samples.sh` — 5 sample inputs to test the pipeline
- `Outputs.json` — processed results for all 5 samples
- Google Sheet: [[link](https://docs.google.com/spreadsheets/d/1iRZAXvvScl0IBaWZElzWK5e7Fbx8PdDrLlp-0-qTQUg/edit?usp=sharing)]
- Loom recording: [link]