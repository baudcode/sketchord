from fastapi import APIRouter, FastAPI, Request, HTTPException

from .requestvars import g
from .ultimate import get_note

router = APIRouter()

@router.get('/ultimate')
def get_ultimate_guitar_song(url: str):
    return get_note(url)


def include_routes(app: FastAPI):
    app.include_router(router, prefix='')
