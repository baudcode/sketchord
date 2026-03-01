#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${BACKEND_DIR}"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller

ENTRYPOINT="${BACKEND_DIR}/src/sketchord_sync_backend/__main__.py"
if [ ! -f "${ENTRYPOINT}" ]; then
  echo "Entrypoint not found: ${ENTRYPOINT}" >&2
  exit 1
fi

pyinstaller \
  --clean \
  --noconfirm \
  --onefile \
  --name sketchord-sync-backend \
  --paths "${BACKEND_DIR}/src" \
  --collect-submodules uvicorn \
  "${ENTRYPOINT}"

echo "Built backend executable at: ${BACKEND_DIR}/dist/sketchord-sync-backend"
