import os
from pathlib import Path
from urllib.parse import quote

from dotenv import dotenv_values

# Must run before any app module reads settings. Tests take nothing from .env but where the
# database server is (its user, password and port, as docker compose starts it), use a database
# of their own on it ("<name>_test", never the dev one; or TEST_DATABASE_URL), and set the rest
# themselves, so a setting in .env can't change what they check.
os.environ["NO_DOTENV"] = "1"
os.environ["JWT_SECRET"] = "tests-only-secret-not-used-anywhere-else"
os.environ["SEED_PASSWORD"] = "tests-only-seed-password"
os.environ["APP_NAME"] = "App"
if not (url := os.environ.get("TEST_DATABASE_URL")):
    env = {**dotenv_values(Path(__file__).resolve().parents[2] / ".env"), **os.environ}
    user, name = quote(env.get("DB_USER") or "app"), quote(env.get("DB_NAME") or "app")
    password = quote(env.get("POSTGRES_PASSWORD") or "")
    port = env.get("DB_PORT") or 5433
    url = f"postgresql+psycopg://{user}:{password}@localhost:{port}/{name}_test"
os.environ["DATABASE_URL"] = url
