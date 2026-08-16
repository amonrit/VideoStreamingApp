Last Modified: 08/17/2026 (1786902544) by amonrit

# Credential Rotation Guide - Steam Project

## Overview

This guide covers **how to rotate credentials** for the Steam project in development and production environments. Credential rotation should happen:

- **Immediately** if a credential is compromised or leaked
- **Quarterly** as routine security maintenance
- **Annually** at minimum for production systems
- **On personnel changes** (departing team members)

---

## Quick Reference: Who Rotates What

| Credential | Frequency | Method | Owner | Downtime |
|------------|-----------|--------|-------|----------|
| `PUBLISH_USER/PASS` | Quarterly | Restart Docker | DevOps | ~30 seconds |
| `API_VIEWER_USER/PASS` | Quarterly | Restart Docker | DevOps | ~30 seconds |
| iOS Keychain | On access error | User re-authenticates | User | None |

---

## Part 1: Local Development Credential Rotation

### For Local `.env.local` File

**Why rotate?** Keep local environment similar to production; test rotation procedures.

**Frequency:** Weekly during development, or whenever needed.

**Steps:**

1. **Backup current credentials** (if you need to reference them):
   ```bash
   cp streaming/.env.local streaming/.env.local.backup
   ```

2. **Generate new strong passwords:**
   ```bash
   # Option A: Use OpenSSL
   openssl rand -base64 32
   
   # Option B: Use Python
   python3 -c "import secrets; print(secrets.token_urlsafe(32))"
   
   # Option C: Use 1Password, LastPass, or similar
   ```

3. **Update `.env.local`:**
   ```bash
   # Edit streaming/.env.local
   PUBLISH_USER=publish
   PUBLISH_PASS=<NEW-STRONG-PASSWORD>
   API_VIEWER_USER=apiviewer
   API_VIEWER_PASS=<NEW-STRONG-PASSWORD>
   ```

4. **Restart Docker containers:**
   ```bash
   cd streaming
   docker-compose down
   docker-compose up -d
   ```

5. **Verify streaming server loaded new credentials:**
   ```bash
   docker logs mediamtx | grep "auth"
   ```

6. **Test publishing with new credentials:**
   ```bash
   ffmpeg -re -i test_pattern.mp4 \
     -c copy -f flv \
     "rtmp://publish:<NEW-PASSWORD>@localhost:1935/live/test"
   ```

7. **Update test scripts** (if they reference credentials):
   ```bash
   # Update streaming/test-streaming.sh if it has hardcoded credentials
   # OR reload from .env:
   source streaming/.env.local
   ```

8. **Verify iOS app still works:**
   - Update Keychain with new credentials if stored there
   - Re-authenticate when prompted by app

9. **Delete backup** (if created):
   ```bash
   rm streaming/.env.local.backup
   ```

---

## Part 2: Production Credential Rotation

### Preparation (Before Rotation)

1. **Notify stakeholders:**
   - Team members using the streaming service
   - Any external services with API access
   - Give 24-hour notice for planned rotation

2. **Prepare new credentials:**
   ```bash
   # Generate new passwords (DO NOT use on local machine)
   # Use a secure password manager or CI/CD secret generator
   ```

3. **Verify rollback plan:**
   - Have old credentials available for 24 hours post-rotation
   - Document rollback procedure

### Procedure: Rotating RTMP Publishing Credentials (PUBLISH_USER/PASS)

**Estimated downtime:** 30 seconds (during Docker restart)

**Steps:**

1. **In your CI/CD system** (GitHub Actions / GitLab CI / etc.):
   - Update `PROD_PUBLISH_PASS` secret with new password
   - Keep old password documented temporarily (for 24 hours)

2. **Trigger deployment:**
   ```bash
   # For GitHub Actions: manually trigger workflow
   # For manual deployment:
   
   ssh deploy@prod-server
   cd ~/steam/streaming
   
   # Pull latest (with new env vars from secrets)
   docker-compose pull
   
   # Restart with new credentials
   docker-compose down
   docker-compose up -d
   ```

3. **Verify server is running:**
   ```bash
   docker ps | grep mediamtx
   docker logs mediamtx | tail -20
   ```

4. **Test publishing with NEW credentials:**
   ```bash
   ffmpeg -re -i video.mp4 \
     -c copy -f flv \
     "rtmp://publish:<NEW-PASSWORD>@prod-server:1935/live/test"
   
   # Should succeed
   ```

5. **Test publishing with OLD credentials:**
   ```bash
   ffmpeg -re -i video.mp4 \
     -c copy -f flv \
     "rtmp://publish:<OLD-PASSWORD>@prod-server:1935/live/test"
   
   # Should FAIL (authentication error)
   # If this succeeds, rotation failed!
   ```

6. **Notify team:**
   - "RTMP publishing credentials have been rotated"
   - "Update any external publishing tools"
   - "Old credentials will be disabled in 24 hours"

7. **Monitor for issues:**
   - Check for failed publishing attempts in logs
   - Watch for alert notifications

8. **After 24 hours:**
   - Archive old password in secure vault
   - Remove temporary documentation

### Procedure: Rotating API Viewer Credentials (API_VIEWER_USER/PASS)

**Estimated downtime:** 30 seconds (during Docker restart)

**Steps:**

1. **Similar to RTMP rotation above**, but:
   - Update `PROD_API_VIEWER_PASS` instead
   - Update iOS app's Keychain or config (see below)

2. **Special consideration for iOS app:**
   - If credentials are hardcoded: requires app update and re-submission
   - If stored in Keychain: app automatically re-prompts user
   - If fetched from secure endpoint: endpoint must provide new credentials

3. **Test API access with NEW credentials:**
   ```bash
   # Test from local machine (after updating your .env.local)
   curl -u "apiviewer:<NEW-PASSWORD>" \
     "http://prod-server:9997/v3/paths/list"
   
   # Should succeed
   ```

4. **Wait for iOS app deployment** (if needed):
   - If hardcoded: update app, go through App Store review (~1 day)
   - If dynamic: immediate effect once server restarts

---

## Part 3: iOS App Credential Rotation

### Scenario 1: Credentials Stored in Keychain (Recommended)

**Process:**
1. User is prompted: "Server requires re-authentication"
2. User enters new credentials
3. App stores them in Keychain (encrypted)
4. App continues normally

**No action needed** - automatic!

### Scenario 2: Credentials Hardcoded in App (Current Status - FIX)

**Current problem:** 
- Credentials embedded in app binary
- Cannot rotate without releasing new app version

**How to fix (Issue #10):**
- Remove hardcoded credentials from `MediaMTXConfig.swift`
- Implement Keychain storage
- See [[#8]] - Implement Keychain-based credential storage

### Scenario 3: Credentials Fetched from Server

**Process:**
1. App starts, requests credentials from secure endpoint
2. Server returns current credentials
3. App stores them in Keychain
4. When server credentials change, next app restart loads new ones

---

## Part 4: Emergency Credential Revocation

### If Credentials Are Compromised

**Immediately (within 1 hour):**

1. **Revoke access:**
   ```bash
   # For RTMP publishing
   ssh deploy@prod-server
   cd ~/steam/streaming
   
   # Temporarily disable compromised user in mediamtx.yml
   # Set PUBLISH_USER to random value
   export PUBLISH_USER="revoked_$(date +%s)"
   export PUBLISH_PASS="revoked_$(openssl rand -base64 32)"
   
   docker-compose down
   docker-compose up -d
   ```

2. **Notify stakeholders immediately:**
   - "RTMP publishing temporarily disabled during credential rotation"
   - "Old credentials are now invalid"

3. **Generate new credentials:**
   - Use strong random password generator
   - Store in password manager
   - Document in incident log

4. **Deploy new credentials:**
   - Follow production rotation steps above
   - Test thoroughly

5. **Audit logs for unauthorized access:**
   ```bash
   docker logs mediamtx | grep "publish" | tail -100
   # Look for successful publishes during compromise window
   ```

6. **Post-incident actions:**
   - Document what happened
   - Identify how credentials leaked
   - Implement prevention measures

---

## Part 5: Credential Rotation Audit Trail

### Maintain a Rotation Log

**File:** `docs/CREDENTIAL_ROTATION_LOG.txt` (NOT in git)

```
========================================
CREDENTIAL ROTATION LOG
========================================

2026-08-20 10:30 - Development
- Rotated: PUBLISH_USER/PASS
- Method: Docker restart
- Status: OK
- Verified: Yes
- Reason: Routine maintenance

2026-08-25 14:00 - Production  
- Rotated: API_VIEWER_PASS
- Method: CI/CD deployment
- Status: OK
- Verified: Yes
- Reason: Quarterly security rotation

2026-09-10 09:15 - Emergency - Production
- Rotated: PUBLISH_USER/PASS (compromised)
- Method: Emergency revocation + reissue
- Status: OK
- Verified: Yes
- Reason: Credentials found in GitHub history
```

### Automation Option

Set up reminders in your calendar/task system:
- "Quarterly credential rotation review" (every 3 months)
- "Annual security audit" (yearly)

---

## Verification Checklist

After rotating any credentials, verify:

### ✅ Server-Side Verification
- [ ] Docker containers restarted successfully
- [ ] No error logs in Docker output
- [ ] Old credentials rejected with authentication error
- [ ] New credentials accepted for publishing/API access

### ✅ Client Verification  
- [ ] Publishing tools updated with new credentials
- [ ] iOS app re-authenticates successfully
- [ ] Web dashboards (if any) updated
- [ ] Test scripts updated

### ✅ Documentation
- [ ] Rotation logged in `CREDENTIAL_ROTATION_LOG.txt`
- [ ] Team notified of changes
- [ ] Any dependent services updated
- [ ] Old credentials securely archived (if needed temporarily)

---

## Common Issues & Troubleshooting

### Issue: Old Credentials Still Work After Rotation

**Cause:** Docker container didn't restart, or env vars not loaded  
**Fix:**
```bash
docker-compose down
docker-compose up -d
docker logs mediamtx | grep auth
```

### Issue: New Credentials Don't Work

**Cause:** Typo in new password, or container failed to start  
**Fix:**
```bash
# Verify .env file
cat streaming/.env.local | grep "PUBLISH_PASS\|API_VIEWER_PASS"

# Check container status
docker ps | grep mediamtx

# Check logs
docker logs mediamtx
```

### Issue: iOS App Can't Authenticate After Rotation

**Cause:** App still using old credentials from Keychain  
**Fix:**
1. Open iOS Settings → General → iPhone Storage
2. Find "Steam" app
3. Delete or tap "Offload App" to clear Keychain
4. Reinstall app
5. Re-authenticate when prompted

### Issue: External Integrations Fail After Rotation

**Cause:** External services still using old credentials  
**Fix:**
1. Update credentials in external service config
2. Restart external service
3. Verify connectivity

---

## Best Practices

### ✅ DO
- ✅ Use strong, random passwords (32+ characters)
- ✅ Keep rotation log and audit trail
- ✅ Test new credentials before removing old ones
- ✅ Give 24-hour grace period before disabling old credentials
- ✅ Notify stakeholders before planned rotations
- ✅ Document emergency procedures
- ✅ Rotate quarterly as standard practice

### ❌ DON'T
- ❌ Share credentials via Slack, email, or unencrypted channels
- ❌ Commit credentials to git (even in history)
- ❌ Use same credentials across dev/staging/production
- ❌ Keep credentials in plain text on local machines
- ❌ Delay rotation after suspected compromise
- ❌ Rotate without testing first
- ❌ Delete old credentials immediately (keep 24-hour grace period)

---

## Related Documentation

- [[CREDENTIAL_MANAGEMENT]] - Overall credential strategy
- [[#8]] - Implement Keychain-based storage (remove hardcoding)
- [[#9]] - Configure authentication in mediamtx.yml
- [[#10]] - Remove hardcoded credentials from iOS code
- [[#11]] - Remove hardcoded credentials from test scripts
