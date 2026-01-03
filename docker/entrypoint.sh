#!/bin/bash
set -e

EDCB_SETTING_DIR="/var/local/edcb"
BONDRIVER_DIR="/usr/local/lib/edcb"

# Copy default ini files if not exists
for ini_name in Common.ini EpgTimerSrv.ini; do
    default_file="/etc/edcb/${ini_name}.default"
    target_file="${EDCB_SETTING_DIR}/${ini_name}"
    if [ ! -f "${target_file}" ] && [ -f "${default_file}" ]; then
        echo "Copying default ${ini_name} to ${target_file}"
        cp "${default_file}" "${target_file}"
    fi
done

# BonDriver configuration from environment variables
if [ -n "$MIRAKURUN_TYPE" ]; then
    echo "Generating BonDriver configuration from environment variables..."

    if [ "$MIRAKURUN_TYPE" = "unix" ]; then
        cat > "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" <<EOF
SERVER_TYPE="unix"
SERVER_SOCKPATH="${MIRAKURUN_SOCK_PATH:-/var/run/mirakc.sock}"
EOF
        echo "BonDriver configured for Unix socket: ${MIRAKURUN_SOCK_PATH:-/var/run/mirakc.sock}"

    elif [ "$MIRAKURUN_TYPE" = "tcp" ]; then
        cat > "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" <<EOF
SERVER_TYPE="tcp"
SERVER_HOST="${MIRAKURUN_HOST:-mirakurun}"
SERVER_PORT="${MIRAKURUN_PORT:-40772}"
EOF
        echo "BonDriver configured for TCP: ${MIRAKURUN_HOST:-mirakurun}:${MIRAKURUN_PORT:-40772}"

    else
        echo "Warning: Unknown MIRAKURUN_TYPE='${MIRAKURUN_TYPE}'. Use 'unix' or 'tcp'."
    fi

elif [ ! -f "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" ]; then
    echo "Warning: BonDriver configuration not found"
    echo "Creating default Unix Domain Socket configuration..."

    cat > "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" <<EOF
SERVER_TYPE="unix"
SERVER_SOCKPATH="/var/run/mirakc.sock"
EOF
fi

# Also copy BonDriver config to the BonDriver directory if it exists
if [ -f "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" ]; then
    cp "${BONDRIVER_DIR}/BonDriver_LinuxMirakc.so.ini" "${EDCB_SETTING_DIR}/BonDriver/" 2>/dev/null || true
fi

# Enable ALLOW_SETTING in util.lua for web UI configuration
UTIL_LUA="${EDCB_SETTING_DIR}/HttpPublic/legacy/util.lua"
if [ -f "${UTIL_LUA}" ]; then
    sed -i 's/^ALLOW_SETTING=false/ALLOW_SETTING=true/' "${UTIL_LUA}"
    echo "Enabled ALLOW_SETTING in util.lua"
fi

# Permission adjustment when running as root
if [ "$(id -u)" = "0" ]; then
    chown -R edcb:edcb "${EDCB_SETTING_DIR}" /var/log/edcb 2>/dev/null || true
    chown -R edcb:edcb /recordings 2>/dev/null || true
fi

echo "Starting EDCB..."
exec "$@"
