import os
from dotenv import load_dotenv
from arsPRJ.utils.db_connection import DBConnection

def get_db_config():
    load_dotenv()  
    DBConfig = DBConnection(
        host=os.getenv('DB_HOST', 'localhost'),
        port=os.getenv('DB_PORT', '5432'),
        database=os.getenv('DB_NAME', ''),
        user=os.getenv('DB_USER', ''),
        password=os.getenv('DB_PASSWORD', '')
    )

    return DBConfig