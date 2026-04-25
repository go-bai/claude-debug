# claude-debug

A container image for running [Claude Code](https://claude.ai/code) on a Linux host without SSH access.

The container shares the host's network stack, PID namespace, and filesystem, giving Claude Code full visibility into the running system.

## Requirements

- `nerdctl` or `docker` on the target host
- A Kubernetes node or any Linux machine running containerd

## Build

Push to the `main` branch triggers a GitHub Actions workflow that:

1. Fetches the latest `@anthropic-ai/claude-code` version from npm
2. Skips if `ghcr.io/go-bai/claude-debug:<version>` already exists
3. Builds and pushes `linux/amd64` + `linux/arm64` images tagged with the version and `latest`

## Usage

```bash
# Set non-sensitive vars via export (optional)
export ANTHROPIC_BASE_URL=https://your-proxy.internal
export ANTHROPIC_MODEL=claude-opus-4-7
export ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001

# Run — token is prompted interactively and never written to shell history
bash <(curl -fsSL https://raw.githubusercontent.com/go-bai/claude-debug/main/run.sh)
```

### Environment variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | one of these two | Prompted interactively if not set |
| `ANTHROPIC_API_KEY` | one of these two | Prompted interactively if not set |
| `ANTHROPIC_BASE_URL` | No | API proxy endpoint |
| `ANTHROPIC_MODEL` | No | Primary model |
| `ANTHROPIC_SMALL_FAST_MODEL` | No | Fast/cheap model for background tasks |
| `CLAUDE_IMAGE` | No | Override image; auto-uses `m.daocloud.io` mirror when in China |
| `RUNTIME` | No | Force `nerdctl` or `docker` |

## Host access

| Flag | Effect |
|---|---|
| `--network host` | Shares host network stack — all interfaces and ports visible |
| `--pid host` | Shares host PID namespace — can attach to any running process |
| `--ipc host` | Shares host IPC namespace |
| `--privileged` | All Linux capabilities, access to `/dev` including `/dev/infiniband/*` and `/dev/mem` |
| `-v /:/host` | Full host filesystem mounted at `/host` (WORKDIR is `/host`) |

## DMA / RDMA debugging

The image includes userspace RDMA tools. With `--privileged --network host`, the container can:

- Inspect IB/RoCE devices via `ibv_devinfo`, `ibstat`, `ibstatus`
- Run bandwidth/latency tests via `ib_read_bw`, `ib_send_lat` (perftest)
- Read PCI device and memory mappings via `lspci -v`, `/proc/iomem`
- Attach to running RDMA processes via `/proc/<pid>/maps` and `strace`

## Security

`ANTHROPIC_AUTH_TOKEN` is read via `read -s` and passed to the container via `--env ANTHROPIC_AUTH_TOKEN` (no value on the command line). It never appears in `ps aux` or shell history.

Note: the token remains visible in `docker inspect` / `nerdctl inspect` and `/proc/<pid>/environ` inside the container — inherent to how container environment variables work.
