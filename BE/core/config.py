import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    database_url: str = os.environ["DATABASE_URL"]
    secret_key: str = os.environ["SECRET_KEY"]
    app_name: str = os.environ["APP_NAME"]
    debug: bool = os.environ["DEBUG"]

settings = Settings()