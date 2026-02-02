#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="${INSTALL_DIR}/${SERVICE_NAME}"
ENV_FILE="/etc/systemd/system/llama-server.env"
INSTALL_DIR=$(dirname "$(realpath "$0")")
TEMPLATE_FILE="${INSTALL_DIR}/.env.template"

echo "Installing llama.cpp server daemon..."
echo "Usage: sudo ./install.sh [--model PATH] [--llamacpp_dir PATH]"
echo "Options:"
echo "  --model PATH       Path to .gguf model file (optional)"
echo "  --llamacpp_dir PATH Path to llama.cpp directory (optional)"

# Parse command line arguments
MODEL_PATH=""
LLAMCPP_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL_PATH="$2"
            shift 2
            ;;
        --llamacpp_dir)
            LLAMCPP_DIR="$2"
            shift 2
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
cp "${SERVICE_FILE}" "${SERVICE_FILE}"

# Create environment file from template
echo "Creating environment file..."
cp "${TEMPLATE_FILE}" "${ENV_FILE}"

# Prompt for required values if not provided via command line
if [ -z "${MODEL_PATH}" ]; then
    read -p "Enter MODEL_PATH (path to .gguf file): " MODEL_PATH
fi
if [ -z "${LLAMCPP_DIR}" ]; then
    read -p "Enter LLAMCPP_DIR (path to llama.cpp directory): " LLAMCPP_DIR
fi

# Validate values are set
if [ -z "${MODEL_PATH}" ] || [ -z "${LLAMCPP_DIR}" ]; then
    echo "ERROR: MODEL_PATH and LLAMCPP_DIR are required"
    exit 1
fi

# Replace template values
sed -i "s|MODEL_PATH=.*|MODEL_PATH=${MODEL_PATH}|" "${ENV_FILE}"
sed -i "s|LLAMCPP_DIR=.*|LLAMCPP_DIR=${LLAMCPP_DIR}|" "${ENV_FILE}"

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