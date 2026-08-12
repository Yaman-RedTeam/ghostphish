#!/usr/bin/env python3
"""
ghostphish — safe DB cleanup
- clear  : wipe rows, keep DB file
- delete : wipe rows + re-init empty schema (safe: does NOT leave the running
           container with a broken mount)
- purge  : DESTRUCTIVE — actually remove the DB file. Auto-restarts the
           container so the app can recreate a fresh DB on boot.

Developed by Yaman.RedTeam
"""
import os
import sys
import sqlite3
import subprocess

DB_PATH = "./data/captures.db"

# ANSI
R = "\033[0;31m"
G = "\033[0;32m"
Y = "\033[1;33m"
C = "\033[0;36m"
D = "\033[2m"
N = "\033[0m"


def _init_schema(db_path: str) -> None:
    """Create an empty captures table so app.py never 500s."""
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS captures (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            service TEXT,
            email TEXT,
            password TEXT,
            otp TEXT,
            honeypot TEXT,
            ip_address TEXT,
            user_agent TEXT,
            referer TEXT,
            attempt_number INTEGER
        )
        """
    )
    conn.commit()
    conn.close()


def clear_captures() -> bool:
    """Wipe all rows; keep DB file intact. Container keeps running fine."""
    try:
        if not os.path.exists(DB_PATH):
            print(f"  {Y}[~]{N} database not found, initialising empty one...")
            os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
            _init_schema(DB_PATH)
            print(f"  {G}[+]{N} fresh empty DB created")
            return True

        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM captures")
        count = c.fetchone()[0]

        if count == 0:
            print(f"  {C}[*]{N} no captures to clear")
            conn.close()
            return True

        confirm = input(f"  {Y}[?]{N} delete {C}{count}{N} captured records? {D}(yes/no){N} ").strip().lower()
        if confirm != "yes":
            print(f"  {D}[.]{N} cancelled")
            conn.close()
            return False

        c.execute("DELETE FROM captures")
        conn.commit()
        conn.close()

        print(f"  {G}[+]{N} deleted {count} captures · DB file kept")
        return True

    except Exception as e:
        print(f"  {R}[!]{N} error: {e}")
        return False


def delete_database() -> bool:
    """
    Safe delete — wipes rows AND recreates empty schema in place.
    App keeps running, no 500s.
    """
    try:
        confirm = input(f"  {Y}[?]{N} reset database to empty? {D}(yes/no){N} ").strip().lower()
        if confirm != "yes":
            print(f"  {D}[.]{N} cancelled")
            return False

        os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

        # Drop the table entirely, then recreate
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("DROP TABLE IF EXISTS captures")
        conn.commit()
        conn.close()

        _init_schema(DB_PATH)

        print(f"  {G}[+]{N} database reset · schema recreated · app unaffected")
        return True

    except Exception as e:
        print(f"  {R}[!]{N} error: {e}")
        return False


def purge_database() -> bool:
    """
    DESTRUCTIVE — remove the DB file entirely. Also restarts the running
    container (if any) so its stale volume mount is refreshed and the app
    doesn't 500.
    """
    try:
        print(f"  {R}[!]{N} PURGE will remove the DB file AND restart the container.")
        confirm = input(f"  {Y}[?]{N} continue? type {R}PURGE{N} to confirm: ").strip()
        if confirm != "PURGE":
            print(f"  {D}[.]{N} cancelled")
            return False

        if os.path.exists(DB_PATH):
            os.remove(DB_PATH)
            print(f"  {G}[+]{N} removed {DB_PATH}")
        else:
            print(f"  {C}[*]{N} DB file didn't exist")

        # Recreate dir + empty file so mount stays valid
        os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
        _init_schema(DB_PATH)
        print(f"  {G}[+]{N} fresh empty DB in place")

        # Try to restart the container to refresh its mount
        try:
            subprocess.run(
                ["docker", "restart", "ghostphish"],
                check=True, capture_output=True, text=True, timeout=15,
            )
            print(f"  {G}[+]{N} container restarted · app back online")
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            print(f"  {Y}[~]{N} could not auto-restart · run: {C}docker-compose restart{N}")

        return True

    except Exception as e:
        print(f"  {R}[!]{N} error: {e}")
        return False


def usage() -> None:
    print(f"""
  {Y}Usage:{N} python3 cleanup.py {C}[clear|delete|purge]{N}

    {G}clear{N}    wipe rows, keep DB file           {D}(safest, default choice){N}
    {G}delete{N}   drop + recreate empty schema      {D}(safe reset, app unaffected){N}
    {R}purge{N}    remove DB file + restart container {D}(destructive · needs 'PURGE' typed){N}
""")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if   cmd == "clear":  sys.exit(0 if clear_captures() else 1)
    elif cmd == "delete": sys.exit(0 if delete_database() else 1)
    elif cmd == "purge":  sys.exit(0 if purge_database() else 1)
    else:
        print(f"  {R}[!]{N} unknown command: {cmd}")
        usage()
        sys.exit(1)
