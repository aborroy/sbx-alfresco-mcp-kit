#!/usr/bin/env bash
# Publish the alfresco-mcp kit as an OCI artifact to a registry.
#
# `sbx kit push` packages the directory EXACTLY as-is — it ignores .gitignore
# and .dockerignore. So we never push the source tree directly; we rsync a
# clean copy into a staging dir (dropping .git, .venv, .sbx, editor cruft,
# archives), validate it, then push the staged copy.
#
# Usage:
#   DOCKER_NAMESPACE=youruser ./scripts/publish.sh                 # pushes :1.1.0 and :latest
#   DOCKER_NAMESPACE=youruser KIT_VERSION=1.1.0 ./scripts/publish.sh
#   DOCKER_NAMESPACE=youruser DRY_RUN=1 ./scripts/publish.sh       # stage + validate only, no push
#
# Prerequisites: `sbx` on PATH and `sbx login` already done (and `docker login`
# for the target registry). On macOS: `brew install docker/tap/sbx`.

set -euo pipefail

KIT=alfresco-mcp
# Tag the image with the pinned upstream MCP-server version for traceability.
# Bump this in lockstep with MCP_REF/MCP_SHA256 in alfresco-mcp/spec.yaml.
KIT_VERSION="${KIT_VERSION:-1.1.0}"
REGISTRY="${REGISTRY:-docker.io}"
DRY_RUN="${DRY_RUN:-0}"

if [ -z "${DOCKER_NAMESPACE:-}" ]; then
  echo "error: set DOCKER_NAMESPACE (your Docker Hub username/org)" >&2
  exit 2
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE="${REGISTRY}/${DOCKER_NAMESPACE}/sbx-${KIT}-kit"

# --- stage a clean copy ------------------------------------------------------
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

copy_kit() {
  local kit="$1"
  mkdir -p "$stage/$kit"
  rsync -a \
    --exclude '.git' --exclude '.venv' --exclude '.DS_Store' \
    --exclude '.sbx' --exclude '*.tar' --exclude '*.zip' \
    "$REPO_ROOT/$kit/" "$stage/$kit/"
}
copy_kit "$KIT"

# --- validate the STAGED copy (what we actually ship) ------------------------
echo "==> validating $stage/$KIT"
sbx kit validate "$stage/$KIT"

# --- push (unless dry run) ---------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "==> DRY_RUN=1, skipping push. Would push:"
  echo "      $IMAGE:$KIT_VERSION"
  echo "      $IMAGE:latest"
  exit 0
fi

for tag in "$KIT_VERSION" latest; do
  echo "==> pushing $IMAGE:$tag"
  sbx kit push "$stage/$KIT" "$IMAGE:$tag"
done

echo "==> done. Consume with:"
echo "      sbx run claude --kit $IMAGE:$KIT_VERSION ."
