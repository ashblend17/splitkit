"""The backend's version is written in a few places (tool/version.py bumps them together)."""

import re
import tomllib
from pathlib import Path

from app import __version__

API = Path(__file__).resolve().parents[1]


def test_the_backend_has_one_version():
    assert re.fullmatch(r"\d+\.\d+\.\d+", __version__), "semantic versioning"
    assert tomllib.loads((API / "pyproject.toml").read_text())["project"]["version"] == __version__
    lock = (API / "uv.lock").read_text()
    assert f'name = "api"\nversion = "{__version__}"' in lock


def test_the_spec_and_the_app_report_it():
    import json

    from app.main import app

    assert app.version == __version__
    assert json.loads((API / "openapi.json").read_text())["info"]["version"] == __version__
