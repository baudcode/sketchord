import logging
import os
from collections import namedtuple
from pydantic import BaseModel
from typing import Optional


class Connection(BaseModel):
    port: int
    host: str
    password: str
    username: str
    dbname: Optional[str]


def parse_uri(uri: str) -> Connection:
    tmp = uri.split("@")
    assert(len(tmp) == 2)
    username, password = tmp[0].split(":")
    second_split = tmp[1].split("/")

    if len(second_split) == 1:
        dbname = None
    else:
        dbname = second_split[1]

    host, port = second_split[0].split(":")
    port = int(port)
    return Connection(host=host, port=port, username=username, password=password, dbname=dbname)


def get_logger(name, level=logging.DEBUG, fh_level=logging.DEBUG, enable_file_logging=False, root_dir=''):

    logger = logging.getLogger(name)
    logger.propagate = False
    if not logger.handlers or len(logger.handlers) == 0:
        logger.setLevel(level)
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s')
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    if enable_file_logging and not any([isinstance(handler, logging.FileHandler) for handler in logger.handlers]):
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s')
        fh = logging.FileHandler(os.path.join(root_dir, '%s.log' % name))
        fh.setLevel(fh_level)
        fh.setFormatter(formatter)
        logger.addHandler(fh)

    return logger


logger = get_logger("IOT")
