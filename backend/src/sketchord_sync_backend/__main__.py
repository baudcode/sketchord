import uvicorn

from sketchord_sync_backend.app import create_app
from sketchord_sync_backend.config import Settings


def main() -> None:
    settings = Settings()
    uvicorn.run(
        "sketchord_sync_backend.app:create_app",
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level,
        factory=True,
    )


if __name__ == "__main__":
    main()

