import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
  db_backend: str = os.getenv("SYNC_DB_BACKEND", "sqlite").strip().lower()
  sqlite_path: str = os.getenv("SYNC_SQLITE_PATH", "./data/sync.db")
  host: str = os.getenv("SYNC_HOST", "0.0.0.0")
  port: int = int(os.getenv("SYNC_PORT", "8009"))
  log_level: str = os.getenv("SYNC_LOG_LEVEL", "info")

  rethink_host: str = os.getenv("SYNC_RETHINK_HOST", "localhost")
  rethink_port: int = int(os.getenv("SYNC_RETHINK_PORT", "28015"))
  rethink_db: str = os.getenv("SYNC_RETHINK_DB", "sketchord")
  rethink_table_prefix: str = os.getenv("SYNC_RETHINK_TABLE_PREFIX", "sync")

  @property
  def normalized_backend(self) -> str:
    backend = self.db_backend
    if backend not in {"sqlite", "rethinkdb"}:
      return "sqlite"
    return backend

