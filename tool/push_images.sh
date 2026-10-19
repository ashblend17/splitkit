#!/usr/bin/env bash
# Build the API and web images and push them for docker-compose.prod.yml, so the server only
# pulls. Each is a tag in one repo (split-api, split-web, split-tricount), so they can share a
# private repo with other projects. They're built for this machine's CPU: a Graviton (arm64)
# server can't run them.
# Usage: tool/push_images.sh <user>/<repo>   (needs `docker login`)
set -euo pipefail
cd "$(dirname "$0")/.."
image="${1:?usage: tool/push_images.sh <user>/<repo>}"
docker compose build api web tricount
for svc in api web tricount; do
  docker tag "splitkit-$svc" "$image:split-$svc"
  docker push "$image:split-$svc"
done
