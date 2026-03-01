from sketchord_sync_backend.config import Settings
from sketchord_sync_backend.storage.base import SyncRepository


def create_repository(settings: Settings) -> SyncRepository:
    if settings.normalized_backend == "rethinkdb":
        from sketchord_sync_backend.storage.rethink_repo import RethinkSyncRepository

        repo = RethinkSyncRepository(
            host=settings.rethink_host,
            port=settings.rethink_port,
            db_name=settings.rethink_db,
            table_prefix=settings.rethink_table_prefix,
        )
    else:
        from sketchord_sync_backend.storage.sqlite_repo import SqliteSyncRepository

        repo = SqliteSyncRepository(db_path=settings.sqlite_path)
    repo.ensure_schema()
    return repo
