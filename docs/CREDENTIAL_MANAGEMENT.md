Last Modified: 08/17/2026 (1786902544) by amonrit

# Steam Project - Credential Management Strategy

## Overview

This document defines the **credential lifecycle strategy** for the Steam project: how credentials flow from generation through environment variables to secure storage (Keychain on iOS, environment variables on server).

**Scope:** Both iOS app and streaming server

---

## Credential Lifecycle: Generation → Environment → Storage

### Phase 1: Credential Generation

Credentials are generated **once** per environment and stored securely outside source control.

```
┌─────────────────────────────────────────────────────────────────┐
│                    GENERATION PHASE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Generate strong, unique credentials for each environment:   │
│     - Development (local machine)                               │
│     - Staging (internal testing)                                │
│     - Production (public deployment)                            │
│                                                                  │
│  2. Credentials never committed to git or shared via Slack      │
│     → Store in secure password manager (1Password, LastPass)    │
│     → Keep backup in secure vault                               │
│                                                                  │
│  3. Types of credentials generated:                             │
│     - PUBLISH_USER / PUBLISH_PASS (RTMP publishing)             │
│     - API_VIEWER_USER / API_VIEWER_PASS (MediaMTX API access)   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Phase 2: Environment Configuration

Credentials are injected via environment files (`.env.local`), which are **never committed** to git.

#### Local Development (`.env.local`)
```bash
# .env.local - LOCAL MACHINE ONLY (in .gitignore)
PUBLISH_USER=publish
PUBLISH_PASS=<strong-random-password>
API_VIEWER_USER=apiviewer
API_VIEWER_PASS=<strong-random-password>
```

#### Staging/Production Deployment
```bash
# Via CI/CD secrets or deployment configuration
# NOT committed to repository
# Injected at runtime via:
# - GitHub Secrets (CI/CD)
# - Docker environment variables
# - Kubernetes secrets
# - Cloud deployment systems
```

### Phase 3: Runtime Loading

Credentials are loaded from environment at startup and stored in secure locations.

```
┌──────────────────────────────────────┐
│   STREAMING SERVER (Docker)          │
├──────────────────────────────────────┤
│                                      │
│  1. Startup reads .env variables:    │
│     ├─ PUBLISH_USER                  │
│     ├─ PUBLISH_PASS                  │
│     ├─ API_VIEWER_USER               │
│     └─ API_VIEWER_PASS               │
│                                      │
│  2. Injected into mediamtx.yml:      │
│     ├─ authInternalUsers (RTMP)     │
│     ├─ API authentication            │
│     └─ Access control rules          │
│                                      │
│  3. Credentials kept in memory only  │
│     (NOT logged or exposed)          │
│                                      │
└──────────────────────────────────────┘


┌──────────────────────────────────────┐
│   iOS APP (SwiftUI)                  │
├──────────────────────────────────────┤
│                                      │
│  1. App requires API credentials:    │
│     ├─ API_VIEWER_USER               │
│     └─ API_VIEWER_PASS               │
│                                      │
│  2. Fetch from Keychain at startup   │
│     (if not available, prompt user)  │
│                                      │
│  3. Store securely in Keychain       │
│     (encrypted by OS)                │
│                                      │
│  4. Never logged or hardcoded        │
│                                      │
└──────────────────────────────────────┘
```

### Phase 4: Secure Storage

#### Server-Side (MediaMTX in Docker)
- **Storage:** Environment variables loaded at container startup
- **Lifetime:** In-memory during runtime
- **Access:** Only MediaMTX process has access
- **Rotation:** Restart container with new env vars

#### iOS App (SwiftUI)
- **Storage:** Keychain (iOS's secure encrypted storage)
- **Lifetime:** Persists across app launches
- **Access:** Only by this app (OS enforces)
- **Rotation:** App re-prompts user if credentials invalid, stores new ones

---

## Credential Classification

### Type 1: Environment-Only Credentials (Server-Side)
These MUST be loaded from environment, never hardcoded:

| Credential | Purpose | Where Used | Hardcoded Default? |
|------------|---------|------------|-------------------|
| `PUBLISH_USER` | RTMP stream publishing auth | mediamtx.yml | ❌ NO - Must be env |
| `PUBLISH_PASS` | RTMP stream publishing auth | mediamtx.yml | ❌ NO - Must be env |
| `API_VIEWER_USER` | MediaMTX API access | mediamtx.yml | ❌ NO - Must be env |
| `API_VIEWER_PASS` | MediaMTX API access | mediamtx.yml | ❌ NO - Must be env |

### Type 2: App-Side Credentials (iOS)
These are user-specific or fetched from Keychain:

| Credential | Purpose | Where Stored | How |
|------------|---------|-------------|-----|
| `API_VIEWER_USER` | Query MediaMTX API | Keychain | Fetched from server/Keychain |
| `API_VIEWER_PASS` | Query MediaMTX API | Keychain | Fetched from server/Keychain |

### Type 3: Non-Sensitive Configuration
These CAN be hardcoded (safe defaults):

| Setting | Purpose | Hardcoded Value |
|---------|---------|-----------------|
| `SERVER_IP` | Bind address | `0.0.0.0` |
| `RTMP_PORT` | Publishing port | `1935` |
| `HLS_PORT` | Playback port | `8888` |
| `RTSP_PORT` | RTSP playback | `8554` |
| `HLS_SEGMENT_DURATION` | Buffer time | `2s` |
| `LOGLEVEL` | Debug level | `info` |

---

## Implementation Guidelines

### For Streaming Server (Docker)

**✅ DO:**
```yaml
# mediamtx.yml - Load credentials from environment
authInternalUsers:
  - user: ${PUBLISH_USER}
    password: ${PUBLISH_PASS}
    permissions:
      - action: publish
  - user: ${API_VIEWER_USER}
    password: ${API_VIEWER_PASS}
    permissions:
      - action: read
      - action: playback
```

**❌ DON'T:**
```yaml
# mediamtx.yml - Hardcoded credentials
authInternalUsers:
  - user: "publish"
    password: "streampass123"  # NEVER hardcode!
```

### For iOS App

**✅ DO:**
```swift
// Fetch credentials from Keychain
let credentials = KeychainManager.shared.load(service: "MediaMTX")
let apiClient = MediaMTXAPIClient(
    baseURL: streamBaseURL,
    username: credentials.username,
    password: credentials.password
)
```

**❌ DON'T:**
```swift
// Hardcoded credentials
enum MediaMTXConfig {
    static let apiUsername = "apiviewer"
    static let apiPassword = "changeme123"  // NEVER hardcode!
}
```

### For Testing Scripts

**✅ DO:**
```bash
#!/bin/bash
source .env.local  # Load from local env file

# Use environment variables
RTMP_URL="rtmp://${PUBLISH_USER}:${PUBLISH_PASS}@localhost:1935/live/mystream"
HLS_URL="http://localhost:8888/live/mystream/index.m3u8"
```

**❌ DON'T:**
```bash
#!/bin/bash
# Hardcoded credentials in script
RTMP_URL="rtmp://publish:streampass123@localhost:1935/live/mystream"
RTSP_URL="rtsp://publish:streampass123@localhost:8554/live/mystream"
```

---

## Environment File Checklist

### .env.example (Committed to git)
Contains **placeholders only** - no real credentials:

```bash
# Publishing credentials (REQUIRED)
PUBLISH_USER=publish
PUBLISH_PASS=<generate-strong-password>

# API access (REQUIRED)  
API_VIEWER_USER=apiviewer
API_VIEWER_PASS=<generate-strong-password>

# Optional settings
SERVER_IP=0.0.0.0
RTMP_PORT=1935
HLS_PORT=8888
```

### .env.local (Never committed - in .gitignore)
Contains **real credentials** for this machine:

```bash
# Copy from .env.example and customize
PUBLISH_USER=publish
PUBLISH_PASS=actual-strong-password-here

API_VIEWER_USER=apiviewer
API_VIEWER_PASS=actual-strong-password-here

SERVER_IP=127.0.0.1
RTMP_PORT=1935
HLS_PORT=8888
```

### .env.production (Never committed - injected at deploy)
For production deployment via CI/CD:

```bash
# Set as GitHub Secrets or in deployment pipeline
# Never committed to repository
# Example GitHub Actions:
# - uses: docker/build-push-action@v2
#   env:
#     PUBLISH_USER: ${{ secrets.PROD_PUBLISH_USER }}
#     PUBLISH_PASS: ${{ secrets.PROD_PUBLISH_PASS }}
```

---

## Validation

### .gitignore Entries (Already Added)
Ensure these patterns prevent credential leaks:

```gitignore
# Environment files with sensitive data
.env
.env.local
.env.*.local
.env.production
.env.production.local
.env.*.production
*.env.private
```

### Pre-Commit Validation
Before committing, verify:

```bash
# ✅ Check: No .env files committed
git status | grep -E "\.env"

# ✅ Check: No hardcoded credentials in code
git diff --cached | grep -iE "password|secret|key|token" | grep -v "#"

# ✅ Check: .env.example has only placeholders
grep -E "streampass123|changeme123|actual-" .env.example && echo "ERROR: Real credentials in .env.example!" || echo "OK"
```

---

## Summary Table

| Phase | Storage | Location | Secure? | Committed? | Rotatable? |
|-------|---------|----------|---------|-----------|-----------|
| Generation | Password Manager | 1Password/LastPass | ✅ Yes | ❌ No | ✅ Yes |
| Configuration | .env files | Docker/Local | ⚠️ Local only | ❌ No (.local) | ✅ Yes |
| Runtime (Server) | Memory | Docker process | ✅ Yes | N/A | ✅ Yes (restart) |
| Runtime (iOS) | Keychain | Encrypted | ✅ Yes | N/A | ✅ Yes (re-auth) |

---

## Related Issues

- [[#8]] - Implement Keychain-based credential storage
- [[#9]] - Update mediamtx.yml to require RTMP authentication  
- [[#10]] - Remove hardcoded API credentials from MediaMTXConfig
- [[#11]] - Remove hardcoded credentials from test-streaming.sh
