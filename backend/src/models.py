from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ID(BaseModel):
    id: str
    created_at: datetime
    last_modified: datetime


class AudioFile(ID):
    local_path: str
    duration: str
    name: str


class Section(ID):
    title: str
    content: str


class Note(ID):
    title: str
    key: Optional[str]
    tuning: Optional[str]
    label: Optional[str]
    instrument: Optional[str]
    starred: bool
    capo: Optional[str]
    seections: List[Section]
    # has audiofiles and sections attached
