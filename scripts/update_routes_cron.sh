#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ALLOWED_IPS_FILE="${ROOT_DIR}/client-configs/tiktok-allowed-ips.txt"
ENV_FILE="${ROOT_DIR}/.env"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running TikTok routes update..."

# 1. Generate fresh AllowedIPs from RIPE API
python3 "${SCRIPT_DIR}/generate_tiktok_routes.py" > "${ALLOWED_IPS_FILE}.tmp"

# Check if non-empty and valid
if grep -q "^AllowedIPs = " "${ALLOWED_IPS_FILE}.tmp"; then
    mv "${ALLOWED_IPS_FILE}.tmp" "${ALLOWED_IPS_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Routes file updated successfully."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Generated routes file is invalid or empty. Aborting."
    rm -f "${ALLOWED_IPS_FILE}.tmp"
    exit 1
fi

# 2. Extract raw subnets string
NEW_IPS=$(grep -E '^AllowedIPs = ' "${ALLOWED_IPS_FILE}" | sed 's/AllowedIPs = //g' | tr -d '\r\n')

# 3. Update .env if present
if [ -f "${ENV_FILE}" ]; then
    if grep -q "^WG_ALLOWED_IPS=" "${ENV_FILE}"; then
        sed -i "s|^WG_ALLOWED_IPS=.*|WG_ALLOWED_IPS=${NEW_IPS}|" "${ENV_FILE}"
    else
        echo "WG_ALLOWED_IPS=${NEW_IPS}" >> "${ENV_FILE}"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] .env updated with fresh WG_ALLOWED_IPS."

    # 4. Gracefully restart wg-easy to apply for future client downloads
    cd "${ROOT_DIR}"
    docker compose up -d
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] wg-easy container reloaded."
fi
