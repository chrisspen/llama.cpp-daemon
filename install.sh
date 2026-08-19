#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
ENV_FILE="/etc/systemd/system/llama-server.env"
INSTALL_DIR=$(dirname "$(readlink -f "$0")")
TEMPLATE_FILE="${INSTALL_DIR}/.env.template"
ENV_SOURCE="${INSTALL_DIR}/.env"

echo "Installing llama.cpp server daemon..."
echo "Usage: sudo ./install.sh [--model PATH] [--llamacpp_dir PATH]"
echo "Options:"
echo "  --model PATH       Path to .gguf model file (optional)"
echo "  --llamacpp_dir PATH Path to llama.cpp directory (optional)"

# Parse command line arguments (override .env when provided)
CLI_MODEL_PATH=""
CLI_LLAMCPP_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            CLI_MODEL_PATH="$2"
            shift 2
            ;;
        --model=*)
            CLI_MODEL_PATH="${1#*=}"
            shift
            ;;
        --llamacpp_dir)
            CLI_LLAMCPP_DIR="$2"
            shift 2
            ;;
        --llamacpp_dir=*)
            CLI_LLAMCPP_DIR="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root to install the daemon"
    exit 1
fi

# Check if source file exists
if [ ! -f "${TEMPLATE_FILE}" ]; then
    echo "Error: ${TEMPLATE_FILE} not found"
    exit 1
fi

# Copy service file
echo "Copying service file to ${SERVICE_FILE}..."
cp "${INSTALL_DIR}/${SERVICE_NAME}" "${SERVICE_FILE}"

# Determine configuration source: local .env if present, otherwise require CLI params
if [ -f "${ENV_SOURCE}" ]; then
    # .env is the source of truth; CLI flags override individual values
    echo "Loading configuration from ${ENV_SOURCE}..."
    # shellcheck disable=SC1090
    source "${ENV_SOURCE}"
    MODEL_PATH="${CLI_MODEL_PATH:-${MODEL_PATH}}"
    LLAMCPP_DIR="${CLI_LLAMCPP_DIR:-${LLAMCPP_DIR}}"
else
    # No .env: require everything via CLI, as before
    echo "No ${ENV_SOURCE} found; using command-line parameters..."
    MODEL_PATH="${CLI_MODEL_PATH}"
    LLAMCPP_DIR="${CLI_LLAMCPP_DIR}"
    if [ -z "${MODEL_PATH}" ] || [ -z "${LLAMCPP_DIR}" ]; then
        echo "ERROR: no ${ENV_SOURCE} found and --model/--llamacpp_dir not provided"
        echo "Create a .env (copy .env.template) or run: sudo ./install.sh --model PATH --llamacpp_dir PATH"
        exit 1
    fi
fi

# Defaults for anything still unset
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8081}"
CONTEXT_SIZE="${CONTEXT_SIZE:-65536}"
NGL_LEVEL="${NGL_LEVEL:-99}"
JINJA_ENABLED="${JINJA_ENABLED:-true}"
RESTART_MODE="${RESTART_MODE:-always}"
RESTART_SECONDS="${RESTART_SECONDS:-5s}"
LOG_PATH="${LOG_PATH:-/var/log/llama-server.log}"

# Final sanity check
if [ -z "${MODEL_PATH}" ] || [ -z "${LLAMCPP_DIR}" ]; then
    echo "ERROR: MODEL_PATH and LLAMCPP_DIR are required"
    exit 1
fi

# Create environment file from template only if it doesn't exist yet
if [ ! -f "${ENV_FILE}" ]; then
    echo "Creating environment file from template..."
    cp "${TEMPLATE_FILE}" "${ENV_FILE}"
else
    echo "Environment file already exists, updating in place..."
fi

# Fill in resolved values
sed -i "s|MODEL_PATH=.*|MODEL_PATH=${MODEL_PATH}|" "${ENV_FILE}"
sed -i "s|LLAMCPP_DIR=.*|LLAMCPP_DIR=${LLAMCPP_DIR}|" "${ENV_FILE}"
sed -i "s|HOST=.*|HOST=\"${HOST}\"|" "${ENV_FILE}"
sed -i "s|PORT=.*|PORT=\"${PORT}\"|" "${ENV_FILE}"
sed -i "s|CONTEXT_SIZE=.*|CONTEXT_SIZE=\"${CONTEXT_SIZE}\"|" "${ENV_FILE}"
sed -i "s|NGL_LEVEL=.*|NGL_LEVEL=\"${NGL_LEVEL}\"|" "${ENV_FILE}"
sed -i "s|RESTART_MODE=.*|RESTART_MODE=${RESTART_MODE}|" "${ENV_FILE}"
sed -i "s|RESTART_SECONDS=.*|RESTART_SECONDS=${RESTART_SECONDS}|" "${ENV_FILE}"
sed -i "s|JINJA_ENABLED=.*|JINJA_ENABLED=${JINJA_ENABLED}|" "${ENV_FILE}"
sed -i "s|LOG_PATH=.*|LOG_PATH=\"${LOG_PATH}\"|" "${ENV_FILE}"

# Replace template values in service file
sed -i "s|RESTART_MODE=.*|Restart=always|" "${SERVICE_FILE}"
sed -i "s|RESTART_SECONDS=.*|RestartSec=5s|" "${SERVICE_FILE}"

# Initialize the log file (llama-server logs here via --log-file)
echo "Initializing log file at ${LOG_PATH}..."
LOG_DIR="$(dirname "${LOG_PATH}")"
mkdir -p "${LOG_DIR}"
touch "${LOG_PATH}"
# Owned by the user the daemon runs as so llama-server can write to it
SERVICE_USER="${SERVICE_USER:-root}"
SERVICE_GROUP="${SERVICE_GROUP:-${SERVICE_USER}}"
if id "${SERVICE_USER}" >/dev/null 2>&1; then
    chown "${SERVICE_USER}:${SERVICE_GROUP}" "${LOG_PATH}"
fi
chmod 644 "${LOG_PATH}"

# Install logrotate config with a hard size cap so the log can't fill the disk
LOGROTATE_SRC="${INSTALL_DIR}/llama-server.logrotate"
LOGROTATE_DST="/etc/logrotate.d/llama-server"
if [ -f "${LOGROTATE_SRC}" ]; then
    echo "Installing logrotate config to ${LOGROTATE_DST}..."
    sed "s|/var/log/llama-server.log|${LOG_PATH}|g" "${LOGROTATE_SRC}" > "${LOGROTATE_DST}"
    chmod 644 "${LOGROTATE_DST}"
else
    echo "WARNING: ${LOGROTATE_SRC} not found; skipping logrotate setup"
fi

# Check if llama.cpp directory exists
echo "Checking for llama.cpp directory..."
if [ ! -d "${LLAMCPP_DIR}" ]; then
    echo "ERROR: llama.cpp directory not found at ${LLAMCPP_DIR}"
    echo "Please download and build llama.cpp:"
    echo "  cd ${LLAMCPP_DIR}"
    echo "  git clone https://github.com/ggerganov/llama.cpp.git ."
    echo "  git pull"
    echo "  make"
    exit 1
fi

# Check if model file exists
echo "Checking for model file..."
if [ ! -f "${MODEL_PATH}" ]; then
    echo "ERROR: Model file not found at ${MODEL_PATH}"
    echo "Please specify a valid .gguf file path"
    exit 1
fi

# Check if llama-server binary exists
echo "Checking for llama-server binary..."
if [ ! -f "${LLAMCPP_DIR}/build/bin/llama-server" ]; then
    echo "ERROR: llama-server binary not found at ${LLAMCPP_DIR}/build/bin/llama-server"
    echo "Please build llama.cpp first:"
    echo "  cd ${LLAMCPP_DIR}"
    echo "  make"
    exit 1
fi

# Reload systemd
echo "Reloading systemd daemon configuration..."
systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting the service..."
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

# Check service status
echo "Checking service status..."
systemctl status "${SERVICE_NAME}" --no-pager

echo "Installation complete!"
echo "Use './status.sh' to check service status"
echo "Use './logs.sh' to monitor logs"
echo "Use 'systemctl status llama-server' to check service status"
echo "Use 'journalctl -u llama-server -f' to view logs"
