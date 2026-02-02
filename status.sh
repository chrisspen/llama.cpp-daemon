#!/bin/bash

SERVICE_NAME="llama-server.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

echo "=== Llama.cpp Server Daemon Status ==="
echo ""

# Check if service file exists
if [ ! -f "${SERVICE_FILE}" ]; then
    echo "❌ Service file not found at ${SERVICE_FILE}"
    echo "   Run 'sudo ./install.sh' to install the daemon"
    exit 1
fi

# Show service status
echo "📋 Service Status:"
systemctl status "${SERVICE_NAME}" --no-pager
echo ""

# Show service file location
echo "📁 Service File: ${SERVICE_FILE}"
echo ""

# Show environment file status
ENV_FILE="${SERVICE_FILE}.env"
if [ -f "${ENV_FILE}" ]; then
    echo "📝 Environment File: ${ENV_FILE}"
    echo "   Last modified: $(stat -c %y "${ENV_FILE}")"
    echo ""
else
    echo "⚠️  Environment file not found at ${ENV_FILE}"
    echo "   Run 'sudo ./install.sh' to configure the daemon"
fi

# Show last few lines of log if service is running
echo ""
echo "📊 Recent Log Output:"
echo "======================"
journalctl -u "${SERVICE_NAME}" -n 10 --no-pager
