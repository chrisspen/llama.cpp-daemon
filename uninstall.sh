#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
ENV_FILE="/etc/systemd/system/${SERVICE_NAME}.env"

echo "Uninstalling llama.cpp server daemon..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root to uninstall the daemon"
    exit 1
fi

# Stop the service if running
echo "Stopping the service..."
systemctl stop "${SERVICE_NAME}" 2>/dev/null || true

# Disable the service
echo "Disabling the service..."
systemctl disable "${SERVICE_NAME}" 2>/dev/null || true

# Remove the service file
echo "Removing service file..."
rm -f "${SERVICE_FILE}"

# Remove the environment file
echo "Removing environment file..."
rm -f "${ENV_FILE}"

# Reload systemd
echo "Reloading systemd daemon configuration..."
systemctl daemon-reload

echo "Uninstallation complete!"