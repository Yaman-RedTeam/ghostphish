# Docker Issues & Fixes

## Error: "bash: sudo: command not found" or "bash: lsof: command not found"

### Cause
You're trying to run `./launch-and-maintain.sh` **inside the Docker container**, but the script is designed for the host system.

### ✅ Correct Way to Run

**On HOST (your Linux machine, NOT inside container):**

```bash
# Make sure Docker is installed
docker --version
docker-compose --version

# Start via docker-compose (correct)
cd ghostphish
docker-compose up -d

# Check status
docker logs ghostphish -f

# Stop
docker-compose down
```

**Do NOT do this:**
```bash
# WRONG: Don't run host scripts inside container
docker-compose exec ghostphish ./launch-and-maintain.sh start  # ❌ WRONG
```

---

## Proper Setup

### 1. First Time Setup
```bash
git clone https://github.com/Yaman-RedTeam/ghostphish.git
cd ghostphish

# Initialize data directory
./init.sh

# Start via docker-compose (on host)
docker-compose up -d
```

### 2. Check Status
```bash
# View logs
docker logs ghostphish

# Check health
curl http://localhost:8000/health

# View captures
curl http://localhost:8000/admin/captures | jq
```

### 3. Stop
```bash
docker-compose down
```

---

## If Docker is Not Available

If you don't have Docker or it's not working:

### Option A: Run Directly with Python
```bash
# Install dependencies
pip install -r requirements.txt

# Initialize database
./init.sh

# Run app
export GHOSTPHISH_DATA=$PWD/data
python3 -m uvicorn app:app --host 0.0.0.0 --port 8000
```

### Option B: Run via Launch Script (Host Only)
```bash
# This script should only run on HOST, not inside container
./launch-and-maintain.sh start

./launch-and-maintain.sh status

./launch-and-maintain.sh stop
```

---

## Troubleshooting

### Docker Container Exits Immediately
**Check logs:**
```bash
docker logs ghostphish
```

**Common reasons:**
1. Port 8000 already in use: `lsof -i :8000` or `netstat -tlnp | grep 8000`
2. Database permission issues: `chmod 777 data/`
3. Python error: Check app.py for syntax errors

### Fix Port Conflict
```bash
# Use different port
docker-compose down
# Edit docker-compose.yml: change "8000:8000" to "9000:8000"
docker-compose up -d
```

### Reset Database
```bash
# Clear captures but keep schema
python3 cleanup.py clear

# Or reset everything
python3 cleanup.py purge
```

---

## Docker Compose Quick Reference

```bash
# Start (background)
docker-compose up -d

# Start (foreground logs)
docker-compose up

# Stop
docker-compose down

# View logs
docker-compose logs -f ghostphish

# Rebuild image
docker-compose build --no-cache

# Restart container
docker-compose restart

# Execute command in container
docker-compose exec ghostphish <command>

# Check status
docker-compose ps
```

---

## For Termux / No Docker Users

See: `TERMUX_SETUP.md`

Use `./launch-termux.sh` instead of `./launch-and-maintain.sh`
