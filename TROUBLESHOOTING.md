# Troubleshooting: "Site can't be reached"

If you're getting "**This site can't be reached**" when opening phishing links, this guide will fix it permanently.

## Quick Diagnosis

Run this first:

```bash
./diagnose.sh
```

It will tell you exactly what's broken (app, tunnel, or dependencies).

## The Problem

Ghostphish has two parts that must both be alive:
1. **App** (FastAPI server on `localhost:8000`)
2. **Tunnel** (Cloudflare quick-tunnel to make it public)

If either dies, links stop working. Most users manually start the tunnel with `./tunnel.sh`, which dies as soon as they close the terminal — the link dies with it.

## The Solution: Unified Launcher (Recommended)

Instead of juggling two separate processes, use the **unified launcher** that keeps both alive automatically:

### Start Once
```bash
./launch-and-maintain.sh start
```

This:
- ✓ Starts the app
- ✓ Starts the tunnel
- ✓ Keeps both alive in background
- ✓ Auto-restarts if either crashes
- ✓ Survives terminal/SSH disconnect
- ✓ Shows you the current public URL

### Check Status Anytime
```bash
./launch-and-maintain.sh status
```

Output:
```
   App              ✓
   Tunnel           ✓
   
   Public URL: https://xxxxx.trycloudflare.com
   
   ── Phishing pages ──
   instagram          https://xxxxx.trycloudflare.com/instagram
   facebook           https://xxxxx.trycloudflare.com/facebook
   ...
```

### Copy the URL
Use the URL from the status command. It will **keep working** until you explicitly stop the supervisor.

### Watch What's Happening
```bash
./launch-and-maintain.sh logs
```

### Stop When Done
```bash
./launch-and-maintain.sh stop
```

---

## Why Links Stopped Working (Specific Scenarios)

### Scenario 1: Used `./start.sh` then closed terminal
**What happened:** `./start.sh` includes a tunnel, but it dies when you close the terminal.

**Fix:**
```bash
./launch-and-maintain.sh start
```

### Scenario 2: Used `./tunnel.sh`
**What happened:** You started the app, then ran `./tunnel.sh`, then closed it. The tunnel died but the app stayed up. The URL became unreachable.

**Fix:**
```bash
# Stop old processes
docker kill ghostphish 2>/dev/null
pkill cloudflared 2>/dev/null

# Start unified launcher
./launch-and-maintain.sh start
```

### Scenario 3: Docker container or Python process crashed
**What happened:** The app died (out of memory, database error, etc.). Tunnel kept running but app wasn't there.

**Fix:**
```bash
./launch-and-maintain.sh start
```
The unified launcher detects this and auto-restarts the app.

### Scenario 4: Old tunnel URL from a prior session
**What happened:** You got a URL, closed everything, then opened new links the next day. The URL expired.

**Fix:**
Get a fresh URL:
```bash
./launch-and-maintain.sh status
```
Copy the **new** URL and send that instead.

---

## If Still Broken

### 1. Check diagnostics
```bash
./diagnose.sh
```

### 2. Check if cloudflared is installed
```bash
command -v cloudflared
```

If not, install it:
```bash
# Linux
sudo wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -O /usr/local/bin/cloudflared && sudo chmod +x /usr/local/bin/cloudflared

# macOS
brew install cloudflared
```

### 3. Check for old processes
```bash
docker ps | grep ghostphish
ps aux | grep uvicorn
ps aux | grep cloudflared
```

Kill any strays:
```bash
docker kill ghostphish 2>/dev/null
pkill -f "uvicorn app:app" 2>/dev/null
pkill cloudflared 2>/dev/null
```

### 4. Watch the logs
```bash
./launch-and-maintain.sh logs
```

This will show you exactly where it's failing (database error, port conflict, etc.).

### 5. Try Docker vs Python
If Docker is causing issues, force Python mode:
```bash
pkill -f docker-compose 2>/dev/null
GHOSTPHISH_DATA=./data python3 -m uvicorn app:app --host 0.0.0.0 --port 8000
```

### 6. Check port conflicts
```bash
lsof -i :8000          # Is port 8000 in use?
lsof -i :8443          # Is port 8443 in use?
```

If something else is using port 8000, you'll need to free it:
```bash
kill -9 <PID from lsof output>
```

---

## The "Permanent" Fix

This is permanent because:
1. **Unified launcher** keeps both app and tunnel alive
2. **Auto-restart** on any crash
3. **Background supervisor** survives terminal/SSH close
4. **Health checks** every 10 seconds ensure availability
5. **Single URL** you can rely on (until you restart, which generates a new one per Cloudflare quick-tunnel design)

For a **truly permanent URL that never changes**, you need:
- Cloudflare account
- Your own domain
- Named tunnel setup (see README.md section on cloudflared named tunnels)

---

## Commands Reference

```bash
# Start supervisor + app + tunnel (all-in-one)
./launch-and-maintain.sh start

# Check what's running and show all URLs
./launch-and-maintain.sh status

# Quick health probe (for scripts)
./launch-and-maintain.sh health

# Watch combined logs in real-time
./launch-and-maintain.sh logs

# Stop everything gracefully
./launch-and-maintain.sh stop

# Diagnose what's broken
./diagnose.sh
```

---

## Still Issues?

If nothing works, the old launchers still exist as fallbacks:

**For manual one-shot tunnel** (dies on Ctrl+C):
```bash
./tunnel.sh
```

**For persistent tunnel supervisor** (stays alive in background):
```bash
./tunnel-persistent.sh start
./tunnel-persistent.sh status
./tunnel-persistent.sh stop
```

But use `launch-and-maintain.sh` for the best experience — it handles both app and tunnel together.
