# ── Stage 1: Build NullClaw from source ──────────────────────────
FROM alpine:3.21 AS nullclaw-builder

RUN apk add --no-cache sqlite-dev musl-dev git xz curl pkgconf

RUN ARCH=$(uname -m) && \
    curl -L "https://ziglang.org/download/0.15.2/zig-${ARCH}-linux-0.15.2.tar.xz" | tar xJ -C /opt && \
    ln -s /opt/zig-${ARCH}-linux-0.15.2/zig /usr/local/bin/zig

WORKDIR /build
RUN git clone --depth 1 https://github.com/nullclaw/nullclaw.git .
RUN SQLITE_INC=$(pkg-config --variable=includedir sqlite3) && \
    SQLITE_LIB=$(pkg-config --variable=libdir sqlite3) && \
    zig build -Doptimize=ReleaseSmall \
      -Dsqlite-include="$SQLITE_INC" \
      -Dsqlite-lib="$SQLITE_LIB"

# ── Stage 2: Build Node.js health server ─────────────────────────
FROM node:18-alpine AS node-builder

WORKDIR /app
COPY package.json ./
RUN npm install
COPY src/ ./src/
COPY tsconfig.json ./
RUN npm run build

# ── Stage 3: Production image ───────────────────────────────────
FROM node:18-alpine

RUN apk add --no-cache curl sqlite-libs

# NullClaw binary
COPY --from=nullclaw-builder /build/zig-out/bin/nullclaw /usr/local/bin/nullclaw
RUN chmod +x /usr/local/bin/nullclaw

# NullClaw data dirs
RUN mkdir -p /nullclaw-data/.nullclaw /nullclaw-data/workspace
ENV HOME=/nullclaw-data
ENV NULLCLAW_WORKSPACE=/nullclaw-data/workspace

# Node health server (production deps only)
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY --from=node-builder /app/dist ./dist

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000

CMD ["/start.sh"]
