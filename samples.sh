#!/bin/bash
WEBHOOK_URL="http://localhost:5678/webhook/intake"

echo "--- Sample 1: Bug Report ---"
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"source":"email","raw_message":"Hi, I tried logging in this morning and keep getting a 403 error. My account is arcvault.io/user/jsmith. This started after your update last Tuesday.","received_at":"2026-02-15T09:00:00Z"}'

echo ""
echo "--- Sample 2: Feature Request ---"
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"source":"web_form","raw_message":"We would love to see a bulk export feature for our audit logs. We are a compliance-heavy org and this would save us hours every month.","received_at":"2026-02-15T09:05:00Z"}'

echo ""
echo "--- Sample 3: Billing Issue ---"
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"source":"support_portal","raw_message":"Invoice #8821 shows a charge of $1,240 but our contract rate is $980/month. Can someone look into this?","received_at":"2026-02-15T09:10:00Z"}'

echo ""
echo "--- Sample 4: Technical Question ---"
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"source":"email","raw_message":"I am not sure if this is the right place to ask, but is there a way to set up SSO with Okta? We are evaluating switching our auth provider.","received_at":"2026-02-15T09:15:00Z"}'

echo ""
echo "--- Sample 5: Incident/Outage ---"
curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"source":"web_form","raw_message":"Your dashboard stopped loading for us around 2pm EST. Checked our end, it is definitely on yours. Multiple users affected.","received_at":"2026-02-15T09:20:00Z"}'

echo ""
echo "--- Done ---"