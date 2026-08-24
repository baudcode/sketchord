#!/usr/bin/env bash
# Creates the PESTO artifact consumed by lib/transcription/pesto_runner.dart.
# Run this on a trusted build machine, publish the result over HTTPS, and put
# the resulting SHA-256 in the app's signed model manifest.
set -euo pipefail

OUTPUT_PATH="${1:-pesto_mir-1k_g7_44100_1024.onnx}"
WORK_DIR="${TMPDIR:-/tmp}/sketchord-pesto-export"
REPOSITORY="https://github.com/SonyCSLParis/pesto.git"
REVISION="62bc0c9702558f19af4593752947fb9db1eadac9"

rm -rf "$WORK_DIR"
git clone --depth 1 "$REPOSITORY" "$WORK_DIR"
git -C "$WORK_DIR" fetch --depth 1 origin "$REVISION"
git -C "$WORK_DIR" checkout --detach "$REVISION"

python3 -m venv "$WORK_DIR/.venv"
source "$WORK_DIR/.venv/bin/activate"
PIP_INDEX_URL=https://pypi.org/simple python -m pip install --upgrade pip
PIP_INDEX_URL=https://pypi.org/simple python -m pip install -e "$WORK_DIR" onnx onnxruntime onnxscript

# PyTorch 2.9 defaults to the newer Dynamo exporter, which currently fails
# on PESTO's dynamic `torch.roll`.  The official script is otherwise used
# unchanged; legacy TorchScript export passes PESTO's own validation.
python - "$WORK_DIR" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1]) / "realtime/export_onnx.py"
source = path.read_text()
source = source.replace(
    '        dynamic_axes={',
    '        dynamo=False,\n        dynamic_axes={',
    1,
)
path.write_text(source)
PY

cd "$WORK_DIR"
python -m realtime.export_onnx mir-1k_g7 \
  --sampling_rate 44100 \
  --chunk_size 1024 \
  --batch_size 1 \
  --script_name "$OUTPUT_PATH"

shasum -a 256 "$OUTPUT_PATH"
