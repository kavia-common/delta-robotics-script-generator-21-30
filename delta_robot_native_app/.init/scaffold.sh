#!/usr/bin/env bash
set -euo pipefail
# scaffold the minimal python project and deterministic venv
WORKSPACE="/home/kavia/workspace/code-generation/delta-robotics-script-generator-21-30/delta_robot_native_app"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
VENV_DIR="$WORKSPACE/.venv"
# Create venv if missing and upgrade pip/setuptools immediately to make deterministic
if [ ! -x "$VENV_DIR/bin/python" ]; then
  python3 -m venv "$VENV_DIR" || { echo "error: venv creation failed" >&2; exit 4; }
  # Use the venv's pip to upgrade pip and setuptools deterministically
  "$VENV_DIR/bin/pip" install --quiet --disable-pip-version-check --no-input --upgrade pip setuptools || { echo "error: pip/setuptools upgrade failed" >&2; exit 5; }
fi
VENV_PY="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"
# Minimal project layout
mkdir -p src tests
# generator with workspace-relative CONFIG_FILE resolution (src -> parents[1] => workspace root)
cat > src/generator.py <<'PY'
#!/usr/bin/env python3
import sys, json
from pathlib import Path
# CONFIG_FILE resolved relative to workspace root: src/ -> parents[1] points to workspace root
CONFIG_FILE = Path(__file__).resolve().parents[1] / 'config.yaml'

def load_config():
    try:
        import yaml
    except Exception:
        return {}
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return yaml.safe_load(f)
    return {}

def call_http(url):
    try:
        import requests
    except Exception:
        return None
    try:
        r = requests.get(url, timeout=1)
        return r.status_code
    except Exception:
        return None

def main():
    cfg = load_config()
    print(json.dumps({'status':'ok','cfg':cfg}))

if __name__=='__main__':
    main()
PY
chmod +x src/generator.py
# config and README
cat > config.yaml <<'YAML'
service:
  name: delta-generator
  timeout: 5
YAML
cat > README.md <<'TXT'
Minimal delta-robotics script generator scaffold. Note: requirements are intentionally minimal; consider pinning versions for CI reproducibility.
TXT
# Minimal requirements
cat > requirements.txt <<'TXT'
requests
PyYAML
pytest
TXT
# start script calls venv python explicitly and checks for venv at runtime
cat > start.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/delta-robotics-script-generator-21-30/delta_robot_native_app"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "error: venv python not found" >&2; exit 6; }
exec "$VENV_PY" "$WORKSPACE/src/generator.py"
BASH
chmod +x start.sh
# Ensure ownership when workspace exists but is owned by root (run sudo only when necessary)
if [ -d "$WORKSPACE" ]; then
  ws_uid=$(stat -c %u "$WORKSPACE") || true
  if [ "${ws_uid:-0}" -ne "$(id -u)" ]; then
    sudo chown -R $(id -u):$(id -g) "$WORKSPACE" || true
  fi
fi
# Print concise diagnostic summary
printf "scaffold: workspace=%s venv=%s generator=%s\n" "$WORKSPACE" "$VENV_DIR" "$WORKSPACE/src/generator.py"
