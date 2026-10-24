#!/usr/bin/env python3
"""The UI's and the backend's versions, which are released on their own (README "Versions and
releases").

  python3 tool/version.py                     both versions, and each one's latest tag
  python3 tool/version.py bump ui minor       1.0.0 -> 1.1.0 (or patch, major, or 1.2.3)
  python3 tool/version.py bump api patch
  python3 tool/version.py tag ui              tags the commit: ui-v1.1.0 (api-v… for the backend);
                                              --no-sign skips signing it where git signs tags
  python3 tool/version.py check               the files that carry each version agree

ui is the app (Android, iOS and the web image); api is the backend (the API and the Tricount
worker image). A bump writes the new version wherever its part keeps one and turns the
"## Unreleased" notes in its CHANGELOG.md into that version's. Commit it, then tag. Nothing is
pushed.
"""

import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")

# Each part: where its version is written (file, pattern with the version as group 2), its
# changelog, the folder it lives in and its tag prefix. The first file is the one read.
PARTS = {
    "ui": {
        "name": "UI (app/)",
        "files": [
            ("app/pubspec.yaml", r"^(version:\s*)(\d+\.\d+\.\d+)(\s*)$"),
            ("app/lib/core/version.dart", r"^(  static const name = ')(\d+\.\d+\.\d+)(';)$"),
        ],
        "changelog": "app/CHANGELOG.md",
        "folder": "app",
        "tag": "ui-v",
    },
    "api": {
        "name": "Backend (api/)",
        "files": [
            ("api/app/__init__.py", r'^(__version__ = ")(\d+\.\d+\.\d+)(")$'),
            ("api/pyproject.toml", r'^(version = ")(\d+\.\d+\.\d+)(")$'),
            ("api/uv.lock", r'(?<=name = "api"\n)(version = ")(\d+\.\d+\.\d+)(")'),
            (
                "api/openapi.json",
                r'(?<="title": "API",\n)(\s*"version": ")(\d+\.\d+\.\d+)(")',
            ),
        ],
        "changelog": "api/CHANGELOG.md",
        "folder": "api",
        "tag": "api-v",
    },
}
ALIASES = {"ui": "ui", "app": "ui", "api": "api", "be": "api", "backend": "api"}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=False
    ).stdout.strip()


def part(name: str) -> dict:
    key = ALIASES.get(name.lower())
    if key is None:
        fail(f"{name!r} isn't ui or api")
    return PARTS[key]


def versions(p: dict) -> list[tuple[str, str | None]]:
    """(file, the version it has) for each file the part keeps one in."""
    found = []
    for file, pattern in p["files"]:
        m = re.search(pattern, (ROOT / file).read_text(encoding="utf-8"), re.M)
        found.append((file, m.group(2) if m else None))
    return found


def current(p: dict) -> str:
    seen = versions(p)
    if len({v for _, v in seen}) != 1 or seen[0][1] is None:
        fail(
            f"{p['name']}'s files disagree: "
            + ", ".join(f"{f} {v or '(none)'}" for f, v in seen)
            + ". Fix them, or set one with `bump … X.Y.Z`."
        )
    return seen[0][1]


def latest_tag(p: dict) -> str | None:
    tags = git("tag", "--list", f"{p['tag']}*", "--sort=-v:refname").splitlines()
    return tags[0] if tags else None


def next_version(now: str, how: str) -> str:
    if SEMVER.match(how):
        return how
    major, minor, patch = (int(x) for x in SEMVER.match(now).groups())
    if how == "major":
        return f"{major + 1}.0.0"
    if how == "minor":
        return f"{major}.{minor + 1}.0"
    if how == "patch":
        return f"{major}.{minor}.{patch + 1}"
    fail(f"{how!r} isn't patch, minor, major or a version like 1.2.3")


def release_notes(p: dict, version: str) -> str:
    """The changelog's notes for `version`."""
    text = (ROOT / p["changelog"]).read_text(encoding="utf-8")
    m = re.search(rf"^## {re.escape(version)}\b.*?\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1).strip() if m else ""


def show() -> None:
    for p in PARTS.values():
        tag = latest_tag(p)
        print(f"{p['name']}: {current(p)}  (latest tag: {tag or 'none yet'})")


def check() -> None:
    for p in PARTS.values():
        print(f"{p['name']}: {current(p)} in {len(p['files'])} files")


def bump(name: str, how: str) -> None:
    p = part(name)
    now = current(p)
    new = next_version(now, how)
    if tuple(map(int, new.split("."))) <= tuple(map(int, now.split("."))):
        fail(f"{new} isn't after {now}")
    for file, pattern in p["files"]:
        path = ROOT / file
        text = path.read_text(encoding="utf-8")
        path.write_text(
            re.sub(pattern, lambda m: m.group(1) + new + m.group(3), text, count=1, flags=re.M),
            encoding="utf-8",
        )
    log = ROOT / p["changelog"]
    text = log.read_text(encoding="utf-8")
    m = re.search(r"^## Unreleased\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if m is None:
        fail(f"{p['changelog']} has no '## Unreleased' section")
    notes = m.group(1).strip()
    if not notes:
        print(f"warning: {p['changelog']} has nothing under Unreleased", file=sys.stderr)
    section = f"## Unreleased\n\n## {new} · {date.today().isoformat()}\n\n"
    log.write_text(
        text[: m.start()] + section + (notes + "\n\n" if notes else "") + text[m.end() :],
        encoding="utf-8",
    )
    print(f"{p['name']}: {now} -> {new}")
    print(f"Next: commit it, then `python3 tool/version.py tag {name}`.")


def tag(name: str, sign: bool = True) -> None:
    p = part(name)
    version = current(p)
    if git("status", "--porcelain", "--", p["folder"]):
        fail(f"{p['folder']}/ has changes that aren't committed: commit them first")
    label = f"{p['tag']}{version}"
    if git("tag", "--list", label):
        fail(f"{label} already exists: bump the version first")
    notes = release_notes(p, version) or f"{p['name']} {version}"
    subprocess.run(
        [
            "git",
            "tag",
            "-a",
            *([] if sign else ["--no-sign"]),
            label,
            "-m",
            f"{p['name']} {version}\n\n{notes}",
        ],
        cwd=ROOT,
        check=True,
    )
    print(
        f"Tagged {git('rev-parse', '--short', 'HEAD')} as {label}. "
        f"Push it with `git push origin {label}`."
    )


def main(args: list[str]) -> None:
    match args:
        case [] | ["show"]:
            show()
        case ["check"]:
            check()
        case ["bump", name, how]:
            bump(name, how)
        case ["tag", name]:
            tag(name)
        case ["tag", name, "--no-sign"]:
            tag(name, sign=False)
        case _:
            print(__doc__)
            sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
