# 🔐 Android Build & Code Signing Guide

## Overview

MediCore Android app uses secure code signing to protect against APK tampering and ensure app authenticity on Google Play Store.

**Critical Rules**:
- ⚠️ **NEVER** commit signing credentials to Git
- ⚠️ **NEVER** hardcode passwords in build.gradle
- ⚠️ Store keystore file securely (encrypted backup, offline)
- ⚠️ Different keystores for dev/staging/production (recommended)
- ⚠️ Rotate signing key annually for production apps

---

## Local Development Setup

### 1. Generate Signing Keystore (One-time)

```bash
cd android/app

# Generate a new 2048-bit RSA keystore
# Valid for 10,000 days (~27 years)
keytool -genkey -v -keystore release.keystore \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias medicore_key \
  -storepass "your-secure-keystore-password" \
  -keypass "your-secure-key-password"

# When prompted:
# First and last name: Your Name / Organization Name
# Organizational unit: Engineering
# Organization: MediCore
# City/Locality: Your City
# State/Province: Your State
# Country code: US (or your country)
# Is this correct? Yes
```

**Output**: Creates `android/app/release.keystore`

### 2. Configure Local Properties

```bash
# Copy template from repo root
cp android/local.properties.example android/local.properties

# Edit with your keystore details
nano android/local.properties
```

**File Contents** (`android/local.properties`):
```properties
MEDICORE_RELEASE_STORE_FILE=release.keystore
MEDICORE_RELEASE_STORE_PASSWORD=your-secure-keystore-password
MEDICORE_RELEASE_KEY_ALIAS=medicore_key
MEDICORE_RELEASE_KEY_PASSWORD=your-secure-key-password
```

**IMPORTANT**: 
- ✅ Keep `android/local.properties` on your machine only
- ✅ Passwords should be STRONG (min 12 chars, mixed case, numbers, symbols)
- ✅ Never share or commit this file
- ✅ Store backup of passwords in secure vault (1Password, LastPass, etc.)

### 3. Verify Setup

```bash
# List keys in keystore
keytool -list -v -keystore android/app/release.keystore

# Build APK (will use local.properties)
cd .. && ./gradlew assembleRelease

# Sign verification
jarsigner -verify -verbose -certs dist-android/app-release.apk
```

---

## CI/CD Setup (GitHub Actions / GitLab CI)

### GitHub Actions Example

**Step 1: Prepare Keystore as Secret**

```bash
# On your local machine, encode keystore as base64
cat android/app/release.keystore | base64 > keystore.b64

# Copy the output and add as GitHub repository secret:
# Go to: Settings > Secrets > New repository secret
# Name: ANDROID_KEYSTORE_FILE_B64
# Value: [paste base64 content]
```

**Step 2: Add Secrets to GitHub**

```
Settings > Secrets > New repository secret
- ANDROID_KEYSTORE_FILE_B64: [base64 encoded keystore]
- ANDROID_KEYSTORE_PASSWORD: [password]
- ANDROID_KEY_ALIAS: medicore_key
- ANDROID_KEY_PASSWORD: [password]
```

**Step 3: GitHub Actions Workflow**

```yaml
# .github/workflows/android-release.yml

name: Build Android Release APK

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'
      
      - name: Decode Keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_FILE_B64 }}" | base64 -d > android/app/release.keystore
      
      - name: Build Release APK
        run: cd android && ./gradlew assembleRelease
        env:
          MEDICORE_RELEASE_STORE_FILE: release.keystore
          MEDICORE_RELEASE_STORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          MEDICORE_RELEASE_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          MEDICORE_RELEASE_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
      
      - name: Upload APK to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
          packageName: com.medicore.healthcare
          releaseFiles: android/app/build/outputs/apk/release/*.apk
          track: internal  # or 'beta', 'production'
```

---

## Keystore Management Best Practices

### Security

| Aspect | Recommendation |
|--------|-----------------|
| **Creation** | Generate with min 2048-bit RSA key, 10,000 days validity |
| **Passwords** | Min 12 chars, mix upper/lower/numbers/symbols |
| **Storage** | Encrypted, offline backup; secure vault for passwords |
| **Access** | Limited to DevOps/Release engineer team |
| **Rotation** | Annually for production apps |
| **Audit** | Track who signed each release in Git tags |

### Multi-Environment Setup

**Recommended Setup**:
```
Development:      dev.keystore       (shared team keystore)
Staging:          staging.keystore   (shared team keystore)
Production:       prod.keystore      (single, heavily protected)
```

Each uses different passwords stored in secure vault.

### Keystore Backup & Recovery

```bash
# Create encrypted backup
gpg -c --cipher-algo AES256 android/app/release.keystore
# Creates: android/app/release.keystore.gpg

# Decrypt when needed
gpg -d android/app/release.keystore.gpg > android/app/release.keystore

# Store backup securely (offline, encrypted)
```

### If Keystore is Compromised

1. **Immediately**:
   - Notify security team
   - Stop all releases with that key  
   - Revoke app signing key in Google Play Console (can only do once!)

2. **Within 24 hours**:
   - Generate new keystore
   - Update all CI/CD secrets
   - Rotate passwords in vault

3. **Follow-up**:
   - Audit Play Store releases signed with old key
   - Notify users if needed
   - Document incident

---

## Verification Checklist

Before production release:

- [ ] `android/local.properties` created from template
- [ ] Keystore file generated and working locally
- [ ] `./gradlew assembleRelease` builds successfully  
- [ ] APK signature verified: `jarsigner -verify -verbose app-release.apk`
- [ ] GitHub Secrets configured (if using CI/CD)
- [ ] Keystore backup encrypted and stored offline
- [ ] Team aware of security procedures
- [ ] Production keystore in secure vault, not on any developer machine

---

## Troubleshooting

### "Could not find keystore file"
```
Issue: MEDICORE_RELEASE_STORE_FILE path is wrong
Fix: Ensure path is relative to android/app/ or absolute
Example: release.keystore (in android/app/)
```

### "Invalid password"
```
Issue: Password mismatch between keystore and local.properties
Fix: Verify password in local.properties matches keystore password
Check: keytool -list -keystore android/app/release.keystore
```

### "Key not found in keystore"
```
Issue: Key alias mismatch
Fix: List available keys: keytool -list -keystore android/app/release.keystore
Ensure MEDICORE_RELEASE_KEY_ALIAS matches (default: medicore_key)
```

### Release build is unsigned
```
Issue: Missing credentials in local.properties or environment
Fix: Check logs for: "❌ ERROR: Release build will be UNSIGNED"
Ensure all MEDICORE_RELEASE_* variables are set
```

---

## References

- [Android Code Signing Guide](https://developer.android.com/studio/publish/app-signing)
- [Google Play App Signing Best Practices](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Gradle Build Configuration](https://developer.android.com/studio/build)
- Keytool Documentation: `keytool -help`
