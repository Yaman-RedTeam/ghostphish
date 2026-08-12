# Ghostphish - Engagement Checklist

**⚠️ Use this checklist for AUTHORIZED security testing only**

Use this document to ensure your phishing testing is properly scoped, authorized, and conducted ethically.

---

## Pre-Engagement

### Authorization & Legal
- [ ] Written Rules of Engagement (RoE) signed by target organization
- [ ] Explicit authorization for social engineering testing
- [ ] Phishing/OTP testing explicitly mentioned in RoE scope
- [ ] Test dates/timeframe documented and agreed
- [ ] Target email domains/users documented
- [ ] Liability and indemnification clauses reviewed
- [ ] Legal review completed (if required)
- [ ] NDA signed and current
- [ ] Incident contact information provided by client
- [ ] Escalation procedures documented

### Scope Definition
- [ ] Target user list prepared (emails, departments)
- [ ] Number of users to test documented
- [ ] Testing window defined (dates/times)
- [ ] Out-of-scope users identified
- [ ] Email domains confirmed
- [ ] Acceptable redirect URLs defined
- [ ] Response/remediation expectations set

### Technical Setup
- [ ] Test infrastructure isolated from production
- [ ] Domain/hosting prepared (if needed)
- [ ] SSL/TLS certificates configured
- [ ] Data storage secured and encrypted
- [ ] Logging enabled
- [ ] Backup systems configured
- [ ] Network connectivity tested
- [ ] Docker environment tested locally first

### Notifications
- [ ] IT/Security team notified of test window
- [ ] Help desk briefed on expected user reports
- [ ] SOC/Security monitoring prepared
- [ ] Incident response team on standby
- [ ] Email notification template prepared

---

## During Engagement

### Deployment
- [ ] Ghostphish container started successfully
- [ ] All endpoints responding (health check)
- [ ] Database initialized correctly
- [ ] Rate limiting configured
- [ ] Honeypot fields active
- [ ] Redirect URL set correctly
- [ ] Logging verified working
- [ ] No test data in live environment

### Testing
- [ ] Internal team test first (before launch)
- [ ] Phishing emails generated/queued
- [ ] Test begins at agreed time
- [ ] Monitoring active (logs checked hourly)
- [ ] No incidents or system impacts
- [ ] Data collection ongoing
- [ ] User questions/escalations documented

### Incident Response
- [ ] Incident hotline staffed (if configured)
- [ ] User reports logged
- [ ] Help desk notified of legitimate reports
- [ ] Quick response to user questions
- [ ] Escalations handled per RoE
- [ ] No unauthorized system access

---

## Post-Engagement

### Data Collection & Analysis
- [ ] Export captures: `python export_captures.py json`
- [ ] Export captures: `python export_captures.py csv`
- [ ] Verify data integrity and completeness
- [ ] Statistics compiled: `python export_captures.py stats`
- [ ] Analysis performed on results
- [ ] Click rate calculated
- [ ] Submission rate analyzed
- [ ] Demographics assessed (by department, etc.)

### Reporting
- [ ] Findings documented
- [ ] Statistics compiled
- [ ] Risk ratings assigned
- [ ] Recommendations provided
- [ ] Training recommendations noted
- [ ] Report drafted
- [ ] Report reviewed (legal/security)
- [ ] Report delivered to client
- [ ] Presentation scheduled (if required)

### User Notification
- [ ] Thank you email sent to test subjects
- [ ] Training provided to those who fell for phish
- [ ] Secure phishing awareness training conducted
- [ ] Resources shared for password hygiene
- [ ] Follow-up security briefing held
- [ ] Users informed of their results (if permitted)

### Cleanup
- [ ] Database export backed up: `./data/captures_backup.db`
- [ ] Database cleared: `python cleanup.py clear`
- [ ] OR database deleted: `python cleanup.py delete`
- [ ] Docker container stopped: `docker-compose down`
- [ ] Server/infrastructure decommissioned
- [ ] Test credentials removed
- [ ] Test data securely wiped
- [ ] Logs preserved (per retention policy)
- [ ] Compliance with data destruction requirements

### Security
- [ ] Captured data not shared outside authorized parties
- [ ] Credentials/OTPs not reused elsewhere
- [ ] Backup data securely stored
- [ ] Encryption keys managed properly
- [ ] No captured data left in production
- [ ] No phishing URLs publicly indexed
- [ ] Docker images/containers removed
- [ ] No sensitive data in logs

---

## Follow-up (30-60 days)

- [ ] Verify awareness training completion
- [ ] Check for security posture improvements
- [ ] Repeat testing? (if authorized)
- [ ] Measure trend in click-through rates
- [ ] Document lessons learned
- [ ] Client feedback collected
- [ ] Report metrics and outcomes

---

## Documentation to Keep

- [ ] Signed Rules of Engagement
- [ ] Scope document
- [ ] Authorization email
- [ ] Test emails/templates used
- [ ] Captured data (sanitized)
- [ ] Analysis and findings
- [ ] Final report
- [ ] Client communications

---

## Compliance Checklist

### Data Protection
- [ ] GDPR compliant (if applicable)
- [ ] Data retention limits honored
- [ ] User data not kept longer than necessary
- [ ] Data securely deleted post-engagement
- [ ] Privacy policy reviewed

### Organization Policy
- [ ] Company security policy followed
- [ ] Approval chain completed
- [ ] Incident management policy respected
- [ ] Breach notification reviewed (if applicable)

### Industry Standards
- [ ] PTES (Penetration Testing Execution Standard) followed
- [ ] OWASP guidelines considered
- [ ] Best practices implemented

---

## Common Mistakes to Avoid

❌ **Don't:**
- [ ] Test without written authorization
- [ ] Include out-of-scope users
- [ ] Use real/production email addresses
- [ ] Leave captures accessible publicly
- [ ] Store passwords or sensitive data
- [ ] Test during critical business periods
- [ ] Forget to notify IT/Security beforehand
- [ ] Leave test infrastructure running after engagement
- [ ] Discuss results outside authorized parties
- [ ] Use captured credentials elsewhere

✅ **Do:**
- [ ] Get explicit written authorization
- [ ] Define clear scope and timeline
- [ ] Maintain detailed logs
- [ ] Coordinate with IT/Security
- [ ] Provide training to targeted users
- [ ] Secure all captured data
- [ ] Clean up thoroughly post-test
- [ ] Report findings professionally
- [ ] Maintain client confidentiality
- [ ] Follow up with awareness training

---

## Contact & Escalation

**During Engagement:**
- Client POC: ________________
- Email: ________________
- Phone: ________________

**Incident Escalation:**
- Primary: ________________
- Secondary: ________________
- Emergency: ________________

**Data Handling:**
- Retention period: ________________
- Approved storage: ________________
- Deletion method: ________________

---

## Sign-Off

**Tester:** _________________________ **Date:** _________

**Client:** _________________________ **Date:** _________

**Notes:**
```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```

---

**Remember**: Authorization is everything. Always get it in writing, scope it clearly, and honor the boundaries agreed upon.
