#!/bin/bash

# Check if EpgTimerSrv process is running
if ! pgrep -x "EpgTimerSrv" > /dev/null; then
    echo "EpgTimerSrv is not running"
    exit 1
fi

# Check HTTP port (5510) if curl is available
if command -v curl > /dev/null; then
    if ! curl -sf http://localhost:5510/ > /dev/null 2>&1; then
        echo "HTTP Server is not responding on port 5510"
        exit 1
    fi
fi

echo "EDCB is healthy"
exit 0
