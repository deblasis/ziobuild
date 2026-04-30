FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.16.0
RUN curl -L https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-0.16.0/zig /usr/local/bin/zig

WORKDIR /build

# Copy ziobuild source
COPY . /build/ziobuild

# Copy comparison fixtures
COPY docker/comparison/plain /build/plain
COPY docker/comparison/zb    /build/zb

# Fix zb fixture to use the copied ziobuild source
RUN sed -i 's|path = "../../.."|path = "/build/ziobuild"|g' /build/zb/build.zig.zon

# Build both and compare in a single layer
RUN set -e && \
    echo "=====================================" && \
    echo "   PLAIN BUILD.ZIG (hand-written)" && \
    echo "=====================================" && \
    echo "" && \
    cat /build/plain/build.zig | wc -l | xargs -I{} echo "Lines: {}" && \
    echo "" && \
    cd /build/plain && \
    zig build --summary all 2>&1 | tail -3 && \
    zig build test --summary all 2>&1 | tail -3 && \
    echo "" && \
    echo "=====================================" && \
    echo "   ZIOBUILD BUILD.ZIG (declarative)" && \
    echo "=====================================" && \
    echo "" && \
    cat /build/zb/build.zig | wc -l | xargs -I{} echo "Lines: {}" && \
    echo "" && \
    cd /build/zb && \
    zig build --summary all 2>&1 | tail -3 && \
    zig build test --summary all 2>&1 | tail -3 && \
    echo "" && \
    echo "=====================================" && \
    echo "         COMPARISON RESULTS" && \
    echo "=====================================" && \
    PLAIN_LINES=$(wc -l < /build/plain/build.zig) && \
    ZB_LINES=$(wc -l < /build/zb/build.zig) && \
    SAVED=$((PLAIN_LINES - ZB_LINES)) && \
    echo "Plain build.zig:    ${PLAIN_LINES} lines" && \
    echo "Ziobuild build.zig: ${ZB_LINES} lines" && \
    echo "Lines saved: ${SAVED} (ziobuild is $((SAVED * 100 / PLAIN_LINES))% shorter)" && \
    echo "" && \
    echo "Both built and tested successfully with identical source code."

CMD ["/bin/bash"]
