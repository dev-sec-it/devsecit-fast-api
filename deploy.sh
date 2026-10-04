#!/usr/bin/env bash
set -e

# ==============================================================================
# DEV SEC IT - DevSecIt Rust API Server Deployment & Service Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="${SCRIPT_DIR}/devsecit-rust-api"
SERVICE_NAME="devsecit-api.service"

# Parse CLI arguments if provided
PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port|-p)
      PORT="$2"
      shift 2
      ;;
    --port=*)
      PORT="${1#*=}"
      shift
      ;;
    -p=*)
      PORT="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        PORT="$1"
      fi
      shift
      ;;
  esac
done

# If port not provided via arguments, interactively ask the user
if [ -z "${PORT}" ]; then
  read -p "Enter port number to deploy [default: 3000]: " USER_PORT
  if [ -n "${USER_PORT}" ]; then
    PORT="${USER_PORT}"
  else
    PORT="3000"
  fi
fi

# Validate port number
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
  echo "[-] Invalid port number: ${PORT}. Must be an integer between 1 and 65535."
  exit 1
fi

echo ">>> Deploying DevSecIt Rust API on Port ${PORT}..."

# Check if binary exists in current directory or parent target/release
if [ ! -f "${BIN_PATH}" ]; then
  if [ -f "${SCRIPT_DIR}/../target/release/devsecit-rust-api" ]; then
    BIN_PATH="${SCRIPT_DIR}/../target/release/devsecit-rust-api"
  elif [ -f "$(pwd)/devsecit-rust-api" ]; then
    BIN_PATH="$(pwd)/devsecit-rust-api"
    SCRIPT_DIR="$(pwd)"
  else
    echo "[-] Error: 'devsecit-rust-api' binary not found in ${SCRIPT_DIR}."
    exit 1
  fi
fi

chmod +x "${BIN_PATH}"
echo "[+] Binary found and executable: ${BIN_PATH}"

# Dynamically generate systemd service unit
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

echo "[+] Creating systemd service: ${SERVICE_FILE}"
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=DevSecIt Rust API Server (Port ${PORT})
After=network.target

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${BIN_PATH} --port ${PORT}
Restart=always
RestartSec=3s
LimitNOFILE=65536
EnvironmentFile=-${SCRIPT_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

# Activate service via systemctl
echo "[+] Connecting and activating service via systemctl..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"

echo ">>> Service status:"
sudo systemctl status "${SERVICE_NAME}" --no-pager

echo ""
echo ">>> Successfully deployed and running on http://0.0.0.0:${PORT}"
