#!/bin/bash

SERVICE_NAME="llama-server.service"
LOG_FILE="/var/log/llama-server.log"
JOURNAL_LOG="journal"

echo "=== Llama.cpp Server Daemon Logs ==="
echo ""

# Check if service is running
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "🟢 Service is running"
    echo ""
    echo "Monitoring logs (Ctrl+C to stop)..."
    echo "===================================="
    echo ""

    # Try to show log file first, fall back to journalctl
    if [ -f "${LOG_FILE}" ]; then
        tail -f "${LOG_FILE}"
    else
        journalctl -u "${SERVICE_NAME}" -f
    fi
else
    echo "🔴 Service is not running"
    echo ""
    echo "To start the service, run:"
    echo "  sudo systemctl start ${SERVICE_NAME}"
    echo ""
    echo "To view recent logs:"
    echo "  journalctl -u ${SERVICE_NAME} -f"
    echo ""
    echo "To view the last 50 lines:"
    echo "  journalctl -u ${SERVICE_NAME} -n 50"
fi
