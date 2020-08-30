import contextvars

from pydantic import BaseModel
from .db import RethinkClient
from typing import Optional


class Context(BaseModel):
    db: Optional[RethinkClient]

    class Config:
        arbitrary_types_allowed = True


request_global = contextvars.ContextVar(
    "request_global", default=Context(db=None))


def g():
    return request_global.get()
