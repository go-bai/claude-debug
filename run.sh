#!/bin/bash
# Non-sensitive vars via export:
#   export ANTHROPIC_BASE_URL=https://your-proxy.internal
#   export ANTHROPIC_MODEL=claude-opus-4-7
#   export ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
#
# ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY are prompted interactively (not stored in shell history)
#
# Optional:
#   CLAUDE_IMAGE  — image, default ghcr.io/go-bai/claude-debug:latest
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

echo "Runtime: $CTR  Image: $IMAGE"

exec "$CTR" run --rm -it \
  --network host \
  --pid host \
  --ipc host \
  --privileged \
  -v /:/host \
  ${ANTHROPIC_AUTH_TOKEN:+--env ANTHROPIC_AUTH_TOKEN} \
  ${ANTHROPIC_API_KEY:+--env ANTHROPIC_API_KEY} \
  ${ANTHROPIC_BASE_URL:+--env ANTHROPIC_BASE_URL} \
  ${ANTHROPIC_MODEL:+--env ANTHROPIC_MODEL} \
  ${ANTHROPIC_SMALL_FAST_MODEL:+--env ANTHROPIC_SMALL_FAST_MODEL} \
  "$IMAGE"
