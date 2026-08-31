# Ghostphish on Termux – Setup Guide

## Why Termux is Different

Termux doesn't have:
- `sudo` command (runs as single user)
- `lsof` command (not needed in Termux)
- Full Docker support (limited)
- System package managers like `apt-get`

## Installation Steps

### 1. Install Dependencies
```bash
pkg update && pkg upgrade -y

# Install Python + pip
pkg install python3 -y

# Install cloudflared (for tunnel)
pkg install cloudflared -y

# Optional: curl for health checks
pkg install curl -y
```

### 2. Clone & Setup Ghostphish
```bash
git clone https://github.com/Yaman-RedTeam/ghostphish.git
cd ghostphish

# Initialize database
./init.sh

# Install Python dependencies
pip install -r requirements.txt
```

### 3. Run Without Docker (Python Direct)
**Termux doesn't support Docker well** — run the app directly:

```bash
# Start app + tunnel together
./launch-and-maintain-termux.sh start

# Check status
./launch-and-maintain-termux.sh status

# View logs
./launch-and-maintain-termux.sh logs

# Stop everything
./launch-and-maintain-termux.sh stop
```

---

## Troubleshooting

### Error: "bash: sudo: command not found"
**Solution:** Don't use `sudo` in Termux. The script should work without it.
- Use `./script.sh` instead of `sudo ./script.sh`

### Error: "bash: lsof: command not found"
**Solution:** Install it or use alternative:
```bash
# Try installing lsof
pkg install lsof -y

# Or use alternative commands (already handled in script)
```

### Docker not available
**Solution:** Run directly with Python:
```bash
export GHOSTPHISH_DATA=$PWD/data
python3 -m uvicorn app:app --host 0.0.0.0 --port 8000
```

### Database permission errors
**Solution:** Ensure proper permissions:
```bash
chmod 755 data/
chmod 666 data/*.db 2>/dev/null || true
```

### Tunnel not starting
**Solution:** Cloudflared might not be available:
```bash
# Check if installed
which cloudflared

# If not, install
pkg install cloudflared -y

# Or try manual setup
cloudflared tunnel --url http://localhost:8000
```

---

## Running Ghostphish on Termux (Quick Start)

### Terminal 1 - App
```bash
cd ghostphish
export GHOSTPHISH_DATA=$PWD/data
python3 -m uvicorn app:app --host 0.0.0.0 --port 8000
```

### Terminal 2 - Tunnel (optional)
```bash
cd ghostphish
cloudflared tunnel --url http://localhost:8000
```

### Terminal 3 - Check Status
```bash
curl http://localhost:8000/health
curl http://localhost:8000/admin/captures | jq
```

---

## Important Notes for Termux Users

✅ **Works on Termux:**
- Python FastAPI app
- SQLite database
- Cloudflared tunnel (if installed)
- File I/O and data capture

❌ **Doesn't work on Termux:**
- Docker/Docker-compose (limited support)
- `sudo` command (not needed)
- `lsof` command (alternatives available)
- Named tunnels (need proper setup)

---

## Environment Variables

When running on Termux, set these:

```bash
export GHOSTPHISH_DATA=$HOME/ghostphish/data    # Data directory
export PATH="$PATH:$PREFIX/bin"                 # Termux bin path
export PYTHONPATH="$PREFIX/lib/python3.11/site-packages"  # Python path
```

---

## Persistence (Keep Running in Background)

Use `nohup` or `setsid` to keep running when terminal closes:

```bash
# Method 1: nohup (output to file)
nohup python3 -m uvicorn app:app --host 0.0.0.0 --port 8000 > ghostphish.log 2>&1 &

# Method 2: setsid (completely detached)
setsid python3 -m uvicorn app:app --host 0.0.0.0 --port 8000 >/dev/null 2>&1 < /dev/null &

# Check if running
ps aux | grep uvicorn

# Kill process
pkill -f "uvicorn app:app"
```

---

## Reporting Issues

If you hit errors:
1. Check `data/captures.db` exists: `ls -la data/`
2. Check app running: `curl http://localhost:8000/health`
3. Check database: `sqlite3 data/captures.db ".tables"`
4. Share error output with complete command used

**GitHub Issues:** https://github.com/Yaman-RedTeam/ghostphish/issues
