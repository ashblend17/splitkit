"""Tricount sync worker.  Usage: python -m app.modules.tricount_sync [--once]"""

import argparse
import logging
import sys

from app.modules.tricount_sync import worker


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="python -m app.modules.tricount_sync", description=__doc__
    )
    parser.add_argument("--once", action="store_true", help="run one round and exit")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # one line per request is too much
    if args.once:
        print(f"Ran {worker.tick()} sync passes")
        return 0
    worker.loop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
