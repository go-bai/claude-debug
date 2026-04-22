#!/bin/bash
# Non-sensitive vars via export:
#   export ANTHROPIC_BASE_URL=https://your-proxy.internal
#   export ANTHROPIC_MODEL=claude-opus-4-7
#   export ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
#
# ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY are prompted interactively (not stored in shell history)
#
# Optional:
#   CLAUDE_IMAGE  — image, default ghcr.io/go-bai/claude-debug:2.1.117
#   RUNTIME       — force runtime: nerdctl or docker

set -e

IMAGE="${CLAUDE_IMAGE:-ghcr.io/go-bai/claude-debug:latest}"

if [ -n "$RUNTIME" ]; then
  CTR="$RUNTIME"
elif command -v nerdctl &>/dev/null; then
  CTR="nerdctl"
elif command -v docker &>/dev/null; then
  CTR="docker"
else
  echo "ERROR: nerdctl and docker not found" >&2
  exit 1
fi

if [ -z "$ANTHROPIC_AUTH_TOKEN" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  read -rsp "ANTHROPIC_AUTH_TOKEN: " ANTHROPIC_AUTH_TOKEN
  echo
fi

TMPENV=$(mktemp)
chmod 600 "$TMPENV"
trap 'rm -f "$TMPENV"' EXIT

[ -n "$ANTHROPIC_AUTH_TOKEN" ] && echo "ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN}" >> "$TMPENV"
[ -n "$ANTHROPIC_API_KEY"    ] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"       >> "$TMPENV"

echo "Runtime: $CTR  Image: $IMAGE"

exec "$CTR" run --rm -it \
  --network host \
  --pid host \
  --ipc host \
  --privileged \
  -v /:/host \
  --env-file "$TMPENV" \
  ${ANTHROPIC_BASE_URL:+-e ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL"} \
  ${ANTHROPIC_MODEL:+-e ANTHROPIC_MODEL="$ANTHROPIC_MODEL"} \
  ${ANTHROPIC_SMALL_FAST_MODEL:+-e ANTHROPIC_SMALL_FAST_MODEL="$ANTHROPIC_SMALL_FAST_MODEL"} \
  "$IMAGE"
