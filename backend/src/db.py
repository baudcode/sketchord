from rethinkdb import RethinkDB

from .utils import parse_uri


class RethinkClient(object):

    SONGS_TABLE = "songs"
    FILES_TABLE = "files"
    USERS_TABLE = "users"

    def __init__(self, uri):
        self.r = RethinkDB()
        self._connection = parse_uri(uri)
        self.r.connect(self._connection.host, self._connection.port).repl()

    def setup(self):
        self.r.db(self._connection.dbname).table_create(self.SONGS_TABLE).run()
        self.r.db(self._connection.dbname).table_create(self.FILES_TABLE).run()
        self.r.db(self._connection.dbname).table_create(self.USERS_TABLE).run()

    def _insert(self, table: str, data=[]):
        return self.r.table(table).insert(data).run()

    def insert(self, table: str, data={}):
        return self._insert(table, [data])

    def _iter(self, table):
        return self.r.table(table).run()

    def _get(self, table, id):
        return self.r.db(self._connection.dbname).table(table).get(id).run()

    def _update(self, table, id, new_data):
        return self.r.table(table).filter(self.r.row['id'] == id).update(new_data).run()


"""FEED:
cursor = r.table("authors").changes().run()
for document in cursor:
print(document)

{
  "new_val": {
    "id": "1d854219-85c6-4e6c-8259-dbda0ab386d4",
    "name": "Laura Roslin",
    "posts": [...],
    "tv_show": "Battlestar Galactica",
    "type": "fictional"
  },
  "old_val": {
    "id": "1d854219-85c6-4e6c-8259-dbda0ab386d4",
    "name": "Laura Roslin",
    "posts": [...],
    "tv_show": "Battlestar Galactica"
  }
}
"""
