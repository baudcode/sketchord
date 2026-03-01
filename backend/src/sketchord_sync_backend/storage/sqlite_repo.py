import json
import sqlite3
import threading
import uuid
from pathlib import Path

from sketchord_sync_backend.models import ChangeItem, ConflictItem, MutationResult, SyncOperationType
from sketchord_sync_backend.storage.base import EntityState, SyncRepository


class SqliteSyncRepository(SyncRepository):
    def __init__(self, db_path: str):
        self.db_path = db_path
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._lock = threading.RLock()

    def ensure_schema(self) -> None:
        with self._lock:
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_entities(
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  version INTEGER NOT NULL,
                  payload TEXT NOT NULL,
                  deleted INTEGER NOT NULL DEFAULT 0,
                  updated_at TEXT NOT NULL,
                  PRIMARY KEY(entity_type, entity_id)
                );
                """,
            )
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_processed_ops(
                  op_id TEXT PRIMARY KEY,
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  result_json TEXT NOT NULL,
                  processed_at TEXT NOT NULL
                );
                """,
            )
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_change_log(
                  seq INTEGER PRIMARY KEY AUTOINCREMENT,
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  operation TEXT NOT NULL,
                  version INTEGER NOT NULL,
                  source TEXT,
                  payload TEXT NOT NULL,
                  ts TEXT NOT NULL
                );
                """,
            )
            cols = self.conn.execute("PRAGMA table_info(sync_change_log)").fetchall()
            col_names = {str(c["name"]) for c in cols}
            if "source" not in col_names:
                self.conn.execute("ALTER TABLE sync_change_log ADD source TEXT;")
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_conflicts(
                  conflict_id TEXT PRIMARY KEY,
                  op_id TEXT NOT NULL,
                  entity_type TEXT NOT NULL,
                  entity_id TEXT NOT NULL,
                  reason TEXT NOT NULL,
                  local_payload TEXT NOT NULL,
                  remote_payload TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  resolved_at TEXT
                );
                """,
            )
            self.conn.commit()

    def get_processed_result(self, op_id: str) -> MutationResult | None:
        with self._lock:
            row = self.conn.execute(
                "SELECT result_json FROM sync_processed_ops WHERE op_id = ?",
                (op_id,),
            ).fetchone()
        if row is None:
            return None
        return MutationResult.model_validate_json(row["result_json"])

    def save_processed_result(self, op_id: str, result: MutationResult, processed_at: str) -> None:
        with self._lock:
            self.conn.execute(
                """
                INSERT OR REPLACE INTO sync_processed_ops(op_id, entity_type, entity_id, result_json, processed_at)
                VALUES(?, ?, ?, ?, ?)
                """,
                (
                    op_id,
                    result.entity_type,
                    result.entity_id,
                    result.model_dump_json(),
                    processed_at,
                ),
            )
            self.conn.commit()

    def get_entity(self, entity_type: str, entity_id: str) -> EntityState | None:
        with self._lock:
            row = self.conn.execute(
                """
                SELECT entity_type, entity_id, version, payload, deleted, updated_at
                FROM sync_entities
                WHERE entity_type = ? AND entity_id = ?
                """,
                (entity_type, entity_id),
            ).fetchone()
        if row is None:
            return None
        return EntityState(
            entity_type=row["entity_type"],
            entity_id=row["entity_id"],
            version=int(row["version"]),
            payload=json.loads(row["payload"]),
            deleted=bool(row["deleted"]),
            updated_at=row["updated_at"],
        )

    def upsert_entity(
        self,
        entity_type: str,
        entity_id: str,
        payload: dict,
        deleted: bool,
        ts: str,
    ) -> int:
        with self._lock:
            row = self.conn.execute(
                """
                SELECT version FROM sync_entities
                WHERE entity_type = ? AND entity_id = ?
                """,
                (entity_type, entity_id),
            ).fetchone()
            next_version = (int(row["version"]) if row else 0) + 1
            self.conn.execute(
                """
                INSERT OR REPLACE INTO sync_entities(entity_type, entity_id, version, payload, deleted, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    entity_type,
                    entity_id,
                    next_version,
                    json.dumps(payload),
                    1 if deleted else 0,
                    ts,
                ),
            )
            self.conn.commit()
            return next_version

    def append_change(
        self,
        entity_type: str,
        entity_id: str,
        operation: str,
        version: int,
        source: str | None,
        payload: dict,
        ts: str,
    ) -> int:
        with self._lock:
            cur = self.conn.execute(
                """
                INSERT INTO sync_change_log(entity_type, entity_id, operation, version, source, payload, ts)
                VALUES(?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    entity_type,
                    entity_id,
                    operation,
                    version,
                    source,
                    json.dumps(payload),
                    ts,
                ),
            )
            self.conn.commit()
            return int(cur.lastrowid)

    def create_conflict(
        self,
        op_id: str,
        entity_type: str,
        entity_id: str,
        reason: str,
        local_payload: dict,
        remote_payload: dict,
        created_at: str,
    ) -> str:
        with self._lock:
            conflict_id = str(uuid.uuid4())
            self.conn.execute(
                """
                INSERT INTO sync_conflicts(conflict_id, op_id, entity_type, entity_id, reason, local_payload, remote_payload, created_at, resolved_at)
                VALUES(?, ?, ?, ?, ?, ?, ?, ?, NULL)
                """,
                (
                    conflict_id,
                    op_id,
                    entity_type,
                    entity_id,
                    reason,
                    json.dumps(local_payload),
                    json.dumps(remote_payload),
                    created_at,
                ),
            )
            self.conn.commit()
            return conflict_id

    def list_changes(self, since_seq: int, limit: int) -> list[ChangeItem]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT seq, entity_type, entity_id, operation, version, source, payload, ts
                FROM sync_change_log
                WHERE seq > ?
                ORDER BY seq ASC
                LIMIT ?
                """,
                (since_seq, limit),
            ).fetchall()
        return [
            ChangeItem(
                seq=int(row["seq"]),
                entity_type=row["entity_type"],
                entity_id=row["entity_id"],
                operation=SyncOperationType(row["operation"]),
                version=int(row["version"]),
                source=row["source"],
                payload=json.loads(row["payload"]),
                ts=row["ts"],
            )
            for row in rows
        ]

    def max_change_seq(self) -> int:
        with self._lock:
            row = self.conn.execute("SELECT COALESCE(MAX(seq), 0) AS v FROM sync_change_log").fetchone()
        return int(row["v"]) if row is not None else 0

    def list_conflicts(self, unresolved_only: bool = True) -> list[ConflictItem]:
        with self._lock:
            if unresolved_only:
                rows = self.conn.execute(
                    """
                    SELECT conflict_id, op_id, entity_type, entity_id, reason, local_payload, remote_payload, created_at, resolved_at
                    FROM sync_conflicts
                    WHERE resolved_at IS NULL
                    ORDER BY created_at DESC
                    """,
                ).fetchall()
            else:
                rows = self.conn.execute(
                    """
                    SELECT conflict_id, op_id, entity_type, entity_id, reason, local_payload, remote_payload, created_at, resolved_at
                    FROM sync_conflicts
                    ORDER BY created_at DESC
                    """,
                ).fetchall()
        return [
            ConflictItem(
                conflict_id=row["conflict_id"],
                op_id=row["op_id"],
                entity_type=row["entity_type"],
                entity_id=row["entity_id"],
                reason=row["reason"],
                local_payload=json.loads(row["local_payload"]),
                remote_payload=json.loads(row["remote_payload"]),
                created_at=row["created_at"],
                resolved_at=row["resolved_at"],
            )
            for row in rows
        ]

    def resolve_conflict(self, conflict_id: str, resolved_at: str) -> bool:
        with self._lock:
            cur = self.conn.execute(
                """
                UPDATE sync_conflicts
                SET resolved_at = ?
                WHERE conflict_id = ?
                """,
                (resolved_at, conflict_id),
            )
            self.conn.commit()
            return cur.rowcount > 0

    def list_entities(self, limit: int) -> list[dict]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT entity_type, entity_id, version, payload, deleted, updated_at
                FROM sync_entities
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [
            {
                "entity_type": row["entity_type"],
                "entity_id": row["entity_id"],
                "version": int(row["version"]),
                "payload": json.loads(row["payload"]),
                "deleted": bool(row["deleted"]),
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]

    def list_processed_ops(self, limit: int) -> list[dict]:
        with self._lock:
            rows = self.conn.execute(
                """
                SELECT op_id, entity_type, entity_id, processed_at
                FROM sync_processed_ops
                ORDER BY processed_at DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [
            {
                "op_id": row["op_id"],
                "entity_type": row["entity_type"],
                "entity_id": row["entity_id"],
                "processed_at": row["processed_at"],
            }
            for row in rows
        ]
