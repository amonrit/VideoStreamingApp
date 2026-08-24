Last Modified: 08/24/2026 (1787587709) by amonrit

# Keychain Setup for iOS App

This document explains how Keychain works in the Steam iOS app and how to configure it for development and testing.

---

## Overview

The Steam iOS app uses **iOS Keychain** to securely store MediaMTX API credentials. This replaces the old hardcoded credentials approach (see [Issue #17](https://github.com/amonrit/VideoStreamingApp/issues/17)).

**Storage Hierarchy:**
1. **Primary:** iOS Keychain (encrypted by OS)
2. **Fallback:** Environment variables (for testing/CI)
3. **Never:** Hardcoded values in source code

---

## iOS Simulator Support

iOS Simulator has **full Keychain support** since iOS 13. No special configuration is required for basic Keychain operations.

### Simulator Keychain Storage

When you run the app on iOS Simulator:
- Keychain data is stored in the simulator's sandboxed filesystem
- Location: `~/Library/Developer/CoreSimulator/Devices/<DEVICE_ID>/data/Library/Keychains/`
- Data persists across simulator sessions (until you reset the simulator)
- Each simulator device has its own isolated Keychain

### Reset Simulator Keychain

If you need to clear all Keychain data for testing:

```bash
# Option 1: Reset the entire simulator (clears all app data + Keychain)
xcrun simctl erase <DEVICE_ID>

# Option 2: Just delete the app (keeps Keychain data)
xcrun simctl uninstall <DEVICE_ID> com.amonrit.steam

# Option 3: Interactive reset in Xcode
# Menu: Simulator → Device → Erase All Content and Settings...
```

---

## Entitlements Configuration

The app requires Keychain access group entitlements. This is configured in:

**File:** `steam/steam.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.amonrit.steam</string>
	</array>
</dict>
</plist>
```

**What this does:**
- Allows the app to access Keychain items with the service identifier `com.amonrit.steam`
- `$(AppIdentifierPrefix)` automatically expands to the team ID in signed builds
- No additional configuration needed for simulator builds

---

## Setting Up Credentials

### For Development (First Time)

When the app first runs, it needs credentials. There are two ways to provide them:

#### Option 1: Environment Variables (Recommended for Testing)

Set environment variables before running the app:

```bash
export API_VIEWER_USER="apiviewer"
export API_VIEWER_PASS="your-secure-password"

# Then build and run
xcodebuild build -project steam.xcodeproj -scheme steam \
  -destination "generic/platform=iOS Simulator"
```

The app will:
1. Try to load from Keychain (fails on first run)
2. Fall back to environment variables
3. Cache and use those credentials

#### Option 2: Store via Code (Development Only)

If you're testing credential storage directly, use the API:

```swift
import Foundation

// In your app setup code or a settings screen:
try await MediaMTXConfig.storeCredentials(
    username: "apiviewer",
    password: "your-secure-password"
)
```

Note: `KeychainManager` is an `actor` and `MediaMTXConfig`'s credential methods are all
`async` — every call above (`storeCredentials`, `clearCredentials`, `apiUsername`,
`apiPassword`, `hasStoredCredentials`) needs `await`.

### For Production

In production/release builds:
1. User provides credentials via app UI (Settings screen)
2. App securely stores them in Keychain using `MediaMTXConfig.storeCredentials()`
3. App loads them automatically on subsequent launches via `MediaMTXConfig.apiUsername` and `MediaMTXConfig.apiPassword`

---

## Testing Keychain Operations

### Unit Tests

Run the Keychain manager tests:

```bash
xcodebuild test-without-building -project steam.xcodeproj \
  -scheme steam \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

Tests are in: `steamTests/Managers/KeychainManagerTests.swift`

Coverage:
- ✅ Save/load credentials
- ✅ Environment variable fallback
- ✅ Delete credentials
- ✅ Special characters handling
- ✅ Credential overwrites

### Integration Tests

Security integration tests verify hardcoded credentials are NOT in the compiled binary:

```bash
xcodebuild build-for-testing -project steam.xcodeproj -scheme steam

xcodebuild test-without-building -project steam.xcodeproj \
  -scheme steam \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

Tests are in: `steamTests/Integration/CredentialSecurityTests.swift`

Coverage:
- ✅ Hardcoded "changeme123" password not in binary
- ✅ Hardcoded credential patterns not in binary
- ✅ Runtime uses dynamic credentials from environment/Keychain

---

## Troubleshooting

### Problem: "Keychain error: saveFailed(-25299)"

**Cause:** Keychain is not accessible in the simulator.

**Solution:**
```bash
# Reset simulator and try again
xcrun simctl erase all

# Or just reset this device
xcrun simctl erase <DEVICE_ID>
```

### Problem: Credentials not persisting across app launches

**Cause:** Environment variables only exist during the build session.

**Solution:**
1. Use Option 2 above (store via code) to save to Keychain
2. Or set environment variables in Xcode scheme:
   - Xcode → Schemes → Edit Scheme
   - Run → Pre-Actions → Add script to export variables
   - Example:
     ```bash
     export API_VIEWER_USER=apiviewer
     export API_VIEWER_PASS=secure-pass
     ```

### Problem: "Cannot find type 'KeychainManager' in scope"

**Cause:** KeychainManager file not included in build target.

**Solution:**
```bash
# Clean and rebuild
xcodebuild clean -project steam.xcodeproj -scheme steam
xcodebuild build -project steam.xcodeproj -scheme steam \
  -destination "generic/platform=iOS Simulator"
```

---

## Security Notes

1. **Environment variables are not secure** — use them for testing only
2. **Keychain is encrypted by iOS** — use for production credentials
3. **Never commit `.env.local` or credential files** — already in `.gitignore`
4. **Credential rotation** — call `MediaMTXConfig.clearCredentials()` then `storeCredentials()` again

---

## Related Files

- `steam/Core/Managers/KeychainManager.swift` — Main Keychain implementation (actor)
- `steam/Features/StreamAdmin/Domain/MediaMTXConfig.swift` — Uses Keychain for API credentials
- `steam/steam.entitlements` — Keychain access group configuration
- `steamTests/Managers/KeychainManagerTests.swift` — Unit tests
- `steamTests/Integration/CredentialSecurityTests.swift` — Security tests
- `docs/CREDENTIAL_MANAGEMENT.md` — Full credential lifecycle strategy

---

## References

- [iOS Keychain Documentation](https://developer.apple.com/documentation/security/keychain_services)
- [Simulator Keychain Support](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/KeychainSupport/KeychainSupport.html)
- Issue #15: [Implement Keychain-based credential storage](https://github.com/amonrit/VideoStreamingApp/issues/15)
- Issue #17: [Remove hardcoded API credentials](https://github.com/amonrit/VideoStreamingApp/issues/17)
