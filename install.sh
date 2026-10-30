#!/usr/bin/env bash
# ==============================================================================
# DEV SEC IT - Universal Multi-Platform Installer
# Auto-detects OS & Architecture:
#   - Windows        -> Launches windows/windows.exe (NSIS Setup)
#   - Linux x86_64   -> Deploys 64-bit Static Binary + Systemd Service + Port Binding
#   - Linux aarch64  -> Deploys ARM64 Static Binary + Systemd Service + Port Binding
#
# Usage:
#   ./install.sh                     (Interactive prompt for port)
#   ./install.sh --port 8000         (Direct deployment on port 8000)
#   ./install 8000                   (Direct deployment on port 8000)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="devsecit-api.service"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${CYAN}${BOLD}       ⚡ DEV SEC IT - UNIVERSAL MULTI-PLATFORM INSTALLER ⚡       ${NC}"
echo -e "${CYAN}==============================================================================${NC}"

# ------------------------------------------------------------------------------
# STEP 1: OS Detection (Windows vs Linux vs macOS)
# ------------------------------------------------------------------------------
OS_NAME="$(uname -s 2>/dev/null || echo "Unknown")"
echo -e "[*] Detecting Operating System: ${BOLD}${OS_NAME}${NC}"

IS_WINDOWS=false
IS_LINUX=false

case "${OS_NAME}" in
    CYGWIN*|MINGW*|MSYS*|Windows_NT)
        IS_WINDOWS=true
        ;;
    Linux)
        IS_LINUX=true
        ;;
    Darwin)
        echo -e "${YELLOW}[!] macOS detected. Preparing Linux/Unix installer environment...${NC}"
        IS_LINUX=true
        ;;
    *)
        # Check fallback indicators for Windows environment
        if [ -n "${WINDIR}" ] || [ -n "${SYSTEMROOT}" ] || [ -n "${COMSPEC}" ]; then
            IS_WINDOWS=true
        else
            IS_LINUX=true
        fi
        ;;
esac

# ------------------------------------------------------------------------------
# BRANCH A: Windows Setup
# ------------------------------------------------------------------------------
if [ "${IS_WINDOWS}" = true ]; then
    echo -e "${GREEN}[+] Windows Operating System detected.${NC}"
    echo -e "[*] Locating DevSecIt Windows Setup..."

    WIN_INSTALLER=""
    if [ -f "${SCRIPT_DIR}/windows/windows.exe" ]; then
        WIN_INSTALLER="${SCRIPT_DIR}/windows/windows.exe"
    elif [ -f "${SCRIPT_DIR}/windows.exe" ]; then
        WIN_INSTALLER="${SCRIPT_DIR}/windows.exe"
    elif [ -f "${SCRIPT_DIR}/windows/setup.exe" ]; then
        WIN_INSTALLER="${SCRIPT_DIR}/windows/setup.exe"
    fi

    if [ -n "${WIN_INSTALLER}" ] && [ -f "${WIN_INSTALLER}" ]; then
        echo -e "${GREEN}[+] Found Windows Setup: ${WIN_INSTALLER}${NC}"
        echo -e "[*] Launching Windows Installation Wizard..."
        if command -v cmd.exe >/dev/null 2>&1; then
            cmd.exe /c start "" "$(cygpath -w "${WIN_INSTALLER}" 2>/dev/null || echo "${WIN_INSTALLER}")"
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "${WIN_INSTALLER}"
        else
            "${WIN_INSTALLER}" &
        fi
        echo -e "${GREEN}[SUCCESS] Windows Setup wizard opened successfully.${NC}"
        exit 0
    else
        echo -e "${RED}[ERROR] Windows installer executable not found at ${SCRIPT_DIR}/windows/windows.exe${NC}"
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# BRANCH B: Linux Deployment (ARM64 vs x86_64)
# ------------------------------------------------------------------------------
echo -e "${GREEN}[+] Linux Operating System confirmed.${NC}"

# Parse command line port arguments
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

# If port was not specified via arguments, prompt the user
if [ -z "${PORT}" ]; then
    echo ""
    read -p "Enter port number to deploy [default: 8000]: " USER_PORT
    if [ -n "${USER_PORT}" ]; then
        PORT="${USER_PORT}"
    else
        PORT="8000"
    fi
fi

# Validate Port Number
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
    echo -e "${RED}[ERROR] Invalid port number: '${PORT}'. Must be an integer between 1 and 65535.${NC}"
    exit 1
fi

echo -e "[*] Target Port: ${BOLD}${PORT}${NC}"

# Detect CPU Architecture
RAW_ARCH="$(uname -m)"
echo -e "[*] Detecting CPU Architecture: ${BOLD}${RAW_ARCH}${NC}"

ARCH_FOLDER=""
case "${RAW_ARCH}" in
    aarch64|arm64|armv8*)
        ARCH_FOLDER="arm64"
        ARCH_DISPLAY="ARM64 (aarch64)"
        ;;
    x86_64|amd64)
        ARCH_FOLDER="x86_64"
        ARCH_DISPLAY="x86_64 (64-bit)"
        ;;
    *)
        echo -e "${RED}[ERROR] Unsupported CPU architecture: ${RAW_ARCH}.${NC}"
        echo -e "[!] DevSecIt currently provides precompiled static binaries for x86_64 and aarch64 (ARM64)."
        exit 1
        ;;
esac

echo -e "${GREEN}[+] Architecture match: ${ARCH_DISPLAY}${NC}"

# Locate Architecture Binary
SELECTED_BIN=""
SEARCH_PATHS=(
    "${SCRIPT_DIR}/linux/${ARCH_FOLDER}/devsecit-rust-api"
    "${SCRIPT_DIR}/linux/${ARCH_FOLDER}/dsiapi"
    "${SCRIPT_DIR}/${ARCH_FOLDER}/devsecit-rust-api"
    "${SCRIPT_DIR}/${ARCH_FOLDER}/dsiapi"
    "${SCRIPT_DIR}/linux/devsecit-rust-api"
    "${SCRIPT_DIR}/linux/dsiapi"
    "${SCRIPT_DIR}/devsecit-rust-api"
    "${SCRIPT_DIR}/dsiapi"
)

for cand in "${SEARCH_PATHS[@]}"; do
    if [ -f "${cand}" ]; then
        SELECTED_BIN="${cand}"
        break
    fi
done

if [ -z "${SELECTED_BIN}" ] || [ ! -f "${SELECTED_BIN}" ]; then
    echo -e "${RED}[ERROR] Compatible binary for ${ARCH_DISPLAY} could not be found!${NC}"
    echo -e "[!] Checked search paths:"
    for cand in "${SEARCH_PATHS[@]}"; do
        echo -e "    - ${cand}"
    done
    exit 1
fi

echo -e "${GREEN}[+] Found binary: ${SELECTED_BIN}${NC}"

# Target installation directory
TARGET_DIR="${SCRIPT_DIR}"
if [ -d "${SCRIPT_DIR}/linux" ]; then
    TARGET_DIR="${SCRIPT_DIR}/linux"
fi

FINAL_BIN="${TARGET_DIR}/devsecit-rust-api"
FINAL_ALIAS="${TARGET_DIR}/dsiapi"

if [ "${SELECTED_BIN}" != "${FINAL_BIN}" ]; then
    echo -e "[*] Installing binary -> ${FINAL_BIN} ..."
    cp -f "${SELECTED_BIN}" "${FINAL_BIN}"
    cp -f "${SELECTED_BIN}" "${FINAL_ALIAS}" 2>/dev/null || true
fi

chmod +x "${FINAL_BIN}" 2>/dev/null || true
chmod +x "${FINAL_ALIAS}" 2>/dev/null || true

# Test execution
echo -e "[*] Testing binary runtime: ${FINAL_BIN} ($(stat -c%s "${FINAL_BIN}" 2>/dev/null || wc -c < "${FINAL_BIN}") bytes)..."
if "${FINAL_BIN}" --version >/dev/null 2>&1; then
    VER_STR="$("${FINAL_BIN}" --version 2>&1 | head -n 1)"
    echo -e "${GREEN}[+] Binary runtime verified: ${VER_STR}${NC}"
else
    echo -e "${RED}[ERROR] Direct execution returned an error. Testing output:${NC}"
    "${FINAL_BIN}" --version || true
    echo ""
    echo -e "${YELLOW}[!] If you see 'GLIBC_2.43 not found', the binary on this server is the OLD GLIBC version (11,159,928 bytes).${NC}"
    echo -e "${YELLOW}[!] Please upload the NEW 100% Statically linked MUSL binary (10,897,136 bytes) from:${NC}"
    echo -e "${YELLOW}[!]   deploy/linux/arm64/devsecit-rust-api${NC}"
    echo ""
    exit 1
fi

# Check for Port Conflicts & Bindings
echo -e "[*] Checking port bindings for port ${PORT}..."
PORT_IN_USE=false

if command -v fuser >/dev/null 2>&1; then
    if sudo fuser "${PORT}/tcp" >/dev/null 2>&1; then
        PORT_IN_USE=true
        echo -e "${YELLOW}[!] Port ${PORT} is currently in use. Releasing port...${NC}"
        sudo fuser -k "${PORT}/tcp" 2>/dev/null || true
        sleep 1
    fi
fi

if command -v ss >/dev/null 2>&1 && [ "${PORT_IN_USE}" = false ]; then
    if sudo ss -lptn "sport = :${PORT}" 2>/dev/null | grep -q ":${PORT}"; then
        echo -e "${YELLOW}[!] Port ${PORT} is still bound by another process.${NC}"
        if command -v fuser >/dev/null 2>&1; then
            sudo fuser -k "${PORT}/tcp" 2>/dev/null || true
        fi
    fi
fi

# Ensure .env exists in target directory
if [ ! -f "${TARGET_DIR}/.env" ]; then
    if [ -f "${TARGET_DIR}/.env.example" ]; then
        cp "${TARGET_DIR}/.env.example" "${TARGET_DIR}/.env"
        echo -e "[+] Created .env from .env.example"
    elif [ -f "${SCRIPT_DIR}/.env.example" ]; then
        cp "${SCRIPT_DIR}/.env.example" "${TARGET_DIR}/.env"
        echo -e "[+] Created .env from deploy/.env.example"
    fi
fi

# Create Systemd Service File
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
echo -e "[*] Generating systemd service unit: ${SERVICE_FILE} ..."

sudo bash -c "cat > ${SERVICE_FILE}" <<EOF
[Unit]
Description=DevSecIt Rust API Engine (Port ${PORT})
After=network.target

[Service]
Type=simple
WorkingDirectory=${TARGET_DIR}
ExecStart=${FINAL_BIN} start -p ${PORT} --no-gui
Restart=always
RestartSec=3s
LimitNOFILE=65536
EnvironmentFile=-${TARGET_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

# Activate and start service
echo -e "[*] Registering and activating ${SERVICE_NAME} via systemctl..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
sleep 1.5

# Verify service status
if sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${GREEN}${BOLD}>>> [SUCCESS] DevSecIt Rust API is running successfully on Port ${PORT}!${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "  - Architecture : ${BOLD}${ARCH_DISPLAY}${NC}"
    echo -e "  - Binary       : ${FINAL_BIN}"
    echo -e "  - Service Name : ${SERVICE_NAME}"
    echo -e "  - Server URL   : ${CYAN}http://0.0.0.0:${PORT}${NC}"
    echo -e "  - Swagger UI   : ${CYAN}http://localhost:${PORT}/${NC}"
    echo -e "  - Health Check : ${CYAN}http://localhost:${PORT}/health${NC}"
    echo ""
    echo -e "Management Commands:"
    echo -e "  - View status : sudo systemctl status ${SERVICE_NAME}"
    echo -e "  - View logs   : sudo journalctl -u ${SERVICE_NAME} -f"
    echo -e "  - Restart     : sudo systemctl restart ${SERVICE_NAME}"
    echo -e "  - Stop        : sudo systemctl stop ${SERVICE_NAME}"
    echo ""
else
    echo -e "${RED}[ERROR] Service '${SERVICE_NAME}' failed to start.${NC}"
    echo -e "[*] Fetching recent systemd journal logs:"
    sudo journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
    exit 1
fi
