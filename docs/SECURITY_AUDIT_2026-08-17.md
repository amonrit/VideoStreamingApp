Last Modified: 08/24/2026 (1787587709) by amonrit

# Steam Project - Security Audit Findings

**Audit Date:** 2026-08-17  
**Scope:** iOS App (Swift/SwiftUI) + Streaming Server (Docker/MediaMTX/FFmpeg)  
**Auditor:** Security Review Agent

> **08/24/2026 update:** This is a point-in-time audit; the codebase has moved since it was
> written (file paths reorganized into `Features/`/`Core/`, `KeychainManager` became an actor).
> Paths below were updated to match the current tree, and findings #1, #4, #5, and #6 have been
> re-checked against the current code and are now marked **RESOLVED** with what actually changed.
> Findings #2, #3, #7, #8, and #10 were spot-checked and are still open as described. This pass
> did not re-run a full audit (no new exploit testing, no re-scoring) — treat the still-open
> items as accurate but schedule a proper follow-up audit before relying on this list as
> current.

---

## Executive Summary

The original audit found **4 CRITICAL** and **3 HIGH** severity issues. As of the 08/24/2026
re-check: the two credential-hardcoding findings (#1, #4), the missing `.gitignore` entries
(#5), and the unsafe URL encoding (#6) are **fixed**. Still open: unauthenticated publishing
(#2), permissive CORS (#3), no certificate pinning (#7), Basic auth without HTTPS enforcement
(#8), and the exposed metrics port (#10).

**Risk Assessment:** MEDIUM — the credential-in-source-code risk is gone, but the streaming
server itself still accepts unauthenticated publishing and unrestricted CORS on its control API.

---

## Critical Findings

### 1. HARDCODED CREDENTIALS IN IOS APP SOURCE CODE ✅ FIXED
**File:** `/steam/Features/StreamAdmin/Domain/MediaMTXConfig.swift`  
**Severity:** CRITICAL  
**Category:** Hardcoded Secrets / Information Disclosure  
**Confidence:** 10/10  
**Status:** RESOLVED

**Original Vulnerability:**
```swift
// Lines 11-12
static let apiUsername = "apiviewer"
static let apiPassword = "changeme123"  // Keep in sync with streaming/.env API_VIEWER_PASS
```

**Fix Implemented:** `apiUsername`/`apiPassword` are now `async` computed properties that
load from `KeychainManager` (an actor), falling back to `API_VIEWER_USER`/`API_VIEWER_PASS`
environment variables only if nothing is in the Keychain. No credential value is compiled
into the binary. See `docs/KEYCHAIN_SETUP.md` and `docs/CREDENTIAL_MANAGEMENT.md`.

**Description:**
Hardcoded credentials are embedded directly in Swift source code. These credentials are:
- Compiled into the iOS app binary
- Visible in decompiled/disassembled app code
- Cannot be rotated without re-releasing the app
- Identical across all deployed instances

**Exploit Scenario:**
1. Attacker downloads the iOS app from App Store
2. Uses commercial/open-source iOS app decompiler (e.g., Ghidra, IDA Pro)
3. Extracts hardcoded credentials: `apiviewer:changeme123`
4. Uses Basic auth credentials to query MediaMTX API v3 endpoints
5. Discovers all active streams, viewer counts, and server status
6. Performs reconnaissance for further attacks

**Recommendation:**
- Remove hardcoded credentials from source code immediately
- Implement credential storage via Keychain for sensitive data
- Use environment-specific configuration (dev/staging/production)
- Consider certificate-based or OAuth2 authentication
- If app needs to know server details, fetch them dynamically from secure endpoint
- Rotate the exposed `apiviewer` password immediately in production

---

### 2. UNAUTHENTICATED STREAM PUBLISHING
**File:** `/streaming/mediamtx.yml`  
**Severity:** CRITICAL  
**Category:** Authentication Bypass / Authorization Failure  
**Confidence:** 10/10  

**Vulnerability:**
```yaml
# Lines 13-19
authInternalUsers:
  - user: any
    permissions:
      - action: publish
      - action: read
      - action: playback
```

**Description:**
MediaMTX is configured to accept stream publishing from ANY user without requiring authentication. The "any" user with no password can:
- Publish streams to any path
- Read metadata of any stream
- Playback any stream

**Exploit Scenario:**
1. Attacker discovers the streaming server (via network scanning or error messages)
2. Connects to RTMP (port 1935), RTSP (port 8554), or other publishing endpoints
3. Publishes malicious content without any authentication:
   ```bash
   ffmpeg -i malware.mp4 -c copy -f flv rtmp://target-server:1935/live/important_stream
   ```
4. Disrupts legitimate streams by publishing to the same paths
5. Performs stream hijacking and content injection attacks
6. Broadcasts spam, malware links, or inappropriate content

**Recommendation:**
- Require authentication for RTMP publishing by default
- Configure `authInternalUsers` to require username/password for publish action
- Remove the "any" user with publish permission
- Implement per-stream access control policies
- Use environment variables to load credentials securely
- Monitor and log all publishing attempts

---

### 3. OVERLY PERMISSIVE CORS CONFIGURATION
**File:** `/streaming/mediamtx.yml`  
**Severity:** CRITICAL  
**Category:** CORS Misconfiguration / Cross-Origin Attack  
**Confidence:** 10/10  

**Vulnerability:**
```yaml
# Line 10
apiAllowOrigins: ["*"]
```

**Description:**
The MediaMTX Control API allows CORS requests from ANY origin. This enables:
- Cross-site request forgery (CSRF) attacks
- JavaScript from malicious websites to interact with the API
- Credential exposure through browser cross-origin requests
- Bypassing security policies that depend on origin validation

**Exploit Scenario:**
1. Victim visits attacker's website (attacker.com)
2. JavaScript embedded in the page makes requests to `http://192.168.1.50:9997/v3/paths/list`
3. MediaMTX responds with CORS headers `Access-Control-Allow-Origin: *`
4. Browser allows the response; victim's credentials (if authenticated) are sent
5. Attacker's JavaScript harvests:
   - List of all active streams
   - Viewer counts for each stream
   - Stream metadata
   - Server configuration details
6. Attacker uses this information for:
   - Targeting specific streams with attacks
   - Understanding server architecture
   - Social engineering based on stream names
   - Stream hijacking attacks

**Recommendation:**
- Restrict CORS to specific trusted origins:
  ```yaml
  apiAllowOrigins: ["https://yourdomain.com", "https://app.yourdomain.com"]
  ```
- If public access needed, require authentication tokens
- Implement API rate limiting per origin
- Add CSRF tokens for state-changing operations
- Consider disabling the public API endpoint entirely if not needed

---

### 4. HARDCODED CREDENTIALS IN SHELL SCRIPTS ✅ FIXED
**File:** `/streaming/test-streaming.sh`  
**Severity:** CRITICAL  
**Category:** Hardcoded Secrets in Source Control  
**Confidence:** 10/10  
**Status:** RESOLVED

**Original Vulnerability:**
```bash
# Lines 21-23
RTMP_URL="rtmp://publish:streampass123@localhost:1935/live/mystream"
HLS_URL="http://localhost:8888/live/mystream/index.m3u8"
RTSP_URL="rtsp://publish:streampass123@localhost:8554/live/mystream"
```

**Fix Implemented:** The script now reads `$PUBLISH_USER`/`$PUBLISH_PASS` from `.env.local`
and fails with an error if they're unset, instead of embedding a default password.

**Description:**
Test script contains hardcoded default credentials that are:
- Checked into version control (visible in git history)
- Printed to console output and logs (lines 182, 191, 202)
- Used verbatim in documentation and examples
- Shared across development team
- Potentially captured in CI/CD logs

**Exploit Scenario:**
1. Attacker clones the public/private GitHub repository
2. Views `git log` or script files to find credentials
3. Searches git history for all instances of "streampass123"
4. Finds hardcoded password: `publish:streampass123`
5. Attempts to use these credentials against production servers:
   ```bash
   ffmpeg -i malware.mp4 -c copy -f flv rtmp://publish:streampass123@prod-server:1935/live/mystream
   ```
6. If production uses same defaults, stream publishing succeeds
7. If not, attacker now knows the username and can attempt password attacks

**Recommendation:**
- Remove all hardcoded credentials from test scripts
- Use environment variables for sensitive values:
  ```bash
  RTMP_URL="rtmp://${PUBLISH_USER}:${PUBLISH_PASS}@localhost:1935/live/mystream"
  ```
- Create `.env.example` with placeholder values (already done, but test-streaming.sh violates this)
- Add all `*.env*` and `.env.local` files to `.gitignore`
- Clean git history if credentials were exposed:
  ```bash
  git filter-branch --tree-filter 'sed -i "s/streampass123/REDACTED/g"' -- --all
  ```
- Rotate `publish` user password immediately

---

## High Severity Findings

### 5. MISSING .ENV FILES IN GITIGNORE ✅ FIXED
**File:** `/.gitignore`  
**Severity:** HIGH  
**Category:** Configuration Error / Credential Exposure Risk  
**Confidence:** 10/10  
**Status:** RESOLVED

**Original Vulnerability:**
The `.gitignore` file did not exclude `.env` files, which frequently contain sensitive credentials.

**Fix Implemented:** `.gitignore` now includes `.env`, `.env.local`, `.env.*.local`,
`.env.production`, `.env.development`, `.env.test`, and `*.env.private`.

**Exploit Scenario:**
1. Developer accidentally creates `.env.local` with real production credentials
2. Developer forgets to remove it before committing
3. Credentials are committed to version control
4. Even if developer discovers the mistake and deletes the file, git history still contains it
5. Attacker can recover credentials from git history:
   ```bash
   git log -p -- .env.local
   ```

**Recommendation:**
Add to `.gitignore`:
```
# Environment files with secrets
.env
.env.*.local
.env.local
.env.production
*.env.private
```

---

### 6. UNSAFE URL PARAMETER ENCODING IN API CLIENT ✅ FIXED
**File:** `/steam/Core/Networking/MediaMTXAPIClient.swift`  
**Severity:** HIGH  
**Category:** Path Traversal / URL Injection  
**Confidence:** 7/10  
**Status:** RESOLVED

**Original Vulnerability:**
```swift
// Line 64
let url = baseURL.appendingPathComponent("v3/paths/get/\(pathName)")
```

**Fix Implemented:** `pathName` is now passed through a dedicated `encodePathComponent`
helper (`addingPercentEncoding(withAllowedCharacters:)`) before being interpolated into the
path, matching the recommendation below.

**Description:**
The `pathName` parameter is interpolated directly into a URL path component string. While `appendingPathComponent` does provide some encoding, the pattern allows potential issues:

1. Special characters in pathName may not be properly URL-encoded
2. Path traversal sequences (e.g., `../../../v1/admin`) could potentially escape the intended path
3. Double URL-encoding issues could occur

While Swift's `appendingPathComponent` is more robust than many approaches, this pattern is still problematic because:
- The pathName is embedded in a string before appendingPathComponent processes it
- Any special characters already in the string aren't guaranteed to be encoded

**Exploit Scenario (Theoretical):**
1. App receives a crafted stream URL with special characters in the path
2. Attacker controls the pathName parameter through the HLS URL parsing
3. Passes pathName like: `live/mystream%00admin` (null byte injection)
4. API client constructs URL that bypasses intended path restrictions
5. Attacker gains access to admin endpoints or different paths

**Recommendation:**
Properly encode path parameters using URLComponents:
```swift
var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
urlComponents.path = "/v3/paths/get/\(pathName)"
let url = urlComponents.url!
```

Or use proper URL encoding:
```swift
let encodedPathName = pathName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pathName
let url = baseURL.appendingPathComponent("v3/paths/get/\(encodedPathName)")
```

---

### 7. NO CERTIFICATE PINNING OR CUSTOM TLS VALIDATION
**File:** `/steam/Core/Networking/MediaMTXAPIClient.swift`  
**Severity:** MEDIUM/HIGH (context-dependent)  
**Category:** Man-in-the-Middle (MITM) Vulnerability  
**Confidence:** 8/10  

**Vulnerability:**
```swift
// Lines 30-35
private let session: URLSession

init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
}
```

**Description:**
The app uses standard URLSession without any custom certificate validation, pinning, or delegate implementation. This leaves the app vulnerable to MITM attacks if:

1. Attacker is on the same local network (WiFi)
2. Network administrator intercepts HTTPS
3. Compromised DNS redirects to attacker's server
4. Corporate proxy intercepts HTTPS

**Impact:**
- Attacker can intercept API calls to MediaMTX
- Credentials sent in Basic auth header can be captured
- Stream metadata and viewer counts can be snooped
- API responses can be modified to cause app malfunction

**Exploit Scenario:**
1. Victim connects to public WiFi
2. Attacker runs MITM proxy (e.g., mitmproxy) on network
3. Attacker intercepts HTTPS request to `http://192.168.1.50:9997/v3/paths/list`
4. Attacker captures Basic auth header: `Authorization: Basic YXBpdmlld2VyOmNoYW5nZW1lMTIz`
5. Attacker decodes Base64 to get credentials: `apiviewer:changeme123`
6. Credentials remain valid across app sessions and devices

**Recommendation:**
- Implement certificate pinning for production APIs
- Create a custom URLSessionDelegate with certificate validation
- Require HTTPS for all API communication (not HTTP)
- For local network APIs, use self-signed certificates with pinning
- Consider implementing public key pinning (HPKP)

Example implementation:
```swift
class SecureURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, 
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Implement certificate pinning here
        // Validate against known certificate hashes
    }
}
```

---

## Medium Severity Findings

### 8. BASIC AUTH CREDENTIALS TRANSMITTED WITHOUT SUFFICIENT VALIDATION
**File:** `/steam/Features/StreamAdmin/Domain/MediaMTXConfig.swift`  
**Severity:** MEDIUM  
**Category:** Authentication Weakness  
**Confidence:** 8/10  

**Vulnerability:**
```swift
// Lines 15-20
static var authHeaderValue: String {
    let raw = "\(apiUsername):\(apiPassword)"
    let data = Data(raw.utf8)
    let encoded = data.base64EncodedString()
    return "Basic \(encoded)"
}
```

**Description:**
Basic authentication encodes (but does not encrypt) credentials. The credentials are visible to anyone intercepting HTTP traffic or inspecting network logs. Combined with the lack of HTTPS enforcement, this is particularly risky.

**Recommendation:**
- Enforce HTTPS for all API communication
- Transition to OAuth2 or Bearer token authentication
- Implement token refresh mechanisms
- Never use Basic auth for sensitive operations
- Add request signing/HMAC for additional security

---

### 9. NO INPUT VALIDATION ON CUSTOM STREAM URLS ✅ FIXED
**File:** `/steam/Features/Playback/Presentation/VideoStreamListView.swift`  
**Severity:** MEDIUM  
**Category:** Weak Input Validation  
**Confidence:** 6/10  
**Status:** RESOLVED (Issue #14)

**Original Vulnerability:**
```swift
// Lines 284-298
var isValidURL: Bool {
    guard !customURL.isEmpty else { return false }
    let isValidProtocol = customURL.starts(with: "http://") ||
                         customURL.starts(with: "https://") ||
                         customURL.starts(with: "rtmp://")

    if !isValidProtocol { return false }

    // For HLS, must end with .m3u8
    if customURL.contains("http") {
        return customURL.hasSuffix(".m3u8")
    }

    return true
}
```

**Description:**
The original validation only checked for protocol prefix and file extension, but didn't validate:
- Hostname/IP legitimacy
- URL encoding attacks
- Malicious URL parameters
- Redirects to untrusted servers

**Fix Implementation (Issue #14):**

Created comprehensive URL validation system with three components:

1. **URLValidator Service** (`steam/Core/Utils/URLValidator.swift`)
   - Domain whitelist validation against trusted sources:
     - `devstreaming-cdn.apple.com` (official Apple test streams)
     - `localhost` and `127.0.0.1` (local development)
   - HTTPS enforcement for HTTP(S) URLs
   - RTMP support only from whitelisted domains
   - User-friendly error messages

2. **URLValidationLogger Service** (`steam/Core/Utils/URLValidationLogger.swift`)
   - Logs all custom URLs with ISO 8601 timestamps
   - Thread-safe concurrent logging
   - Maintains audit trail in `url-validation-logs.txt`
   - Supports log retrieval and clearing

3. **Enhanced AddStreamSheet UI** (`steam/Features/Playback/Presentation/VideoStreamListView.swift`)
   - Integrated URLValidator for strict whitelist checking
   - Real-time HTTPS warning when users enter HTTP URLs
   - Visual warning indicator (orange banner)
   - Prevents adding non-whitelisted URLs

**Testing:**
- `steamTests/Services/URLValidatorTests.swift` — 20+ test cases
- `steamTests/Services/URLValidationLoggerTests.swift` — 10+ test cases
- `steamTests/Integration/URLWhitelistIntegrationTests.swift` — End-to-end tests

**Example Valid URLs (Whitelisted):**
```
✅ https://devstreaming-cdn.apple.com/videos/example.m3u8
✅ https://localhost:8888/live/stream.m3u8
✅ https://127.0.0.1:8888/live/stream.m3u8
```

**Example Invalid URLs (Rejected):**
```
❌ https://malicious.com/stream.m3u8 (domain not whitelisted)
❌ http://localhost:8888/stream.m3u8 (HTTP instead of HTTPS)
❌ rtmp://attacker.com/live/stream (domain not whitelisted)
```

---

### 10. EXPOSED METRICS/ADMIN ENDPOINTS
**File:** `/streaming/docker-compose.yml` and `/streaming/mediamtx.yml`  
**Severity:** MEDIUM  
**Category:** Information Disclosure  
**Confidence:** 7/10  

**Vulnerability:**
```yaml
# docker-compose.yml line 49
- "9997:9997"  # Metrics (Prometheus)

# mediamtx.yml lines 8-10
api: true
apiAddress: :9997
apiAllowOrigins: ["*"]
```

**Description:**
The MediaMTX admin/metrics endpoint (port 9997) is exposed to the network without authentication. This allows anyone on the network to:
- Query stream information
- Get viewer counts
- Monitor server metrics
- Understand server capacity and load

**Exploit Scenario:**
1. Attacker scans network for open ports
2. Discovers port 9997 responding to HTTP requests
3. Queries `http://target:9997/v3/paths/list` to enumerate all streams
4. Discovers important/sensitive streams
5. Uses this information for targeted attacks
6. Monitors metrics to understand server usage patterns

**Recommendation:**
- Restrict port 9997 to localhost or trusted networks only
- Require authentication for API access
- Use firewall rules to limit access
- Consider not exposing metrics endpoint publicly
- Implement API authentication with strong credentials

---

## Summary Table

| # | Finding | Severity | File | Confidence | Status (as of 08/24/2026) |
|---|---------|----------|------|------------|--------|
| 1 | Hardcoded credentials in iOS source | CRITICAL | MediaMTXConfig.swift | 10/10 | ✅ RESOLVED |
| 2 | Unauthenticated stream publishing | CRITICAL | mediamtx.yml | 10/10 | ❌ OPEN |
| 3 | CORS allows all origins | CRITICAL | mediamtx.yml | 10/10 | ❌ OPEN |
| 4 | Hardcoded credentials in shell scripts | CRITICAL | test-streaming.sh | 10/10 | ✅ RESOLVED |
| 5 | .env files not in gitignore | HIGH | .gitignore | 10/10 | ✅ RESOLVED |
| 6 | Unsafe URL parameter encoding | HIGH | MediaMTXAPIClient.swift | 7/10 | ✅ RESOLVED |
| 7 | No certificate pinning | MEDIUM/HIGH | MediaMTXAPIClient.swift | 8/10 | ❌ OPEN |
| 8 | Basic auth without HTTPS validation | MEDIUM | MediaMTXConfig.swift | 8/10 | ⚠️ PARTIAL (credential is no longer hardcoded, but Basic-auth-over-HTTP itself is unchanged) |
| 9 | Weak input validation on URLs | MEDIUM | VideoStreamListView.swift | 6/10 | ✅ RESOLVED (already marked fixed in original audit) |
| 10 | Exposed admin endpoints | MEDIUM | docker-compose.yml | 7/10 | ❌ OPEN |

---

## Immediate Actions Required

*(Original priority list below, left as written for historical context. Items already
resolved are struck through with what shipped instead; everything else is still outstanding.)*

### Priority 1 (Do Today)
1. ~~Rotate the exposed credentials~~ — superseded by moving to Keychain-backed credentials (finding #1)
2. ~~Remove hardcoded credentials from source~~ — done for both MediaMTXConfig.swift (#1) and test-streaming.sh (#4)
3. **Still open — fix CORS and authentication:**
   - Remove `apiAllowOrigins: ["*"]` from mediamtx.yml
   - Add authentication requirement for RTMP publishing
   - Restrict API access to authenticated users only

### Priority 2 (This Week)
1. ~~Add `.env*` files to .gitignore~~ — done (finding #5)
2. ~~Implement proper credential management (Keychain, environment variables)~~ — done (finding #1)
3. **Still open:** Add certificate pinning to iOS app (finding #7)
4. ~~Implement URL whitelist for custom stream URLs~~ — done (finding #9)
5. **Still open:** Restrict port 9997 access (finding #10)

### Priority 3 (This Sprint)
1. **Still open:** Transition from Basic auth to OAuth2/Bearer tokens
2. **Still open:** Enforce HTTPS for all API communication
3. Implement comprehensive input validation — partially done via `URLValidator` (finding #9); extend as new input surfaces appear
4. **Still open:** Add security logging and monitoring
5. **Still open:** Conduct a fresh penetration test / follow-up audit covering findings #2, #3, #7, #8, #10

---

## Testing Recommendations

1. **Credential Scanning:**
   ```bash
   git log -S "streampass123" -S "changeme123" -p
   ```

2. **Network Security:**
   - Test CORS with curl from different origins
   - Verify API requires authentication
   - Check if ports can be accessed from external networks

3. **Input Validation:**
   - Test with path traversal sequences: `../../../`
   - Test with special characters in stream URLs
   - Test with malformed URLs

4. **Certificate Pinning:**
   - Implement certificate pinning test
   - Verify MITM protection works

---

## Compliance Notes

These vulnerabilities may violate:
- **OWASP Top 10:** A01:2021 Broken Access Control, A02:2021 Cryptographic Failures
- **CWE:** CWE-798 (Hardcoded Credentials), CWE-276 (Incorrect Default Permissions)
- **SANS Top 25:** CWE-327 (Weak Cryptography)

---

## Next Steps

1. Review this audit with development team
2. Create tickets for all HIGH and CRITICAL issues
3. Assign owners and due dates
4. Schedule follow-up security audit after fixes
5. Implement security review process for future changes
