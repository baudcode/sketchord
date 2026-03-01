#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${BACKEND_DIR}"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller

pyinstaller --clean --noconfirm pyinstaller/sketchord_sync_backend.spec

echo "Built backend executable at: ${BACKEND_DIR}/dist/sketchord-sync-backend"
