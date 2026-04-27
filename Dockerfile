FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    # general
    curl wget ca-certificates less vim jq \
    # process / system
    procps htop lsof strace \
    # network
    net-tools iproute2 iputils-ping \
    # PCI / DMA devices
    pciutils \
    # RDMA / InfiniBand userspace tools
    rdma-core \
    ibverbs-utils \
    infiniband-diags \
    perftest \
    && rm -rf /var/lib/apt/lists/*

ARG CLAUDE_CODE_VERSION
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# non-root user required by Claude Code (--privileged preserves all diagnostic capabilities)
RUN useradd -m claude
USER claude

WORKDIR /host

CMD ["sleep", "infinity"]
