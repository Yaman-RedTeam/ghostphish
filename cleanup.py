#!/usr/bin/env python3
"""
Cleanup captured data - securely wipe the database
"""

import sqlite3
import os
import sys

DB_PATH = "./data/captures.db"

def clear_captures():
    """Delete all captured data"""
    try:
        if not os.path.exists(DB_PATH):
            print("[-] Database not found")
            return False

        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        c.execute("SELECT COUNT(*) FROM captures")
        count = c.fetchone()[0]

        if count == 0:
            print("[*] No captures to clear")
            conn.close()
            return True

        confirm = input(f"[!] Delete {count} captured records? (yes/no): ").strip().lower()
        if confirm != "yes":
            print("[*] Cancelled")
            return False

        c.execute("DELETE FROM captures")
        c.execute("DELETE FROM rate_limits")
        conn.commit()
        conn.close()

        print(f"[+] Deleted {count} captures")
        return True

    except Exception as e:
        print(f"[-] Error: {e}")
        return False

def delete_database():
    """Remove entire database file"""
    try:
        confirm = input("[!] Delete entire database file? (yes/no): ").strip().lower()
        if confirm != "yes":
            print("[*] Cancelled")
            return False

        if os.path.exists(DB_PATH):
            os.remove(DB_PATH)
            print(f"[+] Deleted database: {DB_PATH}")
            return True
        else:
            print("[-] Database file not found")
            return False

    except Exception as e:
        print(f"[-] Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python cleanup.py [clear|delete]")
        print("  clear  - Delete all captured records (keeps database)")
        print("  delete - Remove entire database file")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "clear":
        clear_captures()
    elif cmd == "delete":
        delete_database()
    else:
        print("Unknown command. Use: clear or delete")
