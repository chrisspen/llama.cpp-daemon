#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
ENV_FILE="/etc/systemd/system/llama-server.env"
INSTALL_DIR=$(dirname "$(realpath "$0")")
TEMPLATE_FILE="${INSTALL_DIR}/.env.template"

echo "Installing llama.cpp server daemon..."

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
cp "${TEMPLATE_FILE}" "${SERVICE_FILE}"

# Create environment file from template
echo "Creating environment file..."
cp "${TEMPLATE_FILE}" "${ENV_FILE}"
# Prompt for required values
read -p "Enter MODEL_PATH (path to .gguf file): " MODEL_PATH
read -p "Enter LLAMCPP_DIR (path to llama.cpp directory): " LLAMCPP_DIR
# Replace template values
sed -i "s|MODEL_PATH=.*|MODEL_PATH=${model_path}|" "${ENV_FILE}"
sed -i "s|LLAMCPP_DIR=.*|LLAMCPP_DIR=${llamacpp_dir}|" "${ENV_FILE}"

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