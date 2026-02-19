#!/bin/sh
set -e

CONFIG_DIR="/nullclaw-data/.nullclaw"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR" "/nullclaw-data/workspace"

# Build config.json from environment variables
cat > "$CONFIG_FILE" << EOF
{
  "api_key": "${OPENROUTER_API_KEY}",
  "default_provider": "openrouter",
  "default_model": "${NULLCLAW_MODEL:-anthropic/claude-sonnet-4}",
  "default_temperature": 0.7,
  "channels": {
    "cli": false,
    "telegram": {
      "bot_token": "${TELEGRAM_BOT_TOKEN}",
      "allowed_users": ["${TELEGRAM_ALLOWED_USERS:-*}"]
    }
  },
  "gateway": {
    "port": 3001,
    "host": "127.0.0.1",
    "require_pairing": false,
    "allow_public_bind": false
  },
  "autonomy": {
    "level": "supervised",
    "workspace_only": true,
    "max_actions_per_hour": 20
  },
  "memory": {
    "backend": "sqlite",
    "auto_save": true
  },
  "security": {
    "sandbox": { "backend": "none" },
    "audit": { "enabled": true }
  }
}
EOF

echo "NullClaw config written to $CONFIG_FILE"
echo "Starting NullClaw daemon..."

# Start NullClaw daemon in background
nullclaw daemon &
NULLCLAW_PID=$!

echo "NullClaw daemon started (PID: $NULLCLAW_PID)"
echo "Starting Express health server..."

# Start Express health server in foreground
cd /app
node dist/index.js &
NODE_PID=$!

echo "Health server started (PID: $NODE_PID)"

# Wait for either process to exit
wait -n $NULLCLAW_PID $NODE_PID 2>/dev/null || true

echo "A process exited, shutting down..."
kill $NULLCLAW_PID $NODE_PID 2>/dev/null || true
wait
