Last Modified: 08/17/2026 (1786902544) by amonrit

# Credential Setup - Quick Start for Developers

This is the **quick reference** for setting up credentials locally. For comprehensive details, see [[CREDENTIAL_MANAGEMENT]].

---

## 🚀 First Time Setup (5 minutes)

### Step 1: Create Your Local .env.local File

```bash
cd streaming
cp .env.example .env.local
```

### Step 2: Generate Strong Passwords

For **each** environment (dev, staging, production), create unique passwords:

```bash
# Option A: Using openssl
openssl rand -base64 32

# Option B: Using Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Option C: Use 1Password, LastPass, or your password manager
```

### Step 3: Edit .env.local with Your Credentials

```bash
# Edit streaming/.env.local and replace placeholders:

# Replace these with actual values (never commit!)
PUBLISH_USER=publish
PUBLISH_PASS=<paste-your-generated-password>

API_VIEWER_USER=apiviewer
API_VIEWER_PASS=<paste-your-generated-password>
```

### Step 4: Verify .env.local is in .gitignore

✅ Already done! The repository has:
```gitignore
.env.local
.env.*.local
```

### Step 5: Start Docker and Test

```bash
cd streaming
docker-compose up -d

# Run the test script (uses env vars from .env.local)
bash test-streaming.sh
```

---

## 📋 Checklist: Before Making Your First Commit

- [ ] `.env.local` file exists with real credentials
- [ ] `.env.local` is **NOT** in git (should be in .gitignore)
- [ ] Check: `git status | grep .env` → Should be empty
- [ ] Credentials are **not** hardcoded in Swift files
- [ ] Test script uses environment variables, not hardcoded values
- [ ] Docker starts successfully with new env vars
- [ ] RTMP publishing works with new credentials

---

## ⚠️ Security Rules

### ✅ DO
- ✅ Keep `.env.local` in `.gitignore`
- ✅ Use strong, unique passwords (32+ characters)
- ✅ Store credentials in password manager (1Password, LastPass, etc.)
- ✅ Rotate credentials quarterly
- ✅ Load credentials from environment variables in code

### ❌ DON'T  
- ❌ Commit `.env.local` to git
- ❌ Share credentials via Slack, email, or chat
- ❌ Use same credentials across environments
- ❌ Hardcode credentials in source code (Swift, bash scripts)
- ❌ Keep credentials in plain text on your machine

---

## 🐛 Troubleshooting

### Issue: "Module not found" or ".env.local doesn't exist"

**Solution:**
```bash
cd streaming
cp .env.example .env.local
```

### Issue: Docker can't authenticate (RTMP publish fails)

**Solution:**
```bash
# Check if .env.local is loaded
docker exec mediamtx env | grep PUBLISH

# If empty, restart Docker
docker-compose down
docker-compose up -d
```

### Issue: "Can't connect to localhost:9997" (API access denied)

**Solution:**
```bash
# Verify API credentials in .env.local
grep "API_VIEWER" streaming/.env.local

# Test with credentials
curl -u "apiviewer:<your-password>" http://localhost:9997/v3/paths/list
```

### Issue: Forgot password to my local streaming server

**Solution:**
```bash
# Just regenerate it locally
openssl rand -base64 32

# Edit streaming/.env.local with new password
# Restart Docker
docker-compose down
docker-compose up -d
```

---

## 📚 Related Documentation

- **[[CREDENTIAL_MANAGEMENT]]** — Full credential lifecycle strategy
- **[[CREDENTIAL_ROTATION]]** — How to rotate credentials
- **[[#8]]** — Implement Keychain storage (iOS)
- **[[#9]]** — Require RTMP authentication
- **[[#10]]** — Remove hardcoded credentials from iOS code
- **[[#11]]** — Remove hardcoded credentials from test scripts

---

## 🔗 External Resources

- [1Password Password Generator](https://1password.com/)
- [OpenSSL random password generation](https://www.openssl.org/)
- [MediaMTX Authentication Docs](https://github.com/bluenviron/mediamtx)
- [iOS Keychain Documentation](https://developer.apple.com/documentation/security/keychain_services)
