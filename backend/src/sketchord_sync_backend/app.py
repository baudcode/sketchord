import asyncio
import json

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, StreamingResponse

from sketchord_sync_backend.config import Settings
from sketchord_sync_backend.models import ConflictListResponse, PullResponse, UploadRequest, UploadResponse
from sketchord_sync_backend.service import SyncService
from sketchord_sync_backend.storage import create_repository


def _diff_payloads(before: dict | None, after: dict | None) -> dict:
    before = before or {}
    after = after or {}
    added = {}
    removed = {}
    changed = {}

    before_keys = set(before.keys())
    after_keys = set(after.keys())
    for k in sorted(after_keys - before_keys):
        added[k] = after[k]
    for k in sorted(before_keys - after_keys):
        removed[k] = before[k]
    for k in sorted(before_keys & after_keys):
        b = before[k]
        a = after[k]
        if b == a:
            continue
        if isinstance(b, dict) and isinstance(a, dict):
            nested = _diff_payloads(b, a)
            if nested["added"] or nested["removed"] or nested["changed"]:
                changed[k] = nested
        else:
            changed[k] = {"from": b, "to": a}
    return {"added": added, "removed": removed, "changed": changed}


def create_app() -> FastAPI:
    settings = Settings()
    repository = create_repository(settings)
    service = SyncService(repository)

    app = FastAPI(
        title="Sketchord Sync Backend",
        version="0.1.0",
    )

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok", "backend": settings.normalized_backend}

    @app.post("/v1/sync/upload", response_model=UploadResponse)
    def upload(request: UploadRequest) -> UploadResponse:
        return service.upload(request)

    @app.get("/v1/sync/pull", response_model=PullResponse)
    def pull(
        since_seq: int = Query(default=0, ge=0),
        limit: int = Query(default=500, ge=1, le=5000),
    ) -> PullResponse:
        return service.pull(since_seq=since_seq, limit=limit)

    @app.get("/v1/sync/conflicts", response_model=ConflictListResponse)
    def list_conflicts(unresolved_only: bool = True) -> ConflictListResponse:
        return service.list_conflicts(unresolved_only=unresolved_only)

    @app.post("/v1/sync/conflicts/{conflict_id}/resolve")
    def resolve_conflict(conflict_id: str) -> dict[str, bool]:
        resolved = service.resolve_conflict(conflict_id)
        if not resolved:
            raise HTTPException(status_code=404, detail="conflict not found")
        return {"resolved": True}

    @app.get("/v1/admin/state")
    def admin_state(
        entity_limit: int = Query(default=200, ge=1, le=5000),
        change_limit: int = Query(default=200, ge=1, le=5000),
        conflict_limit: int = Query(default=200, ge=1, le=5000),
        op_limit: int = Query(default=200, ge=1, le=5000),
    ) -> dict:
        changes = repository.list_changes(since_seq=0, limit=change_limit)
        previous_payloads: dict[tuple[str, str], dict] = {}
        changes_with_diff = []
        for change in changes:
            key = (change.entity_type, change.entity_id)
            before = previous_payloads.get(key, {})
            after = change.payload
            diff = _diff_payloads(before, after)
            row = change.model_dump()
            row["diff"] = diff
            changes_with_diff.append(row)
            previous_payloads[key] = after

        conflicts = repository.list_conflicts(unresolved_only=False)[:conflict_limit]
        entities = repository.list_entities(limit=entity_limit)
        processed_ops = repository.list_processed_ops(limit=op_limit)
        conflicts_rows = [conflict.model_dump() for conflict in conflicts]
        return {
            "backend": settings.normalized_backend,
            "counts": {
                "entities": len(repository.list_entities(limit=5000)),
                "changes": repository.max_change_seq(),
                "conflicts_unresolved": len(repository.list_conflicts(unresolved_only=True)),
                "processed_ops": len(repository.list_processed_ops(limit=5000)),
            },
            "entities": entities,
            "changes": changes_with_diff,
            "conflicts": conflicts_rows,
            "processed_ops": processed_ops,
            "tables": {
                "sync_entities": entities,
                "sync_change_log": changes_with_diff,
                "sync_conflicts": conflicts_rows,
                "sync_processed_ops": processed_ops,
            },
        }

    @app.get("/v1/admin/stream")
    async def admin_stream(
        request: Request,
        since_seq: int = Query(default=0, ge=0),
    ) -> StreamingResponse:
        async def event_generator():
            last_seq = since_seq
            # Send initial hello event so the UI can confirm connectivity.
            yield "event: hello\ndata: {\"ok\":true}\n\n"
            while True:
                if await request.is_disconnected():
                    break
                max_seq = repository.max_change_seq()
                unresolved = len(repository.list_conflicts(unresolved_only=True))
                if max_seq > last_seq:
                    payload = {
                        "type": "change",
                        "from_seq": last_seq,
                        "to_seq": max_seq,
                        "unresolved_conflicts": unresolved,
                    }
                    yield f"event: change\ndata: {json.dumps(payload)}\n\n"
                    last_seq = max_seq
                else:
                    payload = {
                        "type": "heartbeat",
                        "seq": max_seq,
                        "unresolved_conflicts": unresolved,
                    }
                    yield f"event: heartbeat\ndata: {json.dumps(payload)}\n\n"
                await asyncio.sleep(1.0)

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    @app.get("/dashboard", response_class=HTMLResponse)
    def dashboard() -> str:
        return """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Sketchord Sync Dashboard</title>
    <style>
      :root { --bg:#0e1116; --panel:#171b22; --text:#e6edf3; --muted:#9aa4b2; --accent:#27c17e; --danger:#ff6b6b; }
      body { margin:0; background:var(--bg); color:var(--text); font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto; }
      .wrap { width:100vw; box-sizing:border-box; margin:0; padding:18px; }
      h1 { margin:0 0 8px; font-size:24px; }
      .sub { color:var(--muted); margin-bottom:16px; }
      .grid { display:grid; grid-template-columns:repeat(4,minmax(120px,1fr)); gap:10px; margin-bottom:14px; }
      .card { background:var(--panel); border-radius:10px; padding:12px; border:1px solid #202734; }
      .k { color:var(--muted); font-size:12px; }
      .v { font-size:22px; font-weight:700; margin-top:4px; }
      .ok { color:var(--accent); }
      .bad { color:var(--danger); }
      .row { display:flex; gap:12px; flex-wrap:wrap; margin-bottom:12px; }
      .row > div { flex:1 1 380px; min-width:0; }
      .row-full { margin-bottom:12px; }
      .tabs { display:flex; gap:8px; margin-bottom:12px; }
      .tab-btn { background:#111824; border:1px solid #2a3a52; color:var(--text); border-radius:8px; padding:8px 12px; cursor:pointer; }
      .tab-btn.active { background:#2b3f5c; border-color:#4d6ea0; }
      .tbl { width:100%; border-collapse:collapse; font-size:12px; }
      .tbl th, .tbl td { border-bottom:1px solid #202734; padding:8px; vertical-align:top; text-align:left; }
      .tbl th { color:var(--muted); font-weight:600; position:sticky; top:0; background:var(--panel); }
      .tbl .col-ts { min-width: 220px; width: 220px; }
      .tbl .col-source { min-width: 180px; width: 180px; }
      .tbl .col-version { min-width: 70px; width: 70px; }
      .tbl .col-seq { min-width: 70px; width: 70px; }
      .tbl .ts-cell { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      .panel { background:var(--panel); border-radius:10px; padding:10px; border:1px solid #202734; }
      .scroll { max-height:320px; overflow:auto; }
      .mono { font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace; word-break:break-word; }
      .explorer-controls { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-bottom:10px; }
      .explorer-controls input, .explorer-controls select { background:#101720; color:var(--text); border:1px solid #2a3a52; border-radius:8px; padding:8px 10px; }
      .explorer-grid { display:grid; grid-template-columns:260px 360px 1fr; gap:12px; }
      .explorer-list { max-height:360px; overflow:auto; border:1px solid #202734; border-radius:8px; }
      .explorer-item { display:block; width:100%; text-align:left; background:transparent; color:var(--text); border:0; border-bottom:1px solid #202734; padding:10px; cursor:pointer; }
      .explorer-item:hover { background:#1e2633; }
      .explorer-item.active { background:#243148; }
      .explorer-meta { color:var(--muted); font-size:11px; margin-top:4px; }
      .json-view { white-space:pre-wrap; font-size:12px; line-height:1.45; max-height:360px; overflow:auto; border:1px solid #202734; border-radius:8px; padding:10px; background:#121821; }
      button { background:#223044; color:var(--text); border:1px solid #31425a; border-radius:8px; padding:8px 10px; cursor:pointer; }
      .top { display:flex; justify-content:space-between; align-items:center; gap:10px; margin-bottom:10px; }
      @media (max-width: 1200px) { .explorer-grid { grid-template-columns:240px 1fr; } .explorer-json { grid-column:1 / -1; } }
      @media (max-width: 960px) { .explorer-grid { grid-template-columns:1fr; } .explorer-json { grid-column:auto; } }
    </style>
  </head>
  <body>
    <div id="root"></div>
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script>
      const e = React.createElement;
      function Dashboard() {
        const [state, setState] = React.useState(null);
        const [error, setError] = React.useState(null);
        const [activeTab, setActiveTab] = React.useState('overview');
        const [selectedTable, setSelectedTable] = React.useState('sync_entities');
        const [selectedRowKey, setSelectedRowKey] = React.useState(null);
        const [tableSearch, setTableSearch] = React.useState('');
        const [rowSearch, setRowSearch] = React.useState('');
        const [entityTypeFilter, setEntityTypeFilter] = React.useState('');

        async function load() {
          try {
            const res = await fetch('/v1/admin/state');
            if (!res.ok) throw new Error('HTTP ' + res.status);
            const data = await res.json();
            setState(data);
            setError(null);
          } catch (err) {
            setError(String(err));
          }
        }

        React.useEffect(() => {
          load();
          const es = new EventSource('/v1/admin/stream');
          es.addEventListener('change', () => load());
          es.addEventListener('heartbeat', () => load());
          es.onerror = () => setError('Stream disconnected, retrying...');
          return () => es.close();
        }, []);

        function table(title, rows, cols) {
          return e('div', { className:'panel' },
            e('div', { className:'top' }, e('strong', null, title)),
            e('div', { className:'scroll' },
              e('table', { className:'tbl' },
                e('thead', null, e('tr', null, cols.map(c => {
                  const headerClass = c === 'ts' ? 'col-ts' : (c === 'source' ? 'col-source' : (c === 'version' ? 'col-version' : (c === 'seq' ? 'col-seq' : '')));
                  return e('th', { key:c, className: headerClass }, c);
                }))),
                e('tbody', null,
                  rows.map((r, idx) =>
                    e('tr', { key: idx },
                      cols.map(c => {
                        const headerClass = c === 'ts' ? 'col-ts' : (c === 'source' ? 'col-source' : (c === 'version' ? 'col-version' : (c === 'seq' ? 'col-seq' : '')));
                        const tdClass = 'mono ' + (c === 'ts' ? 'ts-cell ' : '') + headerClass;
                        return e('td', { key:c, className: tdClass }, typeof r[c] === 'object' ? JSON.stringify(r[c]) : String(r[c] ?? ''));
                      })
                    )
                  )
                )
              )
            )
          );
        }

        function rowKey(tableName, row, idx) {
          const candidates = ['conflict_id', 'op_id', 'seq', 'entity_id', 'id'];
          for (const c of candidates) {
            if (row && row[c] !== undefined && row[c] !== null) {
              return tableName + ':' + c + ':' + String(row[c]);
            }
          }
          return tableName + ':idx:' + idx + ':' + JSON.stringify(row).slice(0, 120);
        }

        function rowTitle(row, idx) {
          if (!row) return 'Row #' + (idx + 1);
          if (row.entity_type && row.entity_id) return row.entity_type + ' / ' + row.entity_id;
          if (row.conflict_id) return 'Conflict ' + row.conflict_id;
          if (row.op_id) return 'Op ' + row.op_id;
          if (row.seq !== undefined && row.seq !== null) return 'Seq ' + row.seq;
          return 'Row #' + (idx + 1);
        }

        function rowMeta(row) {
          if (!row) return '';
          const parts = [];
          if (row.operation) parts.push(String(row.operation));
          if (row.source) parts.push(String(row.source));
          if (row.ts) parts.push(String(row.ts));
          if (row.version !== undefined && row.version !== null) parts.push('v' + String(row.version));
          if (row.reason) parts.push(String(row.reason));
          return parts.join(' | ');
        }

        const tables = state && state.tables ? state.tables : {};
        const tableNames = Object.keys(tables);
        const tableQuery = tableSearch.trim().toLowerCase();
        const visibleTableNames = tableQuery
          ? tableNames.filter((name) => name.toLowerCase().includes(tableQuery))
          : tableNames;
        const activeTableName = visibleTableNames.includes(selectedTable)
          ? selectedTable
          : (visibleTableNames[0] || '');
        const activeRows = activeTableName ? (tables[activeTableName] || []) : [];
        const entityTypeOptions = Array.from(
          new Set(
            activeRows
              .map((row) => row && row.entity_type)
              .filter((v) => typeof v === 'string' && v.length > 0)
          )
        ).sort();
        const activeEntityTypeFilter = entityTypeOptions.includes(entityTypeFilter) ? entityTypeFilter : '';
        const rowQuery = rowSearch.trim().toLowerCase();
        const visibleRows = activeRows.filter((row) => {
          if (activeEntityTypeFilter && String(row.entity_type || '') !== activeEntityTypeFilter) {
            return false;
          }
          if (rowQuery) {
            return JSON.stringify(row).toLowerCase().includes(rowQuery);
          }
          return true;
        });
        const visibleRowsWithKeys = visibleRows.map((row, idx) => ({ key: rowKey(activeTableName, row, idx), row, idx }));

        React.useEffect(() => {
          if (!visibleTableNames.length) return;
          if (!visibleTableNames.includes(selectedTable)) {
            setSelectedTable(visibleTableNames[0]);
            setSelectedRowKey(null);
          }
        }, [selectedTable, tableSearch, state]);

        React.useEffect(() => {
          if (!visibleRowsWithKeys.length) {
            if (selectedRowKey !== null) setSelectedRowKey(null);
            return;
          }
          const exists = visibleRowsWithKeys.some((entry) => entry.key === selectedRowKey);
          if (!exists) setSelectedRowKey(visibleRowsWithKeys[0].key);
        }, [activeTableName, rowSearch, activeEntityTypeFilter, state, selectedRowKey]);

        React.useEffect(() => {
          if (entityTypeFilter && !entityTypeOptions.includes(entityTypeFilter)) {
            setEntityTypeFilter('');
          }
        }, [activeTableName, state, entityTypeFilter]);

        const selectedEntry = visibleRowsWithKeys.find((entry) => entry.key === selectedRowKey) || null;
        const selectedRow = selectedEntry ? selectedEntry.row : null;
        const selectedRowPretty = selectedRow ? JSON.stringify(selectedRow, null, 2) : 'No row selected';

        if (!state) {
          return e('div', { className:'wrap' }, e('h1', null, 'Sketchord Sync Dashboard'), e('div', { className:'sub' }, error ? 'Load failed: ' + error : 'Loading...'));
        }

        return e('div', { className:'wrap' },
          e('h1', null, 'Sketchord Sync Dashboard'),
          e('div', { className:'sub mono' }, 'Backend: ' + state.backend + (error ? ' | Last error: ' + error : '')),
          e('div', { className:'grid' },
            e('div', { className:'card' }, e('div',{className:'k'},'Entities'), e('div',{className:'v'}, state.counts.entities)),
            e('div', { className:'card' }, e('div',{className:'k'},'Changes'), e('div',{className:'v'}, state.counts.changes)),
            e('div', { className:'card' }, e('div',{className:'k'},'Unresolved Conflicts'), e('div',{className:'v ' + (state.counts.conflicts_unresolved > 0 ? 'bad' : 'ok')}, state.counts.conflicts_unresolved)),
            e('div', { className:'card' }, e('div',{className:'k'},'Processed Ops'), e('div',{className:'v'}, state.counts.processed_ops))
          ),
          e('div', { className:'tabs' },
            e('button', {
              className: 'tab-btn' + (activeTab === 'overview' ? ' active' : ''),
              onClick: () => setActiveTab('overview')
            }, 'Overview'),
            e('button', {
              className: 'tab-btn' + (activeTab === 'explorer' ? ' active' : ''),
              onClick: () => setActiveTab('explorer')
            }, 'Table Explorer')
          ),
          activeTab === 'overview'
            ? e('div', null,
                e('div', { className:'row' },
                  e('div', null, table('Entities', state.entities, ['entity_type','entity_id','version','deleted','updated_at','payload'])),
                  e('div', null, table('Changes', state.changes, ['seq','entity_type','entity_id','operation','version','source','ts','diff']))
                ),
                e('div', { className:'row' },
                  e('div', null, table('Conflicts', state.conflicts, ['conflict_id','entity_type','entity_id','reason','created_at','resolved_at'])),
                  e('div', null, table('Processed Ops', state.processed_ops, ['op_id','entity_type','entity_id','processed_at']))
                )
              )
            : e('div', { className:'panel' },
                e('div', { className:'top' },
                  e('strong', null, 'Table Explorer'),
                  e('span', { className:'sub mono' }, activeTableName ? (activeTableName + ' rows=' + activeRows.length + ' filtered=' + visibleRows.length) : 'No tables')
                ),
                e('div', { className:'explorer-controls' },
                  e('input', {
                    type: 'text',
                    placeholder: 'Search tables...',
                    value: tableSearch,
                    onChange: (ev) => setTableSearch(ev.target.value)
                  }),
                  e('select', {
                    value: activeTableName || '',
                    onChange: (ev) => {
                      setSelectedTable(ev.target.value);
                      setSelectedRowKey(null);
                    }
                  },
                    visibleTableNames.map((name) => e('option', { key: name, value: name }, name))
                  ),
                  e('select', {
                    value: activeEntityTypeFilter,
                    onChange: (ev) => {
                      setEntityTypeFilter(ev.target.value);
                      setSelectedRowKey(null);
                    }
                  },
                    e('option', { value: '' }, 'All entity types'),
                    entityTypeOptions.map((entityType) => e('option', { key: entityType, value: entityType }, entityType))
                  ),
                  e('input', {
                    type: 'text',
                    placeholder: 'Filter rows in selected table...',
                    value: rowSearch,
                    onChange: (ev) => setRowSearch(ev.target.value)
                  })
                ),
                !visibleTableNames.length
                  ? e('div', { className:'sub' }, 'No tables match your search.')
                  : e('div', { className:'explorer-grid' },
                      e('div', { className:'explorer-list' },
                        visibleTableNames.map((name) => {
                          const rows = tables[name] || [];
                          const active = name === activeTableName;
                          return e('button', {
                              key: name,
                              className: 'explorer-item' + (active ? ' active' : ''),
                              onClick: () => { setSelectedTable(name); setSelectedRowKey(null); }
                            },
                            e('div', { className:'mono' }, name),
                            e('div', { className:'explorer-meta' }, 'rows=' + rows.length)
                          );
                        })
                      ),
                      e('div', { className:'explorer-list' },
                        visibleRowsWithKeys.length === 0
                          ? e('div', { className:'explorer-meta', style:{padding:'10px'} }, 'No rows match this filter.')
                          : visibleRowsWithKeys.map((entry) => e('button', {
                              key: entry.key,
                              className: 'explorer-item' + (entry.key === selectedRowKey ? ' active' : ''),
                              onClick: () => setSelectedRowKey(entry.key)
                            },
                            e('div', { className:'mono' }, rowTitle(entry.row, entry.idx)),
                            e('div', { className:'explorer-meta mono' }, rowMeta(entry.row))
                          ))
                      ),
                      e('div', { className:'explorer-json' },
                        e('pre', { className:'json-view mono' }, selectedRowPretty)
                      )
                    )
              ),
          e('button', { onClick: load }, 'Refresh now')
        );
      }
      ReactDOM.createRoot(document.getElementById('root')).render(e(Dashboard));
    </script>
  </body>
</html>
"""

    return app
