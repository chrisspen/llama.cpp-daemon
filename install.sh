#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
ENV_FILE="/etc/systemd/system/${SERVICE_NAME}.env"
INSTALL_DIR=$(dirname "$(realpath "$0")")
TEMPLATE_FILE="${INSTALL_DIR}/.env.template"
SOURCE_SERVICE_FILE="${INSTALL_DIR}/${SERVICE_NAME}"
SOURCE_ENV_FILE="${INSTALL_DIR}/.env"

echo "Installing llama.cpp server daemon..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root to install the daemon"
    exit 1
fi

# Check if source file exists
if [ ! -f "${SOURCE_SERVICE_FILE}" ]; then
    echo "Error: ${SOURCE_SERVICE_FILE} not found"
    exit 1
fi

# Copy service file with variable substitution
echo "Copying service file to ${SERVICE_FILE}..."
# Read environment variables and substitute in service file
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    # Remove quotes from value
    value=$(echo "$value" | sed "s/[\"']//g")
    # Substitute in service file
    sed -i "s|\${${key}}|${value}|g" "${SOURCE_SERVICE_FILE}"
done < "${SOURCE_ENV_FILE}"
cp "${SOURCE_SERVICE_FILE}" "${SERVICE_FILE}"

# Copy environment file
echo "Copying environment file to ${ENV_FILE}..."
if [ -f "${SOURCE_ENV_FILE}" ]; then
    cp "${SOURCE_ENV_FILE}" "${ENV_FILE}"
else
    echo "Creating default environment file..."

    # Prompt for required values
    read -p "Enter MODEL_PATH (path to .gguf file): " model_path
    read -p "Enter LLAMCPP_DIR (path to llama.cpp directory): " llamacpp_dir

    # Generate environment file from template
    cat "${TEMPLATE_FILE}" > "${ENV_FILE}"

    # Replace template values
    sed -i "s|MODEL_PATH=.*|MODEL_PATH=${model_path}|" "${ENV_FILE}"
    sed -i "s|LLAMCPP_DIR=.*|LLAMCPP_DIR=${llamacpp_dir}|" "${ENV_FILE}"

    # Update BUILD_DIR based on LLAMCPP_DIR
    sed -i "s|BUILD_DIR=.*|BUILD_DIR=${llamacpp_dir}/build/bin|" "${ENV_FILE}"

    echo "Environment file created with your values"
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
echo "Use 'systemctl status llama-server' to check service status"
echo "Use 'journalctl -u llama-server -f' to view logs"