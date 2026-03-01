from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from sketchord_sync_backend.models import ChangeItem, ConflictItem, MutationResult


@dataclass
class EntityState:
  entity_type: str
  entity_id: str
  version: int
  payload: dict[str, Any]
  deleted: bool
  updated_at: str


class SyncRepository(ABC):
  @abstractmethod
  def ensure_schema(self) -> None:
    raise NotImplementedError

  @abstractmethod
  def get_processed_result(self, op_id: str) -> MutationResult | None:
    raise NotImplementedError

  @abstractmethod
  def save_processed_result(
    self,
    op_id: str,
    result: MutationResult,
    processed_at: str,
  ) -> None:
    raise NotImplementedError

  @abstractmethod
  def get_entity(self, entity_type: str, entity_id: str) -> EntityState | None:
    raise NotImplementedError

  @abstractmethod
  def upsert_entity(
    self,
    entity_type: str,
    entity_id: str,
    payload: dict[str, Any],
    deleted: bool,
    ts: str,
  ) -> int:
    raise NotImplementedError

  @abstractmethod
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
    raise NotImplementedError

  @abstractmethod
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
    raise NotImplementedError

  @abstractmethod
  def list_changes(self, since_seq: int, limit: int) -> list[ChangeItem]:
    raise NotImplementedError

  @abstractmethod
  def max_change_seq(self) -> int:
    raise NotImplementedError

  @abstractmethod
  def list_conflicts(self, unresolved_only: bool = True) -> list[ConflictItem]:
    raise NotImplementedError

  @abstractmethod
  def resolve_conflict(self, conflict_id: str, resolved_at: str) -> bool:
    raise NotImplementedError

  @abstractmethod
  def list_entities(self, limit: int) -> list[dict[str, Any]]:
    raise NotImplementedError

  @abstractmethod
  def list_processed_ops(self, limit: int) -> list[dict[str, Any]]:
    raise NotImplementedError
