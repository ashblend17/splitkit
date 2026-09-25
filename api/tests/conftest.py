import os

# Must run before any app module reads settings: tests never touch the dev database.
os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://splitkit:splitkit@localhost:5433/splitkit_test"
)
