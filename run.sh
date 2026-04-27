#!/bin/bash
# Non-sensitive vars via export:
#   export ANTHROPIC_BASE_URL=https://your-proxy.internal
#   export ANTHROPIC_MODEL=claude-opus-4-7
#   export ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
#
# ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY are prompted interactively (not stored in shell history)
#
# Optional:
#   CLAUDE_IMAGE      — image, default ghcr.io/go-bai/claude-debug:latest
#   CLAUDE_CONTAINER  — container name, default claude-debug
#   RUNTIME           — force runtime: nerdctl or docker

set -e

IMAGE="${CLAUDE_IMAGE:-ghcr.io/go-bai/claude-debug:latest}"
CONTAINER="${CLAUDE_CONTAINER:-claude-debug}"

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
  export ANTHROPIC_AUTH_TOKEN
fi

STATUS=$("$CTR" inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || true)

if [ -z "$STATUS" ]; then
  MOUNTS=()

  if [ -f /root/.kube/config ]; then
    TMPKUBE=$(mktemp -d)
    cp /root/.kube/config "$TMPKUBE/config"
    chown 1001:1001 "$TMPKUBE/config"
    chmod 600 "$TMPKUBE/config"
    MOUNTS+=(-v "$TMPKUBE/config":/home/claude/.kube/config:ro)
  fi

  if [ -d /root/.ssh ]; then
    TMPSSH=$(mktemp -d)
    cp -r /root/.ssh/. "$TMPSSH/"
    chown -R 1001:1001 "$TMPSSH"
    chmod 700 "$TMPSSH"
    find "$TMPSSH" -maxdepth 1 \( -name "*.pub" -o -name "known_hosts" \) -exec chmod 644 {} \;
    MOUNTS+=(-v "$TMPSSH":/home/claude/.ssh)
  fi

  HOST_PATH=$(echo "$PATH" | tr ':' '\n' | sed 's|^|/host|' | tr '\n' ':')

  echo "Starting container $CONTAINER"
  "$CTR" run -d \
    --name "$CONTAINER" \
    --network host \
    --pid host \
    --ipc host \
    --privileged \
    -v /:/host \
    -v /etc/hosts:/etc/hosts:ro \
    "${MOUNTS[@]}" \
    -e PATH="${HOST_PATH}${PATH}" \
    "$IMAGE"

elif [ "$STATUS" != "running" ]; then
  echo "Resuming container $CONTAINER"
  "$CTR" start "$CONTAINER"
else
  echo "Using existing container $CONTAINER"
fi

exec "$CTR" exec -it \
  ${ANTHROPIC_AUTH_TOKEN:+--env ANTHROPIC_AUTH_TOKEN} \
  ${ANTHROPIC_API_KEY:+--env ANTHROPIC_API_KEY} \
  ${ANTHROPIC_BASE_URL:+--env ANTHROPIC_BASE_URL} \
  ${ANTHROPIC_MODEL:+--env ANTHROPIC_MODEL} \
  ${ANTHROPIC_SMALL_FAST_MODEL:+--env ANTHROPIC_SMALL_FAST_MODEL} \
  "$CONTAINER" \
  claude --dangerously-skip-permissions
