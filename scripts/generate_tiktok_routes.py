#!/usr/bin/env python3
"""
Generates the list of IP subnets belonging to ByteDance / TikTok Autonomous Systems (ASNs)
and formats them for WireGuard's `AllowedIPs`.
"""
import urllib.request
import json
import ipaddress
import sys

# Official ByteDance / TikTok ASNs
TIKTOK_ASNS = [
    "AS138699",  # ByteDance
    "AS396986",  # ByteDance US
    "AS149449",  # ByteDance Global
]

def fetch_prefixes():
    networks = []
    for asn in TIKTOK_ASNS:
        url = f"https://stat.ripe.net/data/announced-prefixes/data.json?resource={asn}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode())
                prefixes = data.get("data", {}).get("prefixes", [])
                for p in prefixes:
                    try:
                        net = ipaddress.ip_network(p["prefix"])
                        networks.append(net)
                    except ValueError:
                        pass
        except Exception as e:
            print(f"Warning: Failed to fetch prefixes for {asn}: {e}", file=sys.stderr)

    ipv4_nets = [n for n in networks if n.version == 4]
    ipv6_nets = [n for n in networks if n.version == 6]

    collapsed_v4 = sorted(list(ipaddress.collapse_addresses(ipv4_nets)))
    collapsed_v6 = sorted(list(ipaddress.collapse_addresses(ipv6_nets)))

    return collapsed_v4, collapsed_v6

def main():
    v4, v6 = fetch_prefixes()
    print(f"# ByteDance / TikTok IP Ranges (Total IPv4: {len(v4)}, IPv6: {len(v6)})")
    all_ranges = [str(n) for n in v4]
    print("\n# Copy this line into your WireGuard client config under [Peer] -> AllowedIPs:\n")
    print(f"AllowedIPs = {', '.join(all_ranges)}")

if __name__ == "__main__":
    main()
