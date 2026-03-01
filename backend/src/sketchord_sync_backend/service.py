from dataclasses import dataclass
from typing import Any

from sketchord_sync_backend.models import (
    ConflictListResponse,
    Mutation,
    MutationResult,
    OperationStatus,
    PullResponse,
    SyncOperationType,
    UploadRequest,
    UploadResponse,
    utc_now_iso,
)
from sketchord_sync_backend.storage.base import EntityState, SyncRepository


@dataclass
class MergeOutcome:
    status: OperationStatus
    merged_payload: dict[str, Any] | None = None
    message: str | None = None


class SyncService:
    def __init__(self, repository: SyncRepository):
        self.repository = repository

    def upload(self, request: UploadRequest) -> UploadResponse:
        results: list[MutationResult] = []
        for mutation in request.mutations:
            results.append(self._apply_mutation(mutation))
        return UploadResponse(results=results)

    def pull(self, since_seq: int, limit: int = 500) -> PullResponse:
        changes = self.repository.list_changes(since_seq=since_seq, limit=limit)
        next_seq = changes[-1].seq if changes else self.repository.max_change_seq()
        return PullResponse(changes=changes, next_seq=next_seq)

    def list_conflicts(self, unresolved_only: bool = True) -> ConflictListResponse:
        return ConflictListResponse(
            conflicts=self.repository.list_conflicts(unresolved_only=unresolved_only),
        )

    def resolve_conflict(self, conflict_id: str) -> bool:
        return self.repository.resolve_conflict(conflict_id, utc_now_iso())

    def _apply_mutation(self, mutation: Mutation) -> MutationResult:
        existing_result = self.repository.get_processed_result(mutation.op_id)
        if existing_result is not None:
            return existing_result

        now = utc_now_iso()
        current = self.repository.get_entity(mutation.entity_type, mutation.entity_id)

        if mutation.operation in {SyncOperationType.delete, SyncOperationType.tombstone}:
            result = self._apply_delete(mutation, current, now)
        else:
            result = self._apply_upsert(mutation, current, now)

        self.repository.save_processed_result(
            op_id=mutation.op_id,
            result=result,
            processed_at=now,
        )
        return result

    def _apply_delete(
        self,
        mutation: Mutation,
        current: EntityState | None,
        now: str,
    ) -> MutationResult:
        if current is None:
            version = self.repository.upsert_entity(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                payload={"id": mutation.entity_id},
                deleted=True,
                ts=now,
            )
            self.repository.append_change(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                operation=mutation.operation.value,
                version=version,
                source=mutation.source,
                payload={"id": mutation.entity_id},
                ts=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.applied,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=version,
                message="Delete tombstone created",
            )

        if current.version != mutation.base_version and not current.deleted:
            conflict_id = self.repository.create_conflict(
                op_id=mutation.op_id,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                reason="Delete rejected: version mismatch",
                local_payload=mutation.payload,
                remote_payload=current.payload,
                created_at=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.rejected,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=current.version,
                message="Delete rejected: version mismatch",
                remote_payload=current.payload,
                conflict_id=conflict_id,
            )

        version = self.repository.upsert_entity(
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            payload=current.payload if current else mutation.payload,
            deleted=True,
            ts=now,
        )
        self.repository.append_change(
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            operation=mutation.operation.value,
            version=version,
            source=mutation.source,
            payload={"id": mutation.entity_id},
            ts=now,
        )
        return MutationResult(
            op_id=mutation.op_id,
            status=OperationStatus.applied,
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            server_version=version,
        )

    def _apply_upsert(
        self,
        mutation: Mutation,
        current: EntityState | None,
        now: str,
    ) -> MutationResult:
        if current is None:
            if mutation.base_version != 0:
                conflict_id = self.repository.create_conflict(
                    op_id=mutation.op_id,
                    entity_type=mutation.entity_type,
                    entity_id=mutation.entity_id,
                    reason="Upsert rejected: entity missing for non-zero base_version",
                    local_payload=mutation.payload,
                    remote_payload={},
                    created_at=now,
                )
                return MutationResult(
                    op_id=mutation.op_id,
                    status=OperationStatus.rejected,
                    entity_type=mutation.entity_type,
                    entity_id=mutation.entity_id,
                    server_version=0,
                    message="Entity missing for non-zero base_version",
                    remote_payload={},
                    conflict_id=conflict_id,
                )
            version = self.repository.upsert_entity(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                payload=mutation.payload,
                deleted=False,
                ts=now,
            )
            self.repository.append_change(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                operation=mutation.operation.value,
                version=version,
                source=mutation.source,
                payload=mutation.payload,
                ts=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.applied,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=version,
            )

        if current.deleted:
            conflict_id = self.repository.create_conflict(
                op_id=mutation.op_id,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                reason="Upsert rejected: entity is tombstoned",
                local_payload=mutation.payload,
                remote_payload=current.payload,
                created_at=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.rejected,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=current.version,
                message="Entity is tombstoned",
                remote_payload=current.payload,
                conflict_id=conflict_id,
            )

        if current.version == mutation.base_version:
            version = self.repository.upsert_entity(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                payload=mutation.payload,
                deleted=False,
                ts=now,
            )
            self.repository.append_change(
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                operation=mutation.operation.value,
                version=version,
                source=mutation.source,
                payload=mutation.payload,
                ts=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.applied,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=version,
            )

        merge = self._deterministic_merge(local=mutation.payload, remote=current.payload)
        if merge.status == OperationStatus.rejected:
            conflict_id = self.repository.create_conflict(
                op_id=mutation.op_id,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                reason=merge.message or "Upsert rejected: overlapping field conflict",
                local_payload=mutation.payload,
                remote_payload=current.payload,
                created_at=now,
            )
            return MutationResult(
                op_id=mutation.op_id,
                status=OperationStatus.rejected,
                entity_type=mutation.entity_type,
                entity_id=mutation.entity_id,
                server_version=current.version,
                message=merge.message,
                remote_payload=current.payload,
                conflict_id=conflict_id,
            )

        merged_payload = merge.merged_payload or mutation.payload
        version = self.repository.upsert_entity(
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            payload=merged_payload,
            deleted=False,
            ts=now,
        )
        self.repository.append_change(
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            operation=mutation.operation.value,
            version=version,
            source=mutation.source,
            payload=merged_payload,
            ts=now,
        )
        return MutationResult(
            op_id=mutation.op_id,
            status=OperationStatus.merged,
            entity_type=mutation.entity_type,
            entity_id=mutation.entity_id,
            server_version=version,
            merged_payload=merged_payload,
        )

    def _deterministic_merge(self, local: dict[str, Any], remote: dict[str, Any]) -> MergeOutcome:
        merged = dict(remote)
        conflict_keys: list[str] = []
        for key, local_value in local.items():
            if key not in merged:
                merged[key] = local_value
                continue
            remote_value = merged[key]
            if remote_value == local_value:
                continue

            if isinstance(local_value, dict) and isinstance(remote_value, dict):
                nested = self._deterministic_merge(local_value, remote_value)
                if nested.status == OperationStatus.rejected:
                    conflict_keys.append(key)
                    continue
                merged[key] = nested.merged_payload or remote_value
                continue

            conflict_keys.append(key)

        if conflict_keys:
            return MergeOutcome(
                status=OperationStatus.rejected,
                message=f"Overlapping field conflict: {', '.join(sorted(conflict_keys))}",
            )

        return MergeOutcome(status=OperationStatus.merged, merged_payload=merged)
