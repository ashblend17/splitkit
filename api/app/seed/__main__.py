"""Load the mockup sample data.  Usage: python -m app.seed [--reset]"""

import argparse
import sys

from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.models import User
from app.seed import data
from app.seed.loader import load, reset


def main() -> int:
    parser = argparse.ArgumentParser(prog="python -m app.seed", description=__doc__)
    parser.add_argument("--reset", action="store_true", help="wipe every table first")
    args = parser.parse_args()

    if get_settings().env == "prod":
        print("Refusing to seed a production database.", file=sys.stderr)
        return 1

    with SessionLocal.begin() as session:
        if args.reset:
            reset(session)
        elif session.scalar(select(func.count()).select_from(User)):
            print("Database already has data. Use --reset to wipe and reseed.", file=sys.stderr)
            return 1
        counts = load(session)

    print("Seeded: " + ", ".join(f"{n} {k.replace('_', ' ')}" for k, n in counts.items()))
    print(
        f"Log in as any seeded user with password '{data.DEV_PASSWORD}', "
        f"e.g. {data.USERS[0].email} (admin)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
