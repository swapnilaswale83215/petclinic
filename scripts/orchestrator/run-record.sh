#!/usr/bin/env bash
# run-record.sh — Forwarded-write failure counter and run-record reporter.
#
# This script is intended to be SOURCED by other orchestrator scripts:
#   source "${SCRIPT_DIR}/run-record.sh"
#
# It exposes two functions:
#   increment_forwarded_write_failure <reason>  — append a failure entry to the run record
#   finalize_run_record                         — write the final summary and print it
#
# The rehearsal pass/fail gate checks that forwarded_write_failures == 0.
#
# Run record schema:
#   {
#     "run_id": "<uuid>",
#     "forwarded_write_failures": N,
#     "failures": [
#       {"timestamp": "<ISO8601>", "reason": "<string>"}
#     ]
#   }
#
# Environment variables:
#   RUN_RECORD_FILE  Path to the JSON run record file (default: /tmp/orchestrator-run-record.json)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RUN_RECORD_FILE="${RUN_RECORD_FILE:-/tmp/orchestrator-run-record.json}"

# ---------------------------------------------------------------------------
# Initialise the run record if it does not already exist
# ---------------------------------------------------------------------------
_init_run_record() {
  if [[ ! -f "${RUN_RECORD_FILE}" ]]; then
    local run_id
    # Generate a simple run ID from timestamp + PID
    run_id="run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    printf '{"run_id":"%s","forwarded_write_failures":0,"failures":[]}\n' \
      "${run_id}" > "${RUN_RECORD_FILE}"
    echo "[run-record] Initialised run record: ${RUN_RECORD_FILE} (run_id=${run_id})"
  fi
}

# ---------------------------------------------------------------------------
# increment_forwarded_write_failure <reason>
#   Appends a failure entry to the run record and increments the counter.
# ---------------------------------------------------------------------------
increment_forwarded_write_failure() {
  local reason="${1:-unknown}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  _init_run_record

  # Read current state
  local current_count=0
  local current_failures="[]"
  if command -v python3 >/dev/null 2>&1; then
    current_count=$(python3 -c "
import json, sys
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('forwarded_write_failures', 0))
" 2>/dev/null || echo "0")
    current_failures=$(python3 -c "
import json, sys
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
import json
print(json.dumps(d.get('failures', [])))
" 2>/dev/null || echo "[]")
  fi

  local new_count=$(( current_count + 1 ))

  # Append the new failure entry and write back
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PYEOF
import json
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
d['forwarded_write_failures'] = d.get('forwarded_write_failures', 0) + 1
d.setdefault('failures', []).append({'timestamp': '${timestamp}', 'reason': '${reason}'})
with open('${RUN_RECORD_FILE}', 'w', encoding='utf-8') as f:
    json.dump(d, f)
PYEOF
  else
    # Fallback: overwrite with a minimal record (no python3 available)
    printf '{"run_id":"unknown","forwarded_write_failures":%d,"failures":[{"timestamp":"%s","reason":"%s"}]}\n' \
      "${new_count}" "${timestamp}" "${reason}" > "${RUN_RECORD_FILE}"
  fi

  echo "[run-record] Forwarded-write failure recorded (#${new_count}): ${reason}"
}

# ---------------------------------------------------------------------------
# finalize_run_record
#   Reads the run record, prints a summary, and returns exit code 1 if
#   forwarded_write_failures > 0 (rehearsal gate failure).
# ---------------------------------------------------------------------------
finalize_run_record() {
  _init_run_record

  local failure_count=0
  local run_id="unknown"

  if command -v python3 >/dev/null 2>&1; then
    failure_count=$(python3 -c "
import json
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('forwarded_write_failures', 0))
" 2>/dev/null || echo "0")
    run_id=$(python3 -c "
import json
with open('${RUN_RECORD_FILE}', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('run_id', 'unknown'))
" 2>/dev/null || echo "unknown")
  fi

  echo "[run-record] ===== Run Record Summary ====="
  echo "[run-record] Run ID: ${run_id}"
  echo "[run-record] Forwarded-write failures: ${failure_count}"
  echo "[run-record] Record file: ${RUN_RECORD_FILE}"

  if [[ "${failure_count}" -eq 0 ]]; then
    echo "[run-record] GATE PASS: forwarded_write_failures == 0"
    return 0
  else
    echo "ERROR: [run-record] GATE FAIL: forwarded_write_failures == ${failure_count} (rehearsal target is 0)" >&2
    return 1
  fi
}

# Initialise on source
_init_run_record
