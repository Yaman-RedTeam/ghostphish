#!/usr/bin/env bash
#
# Quick diagnostic to identify what's broken
#

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'

echo -e "${C}════ GHOSTPHISH DIAGNOSTIC ════${N}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8000

# 1. App health
echo -e "${Y}1. App on localhost:${PORT}${N}"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://localhost:${PORT}/health" 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then
    echo -e "   ${G}✓ App is healthy (HTTP $code)${N}"
else
    echo -e "   ${R}✗ App not responding (HTTP $code)${N}"
    echo -e "   ${Y}→ Fix: ./launch-and-maintain.sh start${N}"
fi

# 2. Tunnel status
echo -e "\n${Y}2. Tunnel${N}"
url=$(cat "${SCRIPT_DIR}/ghostphish_current.url" 2>/dev/null || echo "")
if [[ -n "$url" ]]; then
    echo -e "   ${G}✓ Tunnel live${N}"
    echo -e "   ${C}   ${url}${N}"
    # Try a simple request
    http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${url}/health" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
        echo -e "   ${G}✓ Reachable via public URL${N}"
    else
        echo -e "   ${R}✗ Not reachable (HTTP $http_code)${N}"
        echo -e "   ${Y}→ Tunnel may be regenerating. Check: ./launch-and-maintain.sh status${N}"
    fi
else
    echo -e "   ${R}✗ No tunnel URL${N}"
    echo -e "   ${Y}→ Is the supervisor running? ./launch-and-maintain.sh status${N}"
    echo -e "   ${Y}→ Is cloudflared installed? command -v cloudflared${N}"
fi

# 3. Docker/Python runtime
echo -e "\n${Y}3. Runtime${N}"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    container=$(docker ps 2>/dev/null | grep ghostphish || echo "")
    if [[ -n "$container" ]]; then
        echo -e "   ${G}✓ Docker container running${N}"
    else
        echo -e "   ${Y}~ Docker available but container not running${N}"
    fi
else
    if command -v python3 >/dev/null 2>&1; then
        echo -e "   ${G}✓ Python3 available (fallback mode)${N}"
    else
        echo -e "   ${R}✗ Neither Docker nor Python3${N}"
    fi
fi

# 4. Dependencies
echo -e "\n${Y}4. Dependencies${N}"
[[ -f "${SCRIPT_DIR}/requirements.txt" ]] && echo -e "   ${G}✓ requirements.txt found${N}"
[[ -f "${SCRIPT_DIR}/docker-compose.yml" ]] && echo -e "   ${G}✓ docker-compose.yml found${N}"
[[ -d "${SCRIPT_DIR}/data" ]] && echo -e "   ${G}✓ data/ directory exists${N}" || echo -e "   ${Y}~ data/ missing (will auto-create)${N}"
[[ -f "${SCRIPT_DIR}/app.py" ]] && echo -e "   ${G}✓ app.py found${N}"

# 5. Supervisor PID
echo -e "\n${Y}5. Supervisor${N}"
if [[ -f "${SCRIPT_DIR}/ghostphish_maintenance.pid" ]]; then
    pid=$(cat "${SCRIPT_DIR}/ghostphish_maintenance.pid")
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "   ${G}✓ Supervisor running (pid $pid)${N}"
    else
        echo -e "   ${R}✗ Supervisor PID $pid not alive${N}"
    fi
else
    echo -e "   ${R}✗ Supervisor not running${N}"
fi

echo -e "\n${C}════════════════════════════════${N}\n"
echo -e "${Y}Next steps:${N}"
echo -e "  1. Start supervisor: ${C}./launch-and-maintain.sh start${N}"
echo -e "  2. Check status: ${C}./launch-and-maintain.sh status${N}"
echo -e "  3. Watch logs: ${C}./launch-and-maintain.sh logs${N}"
echo -e "  4. If still broken, post these logs to support\n"
