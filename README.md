# TikTok Smart-Routing VPN (Split Tunneling via WireGuard & Sing-box)

A self-hosted, lightweight VPN solution designed for selective traffic routing. It routes traffic for **TikTok** through a remote US/dedicated server endpoint while keeping all other everyday Internet traffic local (direct connection).

## 🚀 Key Advantages

- **Selective Routing (Domain-Based Split Tunneling):** Only TikTok domain clusters and CDNs (`*.tiktok.com`, `*.tiktokv.com`, `*.byteoversea.com`, etc.) go through the VPN. Other browsing remains fast and untouched.
- **Zero Routine Overhead for Users:** Users do not need to constantly turn the VPN on and off; it can stay running in the background 24/7.
- **Lightweight & High-Performance:** Server-side is powered by native **WireGuard** via Docker (`wg-easy`), consuming minimal CPU and RAM (< 100 MB).
- **Secure Management:** Admin Web UI is bound strictly to `127.0.0.1` (accessible via internal VPN or SSH tunnel), exposing only the WireGuard UDP port.

---

## 🏗️ Architecture

```
[ User Device (Mac/Win/iOS/Android) ]
        |
   (Sing-box / Hiddify Client)
        |-- [TikTok Domains & CDNs] ----> (Encrypted WireGuard UDP) ----> [ Asus Router / Server ] ---> Internet (USA)
        |
        `-- [All Other Traffic] --------> (Direct Home/Office ISP) ------> Internet (Local)
```

---

## 🛠️ Server-side Deployment (Docker)

### 1. Requirements
- Linux host with Docker & Docker Compose installed.
- Public IP address or DDNS domain mapped to your external router.
- Forward UDP port `51820` on your router to the local IP of your server.

### 2. Setup
1. Clone this repository on the server:
   ```bash
   git clone https://github.com/nadtoka/tiktok-bypass-vpn.git
   cd tiktok-bypass-vpn
   ```

2. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

3. Generate an admin password hash for the Web UI:
   ```bash
   docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw 'YourSecurePasswordHere'
   ```
   Paste the resulting hash into `PASSWORD_HASH` in `.env`.

4. Update `WG_HOST` in `.env` with your public IP / domain.

5. Start the service:
   ```bash
   docker compose up -d
   ```

6. Access the Web UI securely:
   - Either via an existing internal management VPN: `http://<SERVER_LAN_IP>:51821`
   - Or via SSH port forwarding: `ssh -L 51821:127.0.0.1:51821 user@server` and open `http://localhost:51821`.

---

## 📱 Client Setup (Split-Tunneling)

### Option A: Using Hiddify (Recommended for End-Users)
1. Install [Hiddify](https://github.com/hiddify/hiddify-next) on Windows, macOS, Android, or iOS.
2. In the Web UI (`wg-easy`), create a client and download the WireGuard `.conf` file.
3. Import the WireGuard profile into Hiddify or use the Sing-box config template.
4. Set the routing rule to proxy `geosite:tiktok` through the WireGuard profile, while leaving the default rule as `direct`.

### Option B: Using Sing-box (CLI / GUI)
1. Refer to the template in [`client-configs/sing-box-template.json`](./client-configs/sing-box-template.json).
2. Substitute:
   - `server`: Your public IP / domain
   - `server_port`: 51820
   - `private_key` & `peer_public_key`: Keys from the generated WireGuard profile.
3. Start the Sing-box client.

---

## 🔒 Security & Privacy

- All `.env`, keys, credentials, and configuration files are excluded via `.gitignore`.
- Web management panel is not exposed to the public Internet.
- No corporate hostnames or internal IP addresses are committed to this repository.
