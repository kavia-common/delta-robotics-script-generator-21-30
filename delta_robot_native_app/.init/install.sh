#!/usr/bin/env bash
set -euo pipefail
# Install minimal Python deps into project venv (upgrades pip/setuptools, installs requirements)
WORKSPACE="/home/kavia/workspace/code-generation/delta-robotics-script-generator-21-30/delta_robot_native_app"
cd "$WORKSPACE"
VENV_PIP="$WORKSPACE/.venv/bin/pip"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PIP" ] || { echo "error: venv pip not found" >&2; exit 6; }
# Ensure pip/setuptools are up-to-date for deterministic installs
"$VENV_PIP" install --upgrade pip setuptools --progress-bar off || { echo "error: pip/setuptools upgrade failed" >&2; exit 7; }
TMPLOG=$(mktemp -p "$WORKSPACE" piplog.XXXXXX)
trap 'rm -f "${TMPLOG}"' EXIT
if ! "$VENV_PIP" install --progress-bar off -r requirements.txt >"$TMPLOG" 2>&1; then
  echo "error: dependency installation failed. pip log (tail):" >&2
  tail -n 200 "$TMPLOG" >&2 || true
  exit 8
fi
# Verify installations using venv python with granular checks
"$VENV_PY" - <<'PY'
import sys
errs = []
try:
    import requests
except Exception:
    errs.append('requests')
try:
    import yaml
except Exception:
    errs.append('PyYAML (import name: yaml)')
try:
    import pytest
except Exception:
    errs.append('pytest')
if errs:
    print('error: missing packages: ' + ', '.join(errs), file=sys.stderr)
    sys.exit(9)
print('pkgs-ok')
PY
