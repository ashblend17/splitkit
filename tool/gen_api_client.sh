#!/usr/bin/env bash
# Regenerate the Dart API client (app/packages/splitkit_api) from the API's OpenAPI spec.
# Uses openapi-generator's plain `dart` target (no build_runner). See dart_client_spec() in
# api/app/openapi.py for the two spec adjustments that target needs.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d "$PWD/.openapi-XXXX")"
trap 'rm -rf "$tmp"' EXIT
(cd api && uv run python -m app.openapi --dart-client "$tmp/openapi.json")
rm -rf app/packages/splitkit_api
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/work" openapitools/openapi-generator-cli:v7.16.0 generate \
  -i "/work/$(basename "$tmp")/openapi.json" \
  -g dart \
  -o /work/app/packages/splitkit_api \
  --additional-properties=pubName=splitkit_api,pubDescription="Generated Splitkit API client",pubAuthor=Splitkit \
  --global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false \
  > /dev/null
echo "Generated app/packages/splitkit_api"
