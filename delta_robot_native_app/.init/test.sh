#!/usr/bin/env bash
set -euo pipefail
# Minimal test runner: writes the pytest smoke test and runs it using the venv pytest
WORKSPACE="/home/kavia/workspace/code-generation/delta-robotics-script-generator-21-30/delta_robot_native_app"
cd "$WORKSPACE"
VENV_PYTEST="$WORKSPACE/.venv/bin/pytest"
if [ ! -x "$VENV_PYTEST" ]; then
  echo "error: pytest not found in venv at $VENV_PYTEST" >&2
  exit 10
fi
mkdir -p tests
cat > tests/test_generator.py <<'PY'
import subprocess, json, os

def test_generator_outputs_json():
    env = os.environ.copy()
    env['DEBIAN_FRONTEND'] = 'noninteractive'
    env['PYTHONUNBUFFERED'] = '1'
    env['WORKSPACE'] = os.getcwd()
    # run start.sh via bash to ensure correct PATH and execution semantics
    proc = subprocess.run(['bash','-c','./start.sh'], capture_output=True, text=True, timeout=10, env=env)
    assert proc.returncode == 0, f"generator exited non-zero: rc={proc.returncode}\nstderr={proc.stderr}\nstdout={proc.stdout}"
    out_lines = [l for l in proc.stdout.splitlines() if l.strip()]
    assert out_lines, f'no output from generator; stderr={proc.stderr}\nstdout={proc.stdout}'
    last = out_lines[-1].strip()
    try:
        data = json.loads(last)
    except Exception as e:
        raise AssertionError(f"failed to parse last stdout line as JSON: {e}\nlast_line={last}\nstderr={proc.stderr}\nstdout={proc.stdout}")
    assert data.get('status') == 'ok', f"unexpected status: {data} stderr={proc.stderr} stdout={proc.stdout}"
PY

# Run pytest using venv pytest
"$VENV_PYTEST" -q tests || { echo "error: tests failed" >&2; exit 11; }
