#!/bin/bash

SERVICE_NAME="llama-server.service"
LOG_FILE="/var/log/llama-server.log"

echo "=== Llama.cpp Server Daemon Logs ==="
echo ""

# Check if service is enabled
if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
    echo "🟢 Service is enabled"
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo "🟢 Service is active"
    else
        echo "🔴 Service is not active"
        echo ""
        echo "Service may be starting up or has failed:"
        echo "  systemctl status ${SERVICE_NAME}"
        echo ""
        echo "Recent logs:"
        echo "===================================="
        echo ""
    fi
else
    echo "⚠️  Service is not enabled"
    echo ""
    echo "To enable the service, run:"
    echo "  sudo systemctl enable ${SERVICE_NAME}"
    echo ""
    echo "To start the service, run:"
    echo "  sudo systemctl start ${SERVICE_NAME}"
    echo ""
    echo "Recent logs:"
    echo "===================================="
    echo ""
fi

# Try to show log file first, fall back to journalctl
if [ -f "${LOG_FILE}" ]; then
    tail -f "${LOG_FILE}"
else
    journalctl -u "${SERVICE_NAME}" -f
fi
