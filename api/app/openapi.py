"""Write the OpenAPI spec to api/openapi.json (the Dart client is generated from it).

Usage:
  python -m app.openapi                      (tests/test_openapi.py fails if the file is stale)
  python -m app.openapi --dart-client PATH   (spec adjusted for openapi-generator's dart target)
"""

import copy
import json
import sys
from pathlib import Path

SPEC_PATH = Path(__file__).parents[1] / "openapi.json"


def spec() -> dict:
    from app.main import app

    return app.openapi()


def render() -> str:
    return json.dumps(spec(), indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def dart_client_spec(source: dict) -> dict:
    """Work around two openapi-generator `dart` bugs with OpenAPI 3.1 input:

    - FastAPI's ValidationError.loc items (string | integer) generate an uncompilable model;
      the app never parses 422 details with the client, so loc items are typed as strings.
    - An enum property with a default generates `?? 'upi'` against an enum type, and an
      optional one is sent as null (which the API rejects). Such properties become required
      in the client, so the app always sends an explicit value.
    - Required-but-nullable properties (anyOf with null) trip a debug assertion that rejects
      null for required keys; the client treats them as optional (still nullable types).
    """
    out = copy.deepcopy(source)
    schemas = out["components"]["schemas"]
    if "ValidationError" in schemas:
        schemas["ValidationError"]["properties"]["loc"]["items"] = {"type": "string"}
    for schema in schemas.values():
        for name, prop in schema.get("properties", {}).items():
            if "enum" in prop and "default" in prop:
                del prop["default"]
                schema.setdefault("required", []).append(name)
        nullable = {
            name
            for name, prop in schema.get("properties", {}).items()
            if any(option.get("type") == "null" for option in prop.get("anyOf", []))
        }
        if "required" in schema:
            schema["required"] = [name for name in schema["required"] if name not in nullable]
    return out


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--dart-client":
        client = json.dumps(dart_client_spec(spec()), indent=2)
        Path(sys.argv[2]).write_text(client, encoding="utf-8")
    else:
        SPEC_PATH.write_text(render(), encoding="utf-8")
        print(f"Wrote {SPEC_PATH}")
