import uuid
from typing import Any

from sketchord_sync_backend.models import (
    ChangeItem,
    ConflictItem,
    MutationResult,
    SyncOperationType,
)
from sketchord_sync_backend.storage.base import EntityState, SyncRepository


class RethinkSyncRepository(SyncRepository):
    def __init__(
        self,
        host: str,
        port: int,
        db_name: str,
        table_prefix: str = "sync",
    ):
        try:
            from rethinkdb import RethinkDB
        except ImportError as exc:
            raise RuntimeError(
                "RethinkDB backend requested but rethinkdb package is not installed. "
                "Install with: uv sync --extra rethinkdb",
            ) from exc

        self.r = RethinkDB()
        self.host = host
        self.port = port
        self.db_name = db_name
        self.entities_table = f"{table_prefix}_entities"
        self.processed_ops_table = f"{table_prefix}_processed_ops"
        self.change_log_table = f"{table_prefix}_change_log"
        self.conflicts_table = f"{table_prefix}_conflicts"
        self.conn = self.r.connect(host, port)

    def _db(self):
        return self.r.db(self.db_name)

    def _create_index_if_missing(self, table: str, index: str) -> None:
        indexes = self._db().table(table).index_list().run(self.conn)
        if index not in indexes:
            self._db().table(table).index_create(index).run(self.conn)
            self._db().table(table).index_wait(index).run(self.conn)

    def ensure_schema(self) -> None:
        dbs = self.r.db_list().run(self.conn)
        if self.db_name not in dbs:
            self.r.db_create(self.db_name).run(self.conn)

        db = self._db()
        tables = db.table_list().run(self.conn)
        for table in [
            self.entities_table,
            self.processed_ops_table,
            self.change_log_table,
            self.conflicts_table,
        ]:
            if table not in tables:
                db.table_create(table).run(self.conn)

        self._create_index_if_missing(self.entities_table, "entity_key")
        self._create_index_if_missing(self.processed_ops_table, "op_id")
        self._create_index_if_missing(self.change_log_table, "seq")
        self._create_index_if_missing(self.change_log_table, "ts")
        self._create_index_if_missing(self.conflicts_table, "resolved_at")
        self._create_index_if_missing(self.conflicts_table, "created_at")

    def _entity_key(self, entity_type: str, entity_id: str) -> str:
        return f"{entity_type}:{entity_id}"

    def get_processed_result(self, op_id: str) -> MutationResult | None:
        row = self._db().table(self.processed_ops_table).get(op_id).run(self.conn)
        if row is None:
            return None
        return MutationResult.model_validate(row["result"])

    def save_processed_result(
        self,
        op_id: str,
        result: MutationResult,
        processed_at: str,
    ) -> None:
        self._db().table(self.processed_ops_table).insert(
            {
                "id": op_id,
                "op_id": op_id,
                "entity_type": result.entity_type,
                "entity_id": result.entity_id,
                "result": result.model_dump(),
                "processed_at": processed_at,
            },
            conflict="replace",
        ).run(self.conn)

    def get_entity(self, entity_type: str, entity_id: str) -> EntityState | None:
        key = self._entity_key(entity_type, entity_id)
        row = self._db().table(self.entities_table).get(key).run(self.conn)
        if row is None:
            return None
        return EntityState(
            entity_type=row["entity_type"],
            entity_id=row["entity_id"],
            version=int(row["version"]),
            payload=dict(row.get("payload", {})),
            deleted=bool(row.get("deleted", False)),
            updated_at=row["updated_at"],
        )

    def upsert_entity(
        self,
        entity_type: str,
        entity_id: str,
        payload: dict[str, Any],
        deleted: bool,
        ts: str,
    ) -> int:
        current = self.get_entity(entity_type, entity_id)
        next_version = (current.version if current else 0) + 1
        self._db().table(self.entities_table).insert(
            {
                "id": self._entity_key(entity_type, entity_id),
                "entity_key": self._entity_key(entity_type, entity_id),
                "entity_type": entity_type,
                "entity_id": entity_id,
                "version": next_version,
                "payload": payload,
                "deleted": deleted,
                "updated_at": ts,
            },
            conflict="replace",
        ).run(self.conn)
        return next_version

    def append_change(
        self,
        entity_type: str,
        entity_id: str,
        operation: str,
        version: int,
        source: str | None,
        payload: dict[str, Any],
        ts: str,
    ) -> int:
        next_seq = self.max_change_seq() + 1
        result = self._db().table(self.change_log_table).insert(
            {
                "seq": next_seq,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "operation": operation,
                "version": version,
                "source": source,
                "payload": payload,
                "ts": ts,
            },
        ).run(self.conn)
        _ = result
        return next_seq

    def create_conflict(
        self,
        op_id: str,
        entity_type: str,
        entity_id: str,
        reason: str,
        local_payload: dict[str, Any],
        remote_payload: dict[str, Any],
        created_at: str,
    ) -> str:
        conflict_id = str(uuid.uuid4())
        self._db().table(self.conflicts_table).insert(
            {
                "id": conflict_id,
                "conflict_id": conflict_id,
                "op_id": op_id,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "reason": reason,
                "local_payload": local_payload,
                "remote_payload": remote_payload,
                "created_at": created_at,
                "resolved_at": None,
            },
        ).run(self.conn)
        return conflict_id

    def list_changes(self, since_seq: int, limit: int) -> list[ChangeItem]:
        rows = (
            self._db()
            .table(self.change_log_table)
            .filter(self.r.row["seq"] > since_seq)
            .order_by("seq")
            .limit(limit)
            .run(self.conn)
        )
        return [
            ChangeItem(
                seq=int(row["seq"]),
                entity_type=row["entity_type"],
                entity_id=row["entity_id"],
                operation=SyncOperationType(row["operation"]),
                version=int(row["version"]),
                source=row.get("source"),
                payload=dict(row.get("payload", {})),
                ts=row["ts"],
            )
            for row in rows
        ]

    def max_change_seq(self) -> int:
        rows = (
            self._db()
            .table(self.change_log_table)
            .order_by(self.r.desc("seq"))
            .limit(1)
            .run(self.conn)
        )
        first = next(iter(rows), None)
        if first is None:
            return 0
        return int(first.get("seq", 0))

    def list_conflicts(self, unresolved_only: bool = True) -> list[ConflictItem]:
        query = self._db().table(self.conflicts_table)
        if unresolved_only:
            query = query.filter(self.r.row["resolved_at"] == None)  # noqa: E711
        rows = query.order_by(self.r.desc("created_at")).run(self.conn)
        return [
            ConflictItem(
                conflict_id=row["conflict_id"],
                op_id=row["op_id"],
                entity_type=row["entity_type"],
                entity_id=row["entity_id"],
                reason=row["reason"],
                local_payload=dict(row.get("local_payload", {})),
                remote_payload=dict(row.get("remote_payload", {})),
                created_at=row["created_at"],
                resolved_at=row.get("resolved_at"),
            )
            for row in rows
        ]

    def resolve_conflict(self, conflict_id: str, resolved_at: str) -> bool:
        result = self._db().table(self.conflicts_table).get(conflict_id).update(
            {"resolved_at": resolved_at},
        ).run(self.conn)
        return result.get("replaced", 0) > 0 or result.get("unchanged", 0) > 0

    def list_entities(self, limit: int) -> list[dict]:
        rows = (
            self._db()
            .table(self.entities_table)
            .order_by(self.r.desc("updated_at"))
            .limit(limit)
            .run(self.conn)
        )
        return [
            {
                "entity_type": row["entity_type"],
                "entity_id": row["entity_id"],
                "version": int(row["version"]),
                "payload": dict(row.get("payload", {})),
                "deleted": bool(row.get("deleted", False)),
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]

    def list_processed_ops(self, limit: int) -> list[dict]:
        rows = (
            self._db()
            .table(self.processed_ops_table)
            .order_by(self.r.desc("processed_at"))
            .limit(limit)
            .run(self.conn)
        )
        return [
            {
                "op_id": row["op_id"],
                "entity_type": row["entity_type"],
                "entity_id": row["entity_id"],
                "processed_at": row.get("processed_at", ""),
            }
            for row in rows
        ]
