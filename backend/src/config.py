import os


def get_var(name, default):
    if name in os.environ:
        return os.environ[name]
    else:
        return default


def is_debug():
    return get_var("DEBUG", True)


def get_database_uri():
    return get_var("DATABASE_URI", "root:1234@localhost:8086/iot")
