#!/data/data/com.termux/files/usr/bin/bash
#
# ghostphish — Termux installer (for Android phones)
# Developed by Yaman.RedTeam
#
# What it does:
#   1. Updates termux pkg list
#   2. Installs python + git + curl + tur-repo (for cloudflared)
#   3. Installs cloudflared
#   4. Installs FastAPI + uvicorn (from requirements.txt)
#   5. Launches ./start.sh (which auto-detects no-Docker and runs Python directly)
#
# Run: bash termux-setup.sh
#

set -e

R=$'\033[38;5;196m'
G=$'\033[38;5;46m'
Y=$'\033[38;5;220m'
C=$'\033[38;5;51m'
W=$'\033[38;5;255m'
D=$'\033[2m'
N=$'\033[0m'

banner() {
    clear
    echo ""
    echo -e "  ${R}▄▄  ${W}ghostphish${N}  ${D}termux installer${N}"
    echo -e "  ${R}▀▀  ${D}Developed by ${R}Yaman.RedTeam${N}"
    echo -e "  ${D}────────────────────────────────────────${N}"
    echo ""
}

msg_ok()   { printf "  ${G}[+]${N} %s\n" "$*"; }
msg_info() { printf "  ${C}[*]${N} %s\n" "$*"; }
msg_err()  { printf "  ${R}[!]${N} %s\n" "$*"; }

banner

# ─── 1. Termux check ─────────────────────────────
if [ ! -d /data/data/com.termux ]; then
    msg_err "This script is for Termux (Android) only."
    msg_info "On Linux/Mac use: ./start.sh"
    exit 1
fi
msg_ok "Termux detected"

# ─── 2. Storage permission ───────────────────────
if [ ! -d ~/storage ]; then
    msg_info "Requesting storage access (grant permission when asked)..."
    termux-setup-storage 2>/dev/null || true
fi

# ─── 3. Package updates ──────────────────────────
msg_info "Updating package index..."
pkg update -y > /dev/null 2>&1
msg_ok "packages updated"

# ─── 4. Core dependencies ────────────────────────
msg_info "Installing python + git + curl + openssl + build toolchain..."
pkg install -y python git curl openssl python-pip \
                clang binutils rust patchelf > /dev/null 2>&1
msg_ok "python $(python3 --version 2>&1 | cut -d' ' -f2) installed"
msg_ok "rust $(rustc --version 2>&1 | awk '{print $2}') installed (needed for pydantic-core)"

# ─── 5. tur-repo (needed for cloudflared) ────────
if ! command -v cloudflared >/dev/null 2>&1; then
    msg_info "Enabling tur-repo (has cloudflared)..."
    pkg install -y tur-repo > /dev/null 2>&1

    msg_info "Installing cloudflared..."
    if pkg install -y cloudflared > /dev/null 2>&1; then
        msg_ok "cloudflared installed"
    else
        # Fallback: download prebuilt ARM binary
        msg_info "Package not available, downloading ARM binary..."
        ARCH=$(uname -m)
        case "$ARCH" in
            aarch64) BIN="cloudflared-linux-arm64" ;;
            armv7l|armv8l) BIN="cloudflared-linux-arm" ;;
            *) msg_err "unsupported arch: $ARCH"; exit 1 ;;
        esac
        curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/$BIN" \
             -o "$PREFIX/bin/cloudflared"
        chmod +x "$PREFIX/bin/cloudflared"
        msg_ok "cloudflared binary installed ($ARCH)"
    fi
else
    msg_ok "cloudflared already installed"
fi

# ─── 6. Python deps ──────────────────────────────
# NOTE: do NOT run `pip install --upgrade pip` on Termux — it breaks python-pip.
# NOTE: Python 3.14 broke pydantic v1 (type-inference changes), so we install
#       fastapi + pydantic v2. That requires Rust to compile pydantic-core
#       (installed above in step 4). First install may take 15-30 minutes.
msg_info "Wiping any incompatible pydantic v1 leftovers..."
pip uninstall -y fastapi pydantic pydantic-core 2>/dev/null | tail -1 || true

msg_info "Installing fastapi + pydantic v2 (may take 15-30 min for pydantic-core Rust build)..."
export CARGO_BUILD_JOBS=1  # keep RAM sane on phones
if pip install -r requirements.txt; then
    msg_ok "python deps installed"
else
    msg_err "pip install failed. Full log above."
    msg_info "Manual retry: cd $(pwd) && pip install -r requirements.txt"
    exit 1
fi

echo ""
echo -e "  ${D}────────────────────────────────────────${N}"
msg_ok "${W}Termux setup complete!${N}"
echo ""
echo -e "  ${Y}Next:${N}"
echo -e "    ${W}./start.sh${N}          ${D}(interactive CLI menu)${N}"
echo ""
echo -e "  ${D}Or manually:${N}"
echo -e "    ${D}python3 -m uvicorn app:app --host 0.0.0.0 --port 8000 &${N}"
echo -e "    ${D}cloudflared tunnel --url http://localhost:8000${N}"
echo ""
