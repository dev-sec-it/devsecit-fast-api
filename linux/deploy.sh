#!/usr/bin/env bash
set -e

# ==============================================================================
# DEV SEC IT - DevSecIt Rust API Server Deployment & Service Script
# Supports: x86_64 (amd64) and aarch64 (arm64)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  read -p "Enter port number to deploy [default: 8899]: " USER_PORT
  if [ -n "${USER_PORT}" ]; then
    PORT="${USER_PORT}"
  else
    PORT="8899"
  fi
fi

# Validate port number
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
  echo "[-] Invalid port number: ${PORT}. Must be an integer between 1 and 65535."
  exit 1
fi

echo "=============================================================================="
echo ">>> DEV SEC IT - Deploying Rust API on Port ${PORT}..."
echo "=============================================================================="

# 1. Detect Host CPU Architecture (ARM64 vs x86_64)
ARCH=$(uname -m)
echo "[+] Detected system architecture: ${ARCH}"

case "${ARCH}" in
  aarch64|arm64)
    ARCH_DIR="arm64"
    ;;
  x86_64|amd64)
    ARCH_DIR="x86_64"
    ;;
  *)
    ARCH_DIR=""
    ;;
esac

# 2. Locate Matching Architecture Binary
SELECTED_BIN=""

# Check architecture specific subfolder first
if [ -n "${ARCH_DIR}" ] && [ -f "${SCRIPT_DIR}/${ARCH_DIR}/devsecit-rust-api" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/${ARCH_DIR}/devsecit-rust-api"
elif [ -n "${ARCH_DIR}" ] && [ -f "${SCRIPT_DIR}/${ARCH_DIR}/dsiapi" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/${ARCH_DIR}/dsiapi"
# Check script root directory
elif [ -f "${SCRIPT_DIR}/devsecit-rust-api" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/devsecit-rust-api"
elif [ -f "${SCRIPT_DIR}/dsiapi" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/dsiapi"
# Check parent target/release if running in repo build folder
elif [ -f "${SCRIPT_DIR}/../target/release/devsecit-rust-api" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/../target/release/devsecit-rust-api"
elif [ -f "${SCRIPT_DIR}/../target/release/dsiapi" ]; then
  SELECTED_BIN="${SCRIPT_DIR}/../target/release/dsiapi"
fi

if [ -z "${SELECTED_BIN}" ] || [ ! -f "${SELECTED_BIN}" ]; then
  echo "[-] Error: No compatible binary found for architecture '${ARCH}'."
  echo "[-] Expected binary at: ${SCRIPT_DIR}/${ARCH_DIR}/devsecit-rust-api or ${SCRIPT_DIR}/devsecit-rust-api"
  exit 1
fi

BIN_PATH="${SCRIPT_DIR}/devsecit-rust-api"
if [ "${SELECTED_BIN}" != "${BIN_PATH}" ]; then
  echo "[+] Installing ${ARCH} binary: ${SELECTED_BIN} -> ${BIN_PATH}"
  cp -f "${SELECTED_BIN}" "${BIN_PATH}"
fi

chmod +x "${BIN_PATH}"
echo "[+] Binary verified and executable: ${BIN_PATH}"

# 3. Dynamically Generate Systemd Service Unit
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

echo "[+] Creating systemd service: ${SERVICE_FILE}"
sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=DevSecIt Rust API Server (Port ${PORT})
After=network.target

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${BIN_PATH} start -p ${PORT} --dev --no-gui
Restart=always
RestartSec=3s
LimitNOFILE=65536
EnvironmentFile=-${SCRIPT_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

# 4. Activate Service via systemctl
echo "[+] Activating service via systemctl..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"

echo ">>> Service status:"
sudo systemctl status "${SERVICE_NAME}" --no-pager

echo ""
echo "=============================================================================="
echo ">>> [SUCCESS] DevSecIt Rust API (${ARCH}) running on: http://0.0.0.0:${PORT}"
echo "=============================================================================="
