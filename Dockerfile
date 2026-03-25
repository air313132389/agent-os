# === Build Stage ===
FROM node:20-bookworm AS builder

WORKDIR /app

# Install build dependencies for native modules (node-pty, better-sqlite3)
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# === Production Stage ===
FROM node:20-bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    tmux \
    ripgrep \
    git \
    zsh \
    curl \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Install tsx globally (needed to run server.ts)
RUN npm install -g tsx

# Copy built application from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/server.ts ./server.ts
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json
COPY --from=builder /app/public ./public
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/app ./app
COPY --from=builder /app/components ./components
COPY --from=builder /app/contexts ./contexts
COPY --from=builder /app/hooks ./hooks
COPY --from=builder /app/stores ./stores
COPY --from=builder /app/styles ./styles
COPY --from=builder /app/mcp ./mcp
COPY --from=builder /app/data ./data

# Rebuild native modules for production image
RUN npm rebuild node-pty better-sqlite3

# Create persistent data directories
RUN mkdir -p /lzcapp/var/data /lzcapp/var/projects /lzcapp/var/config

# Environment
ENV NODE_ENV=production
ENV PORT=3011
ENV DB_PATH=/lzcapp/var/data/agent-os.db
ENV HOME=/root
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

EXPOSE 3011

CMD ["tsx", "server.ts"]
