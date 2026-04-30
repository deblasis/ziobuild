FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.16.0
ARG ZIG_VERSION=0.16.0
RUN curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-linux-x86_64-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /build

# Clone ghostty (shallow)
RUN git clone --depth 1 https://github.com/ghostty-org/ghostty.git

# Also clone ziobuild
RUN git clone https://github.com/deblasis/ziobuild.git

# Verify ghostty's original build works
WORKDIR /build/ghostty
RUN zig build --summary all 2>&1 || true

CMD ["/bin/bash"]
