#!/usr/bin/env bash
# Regenerate the Dart API client (app/packages/splitkit_api) from the API's OpenAPI spec.
# Uses openapi-generator's plain `dart` target (no build_runner). See dart_client_spec() in
# api/app/openapi.py for the two spec adjustments that target needs.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d "$PWD/.openapi-XXXX")"
trap 'rm -rf "$tmp"' EXIT
(cd api && uv run python -m app.openapi --dart-client "$tmp/openapi.json")
# A one-value Literal with a default (trigger, valuation_source) is a `const`, which the
# generator also makes an enum with a string default (`?? 'manual'`, which doesn't compile).
# Treat it as dart_client_spec treats enums: no default, required, so the app always sends it.
python3 - "$tmp/openapi.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    spec = json.load(f)
for schema in spec["components"]["schemas"].values():
    for name, prop in schema.get("properties", {}).items():
        if "const" in prop and "default" in prop:
            del prop["default"]
            schema.setdefault("required", []).append(name)
with open(path, "w", encoding="utf-8") as f:
    json.dump(spec, f, indent=2)
PY
rm -rf app/packages/splitkit_api
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/work" openapitools/openapi-generator-cli:v7.16.0 generate \
  -i "/work/$(basename "$tmp")/openapi.json" \
  -g dart \
  -o /work/app/packages/splitkit_api \
  --additional-properties=pubName=splitkit_api,pubDescription="Generated Splitkit API client",pubAuthor=Splitkit \
  --global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false \
  > /dev/null
echo "Generated app/packages/splitkit_api"
