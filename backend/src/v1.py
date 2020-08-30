from fastapi import APIRouter, FastAPI, Request, HTTPException

from .requestvars import g

router = APIRouter()


def include_routes(app: FastAPI):
    app.include_router(router, prefix='')
