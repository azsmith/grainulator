#!/bin/bash
#
# test-bridge.sh — Smoke-test the Grainulator conversational control bridge.
# Exercises session creation, state reads, action validation/scheduling,
# recording control, and history.
#
# Usage:   ./scripts/test-bridge.sh
# Expects: Grainulator running with bridge on 127.0.0.1:4850

set -euo pipefail

BASE="http://127.0.0.1:4850/v1"
PASS=0
FAIL=0
TOKEN=""
SESSION_ID=""

green()  { printf "\033[32m%s\033[0m\n" "$1"; }
red()    { printf "\033[31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }

assert_status() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    green "  PASS  $label (HTTP $actual)"
    PASS=$((PASS + 1))
  else
    red   "  FAIL  $label — expected $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_field() {
  local label="$1" body="$2" field="$3" expected="$4"
  local actual
  actual=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin)$field)" 2>/dev/null || echo "__MISSING__")
  if [ "$actual" = "$expected" ]; then
    green "  PASS  $label ($field = $actual)"
    PASS=$((PASS + 1))
  else
    red   "  FAIL  $label — $field expected '$expected', got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# ---- Connectivity ----
echo ""
echo "=== Grainulator Bridge Smoke Test ==="
echo ""

echo "1. Checking bridge reachability..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/sessions" \
  -H "Content-Type: application/json" \
  -d '{"client":{"name":"test","version":"0.1.0"},"requestedScopes":["state:read","control:write","recording:write"],"userLabel":"smoke test"}' 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "000" ]; then
  red "Bridge is not reachable at $BASE"
  red "Make sure Grainulator is running with the conversational control bridge enabled."
  exit 1
fi

# ---- Session ----
echo "2. Creating session..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/sessions" \
  -H "Content-Type: application/json" \
  -d '{"client":{"name":"test-bridge","version":"0.1.0"},"requestedScopes":["state:read","control:write","recording:write","scenes:write","files:read"],"userLabel":"smoke test"}')
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /sessions" 201 "$STATUS"

TOKEN=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null || echo "")
SESSION_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['sessionId'])" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
  red "Failed to extract session token. Aborting."
  exit 1
fi
green "  Session: $SESSION_ID"

AUTH="Authorization: Bearer $TOKEN"

# ---- Unauthorized request ----
echo "3. Verifying auth enforcement..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/state")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /state without auth" 401 "$STATUS"

# ---- Capabilities ----
echo "4. Reading capabilities..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/capabilities" -H "$AUTH")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /capabilities" 200 "$STATUS"

# ---- Parameters ----
echo "5. Reading parameters..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/parameters?module=granular" -H "$AUTH")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /parameters?module=granular" 200 "$STATUS"

# ---- Full State ----
echo "6. Reading full state..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/state" -H "$AUTH")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /state" 200 "$STATUS"
assert_json_field "State has schemaVersion" "$BODY" "['schemaVersion']" "0.1.0"

# ---- State Query ----
echo "7. Querying state paths..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/state/query" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"paths":["transport.playing","session.key","synth.plaits.mode","synth.daisydrum.mode","synth.daisydrum.harmonics"]}')
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /state/query" 200 "$STATUS"

# ---- Validate Actions ----
echo "8. Validating an action bundle..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/validate" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "bundle": {
      "bundleId": "test_bundle_001",
      "intentId": "test_intent_001",
      "atomic": true,
      "actions": [
        {"actionId":"a1","type":"set","target":"granular.voiceA.pitchSemitones","value":3.0}
      ]
    },
    "policy": {"maxRisk":"medium"}
  }')
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /actions/validate" 200 "$STATUS"

VALIDATION_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['validationId'])" 2>/dev/null || echo "")
IS_VALID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['valid'])" 2>/dev/null || echo "")
assert_json_field "Validation is valid" "$BODY" "['valid']" "True"

# ---- Schedule Actions ----
echo "9. Scheduling validated bundle..."
IDEMP_KEY=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_001\",
      \"intentId\": \"test_intent_001\",
      \"validationId\": \"$VALIDATION_ID\",
      \"atomic\": true,
      \"actions\": [
        {\"actionId\":\"a1\",\"type\":\"set\",\"target\":\"granular.voiceA.pitchSemitones\",\"value\":3.0}
      ]
    },
    \"applyMode\": \"validated_only\",
    \"idempotencyKey\": \"$IDEMP_KEY\"
  }")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /actions/schedule" 202 "$STATUS"

# ---- List Scheduled ----
echo "10. Listing scheduled actions..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/actions/scheduled" -H "$AUTH")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /actions/scheduled" 200 "$STATUS"

# ---- Best-effort schedule (transport toggle) ----
echo "11. Best-effort toggle transport..."
IDEMP_KEY2=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_002\",
      \"intentId\": \"test_intent_002\",
      \"atomic\": false,
      \"actions\": [
        {\"actionId\":\"a2\",\"type\":\"toggle\",\"target\":\"transport.playing\"}
      ]
    },
    \"applyMode\": \"best_effort\",
    \"idempotencyKey\": \"$IDEMP_KEY2\"
  }")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /actions/schedule (best_effort toggle)" 202 "$STATUS"

# Toggle back
sleep 0.2
IDEMP_KEY3=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
curl -s -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_003\",
      \"intentId\": \"test_intent_003\",
      \"atomic\": false,
      \"actions\": [
        {\"actionId\":\"a3\",\"type\":\"toggle\",\"target\":\"transport.playing\"}
      ]
    },
    \"applyMode\": \"best_effort\",
    \"idempotencyKey\": \"$IDEMP_KEY3\"
  }" > /dev/null

# ---- Recording Voices ----
echo "12. Listing recording voices..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/recording/voices" -H "$AUTH")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /recording/voices" 200 "$STATUS"

# ---- History ----
echo "13. Reading activity history..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE/history?limit=10" -H "$AUTH")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "GET /history" 200 "$STATUS"
assert_json_field "History has sessionId" "$BODY" "['sessionId']" "$SESSION_ID"

# ---- Idempotency replay ----
echo "14. Testing idempotency replay..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_001\",
      \"intentId\": \"test_intent_001\",
      \"validationId\": \"$VALIDATION_ID\",
      \"atomic\": true,
      \"actions\": [
        {\"actionId\":\"a1\",\"type\":\"set\",\"target\":\"granular.voiceA.pitchSemitones\",\"value\":3.0}
      ]
    },
    \"applyMode\": \"validated_only\",
    \"idempotencyKey\": \"$IDEMP_KEY\"
  }")
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "Idempotency replay" 200 "$STATUS"
assert_json_field "Idempotent flag set" "$BODY" "['idempotentReplay']" "True"

# ---- Validation errors ----
echo "15. Testing validation error (out of range)..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/validate" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "bundle": {
      "bundleId": "test_err_001",
      "intentId": "test_intent_err",
      "atomic": true,
      "actions": [
        {"actionId":"e1","type":"set","target":"granular.voiceA.pitchSemitones","value":50.0}
      ]
    }
  }')
BODY=$(echo "$RESPONSE" | sed '$d')
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "Validate out-of-range" 200 "$STATUS"
assert_json_field "Validation reports invalid" "$BODY" "['valid']" "False"

# ---- DaisyDrum mode change ----
echo "16. Testing DaisyDrum mode change..."
IDEMP_KEY4=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_004\",
      \"intentId\": \"test_intent_004\",
      \"atomic\": false,
      \"actions\": [
        {\"actionId\":\"a4\",\"type\":\"set\",\"target\":\"synth.daisydrum.mode\",\"value\":\"analog snare\"}
      ]
    },
    \"applyMode\": \"best_effort\",
    \"idempotencyKey\": \"$IDEMP_KEY4\"
  }")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /actions/schedule (daisydrum mode)" 202 "$STATUS"

echo "17. Testing DaisyDrum parameter set..."
IDEMP_KEY5=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/actions/schedule" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"bundle\": {
      \"bundleId\": \"test_bundle_005\",
      \"intentId\": \"test_intent_005\",
      \"atomic\": false,
      \"actions\": [
        {\"actionId\":\"a5\",\"type\":\"set\",\"target\":\"synth.daisydrum.timbre\",\"value\":0.7}
      ]
    },
    \"applyMode\": \"best_effort\",
    \"idempotencyKey\": \"$IDEMP_KEY5\"
  }")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "POST /actions/schedule (daisydrum timbre)" 202 "$STATUS"

# ---- Session cleanup ----
echo "18. Closing session..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/sessions/$SESSION_ID" -H "$AUTH")
STATUS=$(echo "$RESPONSE" | tail -1)
assert_status "DELETE /sessions/$SESSION_ID" 204 "$STATUS"

# ---- Summary ----
echo ""
echo "=== Results ==="
TOTAL=$((PASS + FAIL))
green "Passed: $PASS / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
  red "Failed: $FAIL / $TOTAL"
  exit 1
else
  green "All tests passed!"
fi
