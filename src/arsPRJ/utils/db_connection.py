from contextlib import contextmanager
import psycopg2

from dataclasses import dataclass

@dataclass
class DBConnection:
    host: str
    port: str
    database: str
    user: str
    password: str

class WarehouseConnection:
    def __init__(self, db_connection: DBConnection):
        self.conn_url = (f"postgresql://{db_connection.user}:{db_connection.password}"
            f"@{db_connection.host}:{db_connection.port}/{db_connection.database}")
        
        self.conn = None
    
    @contextmanager
    def managed_cursor(self, cursor_factory=None):
        try:
            self.conn = psycopg2.connect(self.conn_url) if not self.conn else self.conn
            self.conn.autocommit = True
            cursor = self.conn.cursor(cursor_factory=cursor_factory) 
            yield cursor
        finally:
            if self.conn:
                self.conn.close()

        