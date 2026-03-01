from datetime import datetime, timezone
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


def utc_now_iso() -> str:
  return datetime.now(timezone.utc).isoformat()


class OperationStatus(str, Enum):
  applied = "applied"
  merged = "merged"
  rejected = "rejected"
  duplicate = "duplicate"


class SyncOperationType(str, Enum):
  upsert = "upsert"
  delete = "delete"
  tombstone = "tombstone"


class Mutation(BaseModel):
  op_id: str = Field(min_length=1, max_length=128)
  entity_type: str = Field(min_length=1, max_length=64)
  entity_id: str = Field(min_length=1, max_length=256)
  operation: SyncOperationType
  base_version: int = Field(ge=0)
  payload: dict[str, Any] = Field(default_factory=dict)
  client_ts: str | None = None
  source: str | None = None


class UploadRequest(BaseModel):
  mutations: list[Mutation] = Field(default_factory=list)


class MutationResult(BaseModel):
  op_id: str
  status: OperationStatus
  entity_type: str
  entity_id: str
  server_version: int | None = None
  message: str | None = None
  merged_payload: dict[str, Any] | None = None
  remote_payload: dict[str, Any] | None = None
  conflict_id: str | None = None


class UploadResponse(BaseModel):
  results: list[MutationResult]


class ChangeItem(BaseModel):
  seq: int
  entity_type: str
  entity_id: str
  operation: SyncOperationType
  version: int
  source: str | None = None
  payload: dict[str, Any]
  ts: str


class PullResponse(BaseModel):
  changes: list[ChangeItem]
  next_seq: int


class ConflictItem(BaseModel):
  conflict_id: str
  op_id: str
  entity_type: str
  entity_id: str
  reason: str
  local_payload: dict[str, Any]
  remote_payload: dict[str, Any]
  created_at: str
  resolved_at: str | None = None


class ConflictListResponse(BaseModel):
  conflicts: list[ConflictItem]
