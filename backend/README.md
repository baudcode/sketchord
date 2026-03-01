# Sketchord Sync Backend

FastAPI backend for deterministic mutation sync.

## Install

```bash
cd backend
uv sync
```

Optional RethinkDB support:

```bash
cd backend
uv sync --extra rethinkdb
```

## Run

```bash
cd backend
uv run sketchord-sync-backend
```

## Build Standalone Binary (PyInstaller)

Build a single-file executable for macOS/Linux:

```bash
cd backend
./scripts/build_pyinstaller.sh
```

Output binary:

- `backend/dist/sketchord-sync-backend`

Run it directly:

```bash
SYNC_PORT=8009 ./dist/sketchord-sync-backend
```

## Configuration

- `SYNC_DB_BACKEND`: `sqlite` (default) or `rethinkdb`
- `SYNC_SQLITE_PATH`: SQLite file path (default: `./data/sync.db`)
- `SYNC_HOST`: bind host (default: `0.0.0.0`)
- `SYNC_PORT`: bind port (default: `8009`)
- `SYNC_LOG_LEVEL`: Uvicorn log level (default: `info`)

RethinkDB settings (only when `SYNC_DB_BACKEND=rethinkdb`):

- `SYNC_RETHINK_HOST` (default: `localhost`)
- `SYNC_RETHINK_PORT` (default: `28015`)
- `SYNC_RETHINK_DB` (default: `sketchord`)
- `SYNC_RETHINK_TABLE_PREFIX` (default: `sync`)

## API

- `GET /healthz`
- `POST /v1/sync/upload`
- `GET /v1/sync/pull?since_seq=<int>`
- `GET /v1/sync/conflicts?unresolved_only=true`
- `POST /v1/sync/conflicts/{conflict_id}/resolve`
