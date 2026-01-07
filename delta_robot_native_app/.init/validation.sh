#!/usr/bin/env bash
set -euo pipefail
# Validation: start, stop, and record evidence
WORKSPACE="/home/kavia/workspace/code-generation/delta-robotics-script-generator-21-30/delta_robot_native_app"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "error: venv python not found" >&2; exit 12; }
EVIDENCE_FILE="$WORKSPACE/validation_evidence.json"
ENV_MIN="DEBIAN_FRONTEND=noninteractive"
OUT_FILE=$(mktemp -p "$WORKSPACE" out.XXXXXX)
ERR_FILE=$(mktemp -p "$WORKSPACE" err.XXXXXX)
# Ensure temp files are removed on exit
trap 'rm -f "$OUT_FILE" "$ERR_FILE"' EXIT
# Run start.sh capturing stdout and stderr; preserve RC
bash -lc "$ENV_MIN ./start.sh" >"$OUT_FILE" 2>"$ERR_FILE" || RC=$?; RC=${RC:-0}
# Check exit code
if [ "$RC" -ne 0 ]; then
  echo "error: start.sh exited non-zero: $RC" >&2
  echo "--- stderr ---" >&2; sed -n '1,200p' "$ERR_FILE" >&2 || true
  echo "--- stdout ---" >&2; sed -n '1,200p' "$OUT_FILE" >&2 || true
  exit 13
fi
# Select last non-empty stdout line
LINE=$(awk 'NF{line=$0} END{print line}' "$OUT_FILE" || true)
if [ -z "${LINE:-}" ]; then
  echo "error: no stdout captured from start.sh" >&2; sed -n '1,200p' "$ERR_FILE" >&2 || true; exit 14
fi
case "$LINE" in
  '{'* ) ;;
  * ) echo "error: last line not JSON-like: $LINE" >&2; sed -n '1,200p' "$ERR_FILE" >&2 || true; exit 15 ;;
esac
# Parse and write evidence using venv python; pass EVIDENCE_FILE via env to avoid heredoc expansion issues
printf "%s" "$LINE" | EVIDENCE_FILE="$EVIDENCE_FILE" "$VENV_PY" - <<'PY'
import os, sys, json
ef = os.environ.get('EVIDENCE_FILE')
if not ef:
    print('validation_failed: EVIDENCE_FILE not set', file=sys.stderr); sys.exit(4)
try:
    obj = json.load(sys.stdin)
except Exception:
    print('validation_failed: output not valid JSON', file=sys.stderr); sys.exit(5)
if obj.get('status')!='ok':
    print('validation_failed: unexpected status', file=sys.stderr); sys.exit(6)
with open(ef,'w') as f:
    json.dump(obj, f)
print('validation_passed')
PY
# Confirm evidence file exists and is non-empty
[ -s "$EVIDENCE_FILE" ] || { echo "error: evidence file missing or empty" >&2; exit 16; }
echo "validation_passed: evidence=$EVIDENCE_FILE"
