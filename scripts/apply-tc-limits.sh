#!/usr/bin/env bash
set -euo pipefail

# Apply symmetric WireGuard traffic shaping inside the wg-easy container:
# - Total bandwidth cap across all clients (default: 100mbit)
# - Per-client bandwidth cap by WireGuard IP (default: 10mbit)
#
# Usage:
#   ./scripts/apply-tc-limits.sh
#   TOTAL_RATE=100mbit PER_CLIENT_RATE=10mbit CONTAINER=wg-easy ./scripts/apply-tc-limits.sh

CONTAINER="${CONTAINER:-wg-easy}"
WG_IF="${WG_IF:-wg0}"
IFB_IF="${IFB_IF:-ifb0}"
TOTAL_RATE="${TOTAL_RATE:-100mbit}"
PER_CLIENT_RATE="${PER_CLIENT_RATE:-10mbit}"

docker exec -i "$CONTAINER" sh -s "$WG_IF" "$IFB_IF" "$TOTAL_RATE" "$PER_CLIENT_RATE" <<'EOF'
set -eu

WG_IF="$1"
IFB_IF="$2"
TOTAL_RATE="$3"
PER_CLIENT_RATE="$4"

# Ensure wg0 exists
if ! ip link show "$WG_IF" >/dev/null 2>&1; then
  echo "Interface $WG_IF not found in container" >&2
  exit 1
fi

# Ensure ifb0 exists for ingress (client upload) shaping
if ! ip link show "$IFB_IF" >/dev/null 2>&1; then
  ip link add "$IFB_IF" type ifb
fi
ip link set "$IFB_IF" up

# Collect client /32 IPs from active WireGuard peers
CLIENT_IPS=$(wg show "$WG_IF" allowed-ips | awk '{print $2}' | tr ',' '\n' | sed 's|/32||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)

# --- 1. Egress on wg0 (Server -> Client = Client Download) ---
tc qdisc del dev "$WG_IF" root 2>/dev/null || true
tc qdisc add dev "$WG_IF" root handle 1: htb default 9999
tc class add dev "$WG_IF" parent 1: classid 1:1 htb rate "$TOTAL_RATE" ceil "$TOTAL_RATE"
tc class add dev "$WG_IF" parent 1:1 classid 1:9999 htb rate "$PER_CLIENT_RATE" ceil "$PER_CLIENT_RATE"

# --- 2. Ingress on wg0 -> ifb0 (Client -> Server = Client Upload) ---
tc qdisc del dev "$WG_IF" ingress 2>/dev/null || true
tc qdisc add dev "$WG_IF" handle ffff: ingress
tc filter add dev "$WG_IF" parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev "$IFB_IF"

tc qdisc del dev "$IFB_IF" root 2>/dev/null || true
tc qdisc add dev "$IFB_IF" root handle 2: htb default 9999
tc class add dev "$IFB_IF" parent 2: classid 2:1 htb rate "$TOTAL_RATE" ceil "$TOTAL_RATE"
tc class add dev "$IFB_IF" parent 2:1 classid 2:9999 htb rate "$PER_CLIENT_RATE" ceil "$PER_CLIENT_RATE"

# --- 3. Per-client classes & filters ---
idx=10
for ip in $CLIENT_IPS; do
  # Download (dst = client IP)
  tc class add dev "$WG_IF" parent 1:1 classid "1:${idx}" htb rate "$PER_CLIENT_RATE" ceil "$PER_CLIENT_RATE"
  tc filter add dev "$WG_IF" protocol ip parent 1:0 prio 1 u32 match ip dst "${ip}/32" flowid "1:${idx}"

  # Upload (src = client IP)
  tc class add dev "$IFB_IF" parent 2:1 classid "2:${idx}" htb rate "$PER_CLIENT_RATE" ceil "$PER_CLIENT_RATE"
  tc filter add dev "$IFB_IF" protocol ip parent 2:0 prio 1 u32 match ip src "${ip}/32" flowid "2:${idx}"

  idx=$((idx + 1))
done

echo "Applied TC limits on $WG_IF/$IFB_IF: total=$TOTAL_RATE, per_client=$PER_CLIENT_RATE ($(echo "$CLIENT_IPS" | wc -w | tr -d ' ') clients)"
EOF
