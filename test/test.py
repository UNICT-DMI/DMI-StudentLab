import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'BE'))

from core.config import settings
from core.database import engine

print(f"\033[35m{settings.app_name}")
print(f"{settings.database_url[:20]}...")

print("\nTest connessione database...")
try:
    with engine.connect() as conn:
        print("\033[34m~o~\033[0m")
except Exception as e:
    print(f"\n\033[31mError: {e}\033[0m\n")

