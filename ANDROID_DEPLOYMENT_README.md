# MediCore Android App - Google Play Store Deployment

This guide will help you prepare and deploy the MediCore healthcare management app to the Google Play Store.

## Prerequisites

1. **Java JDK 8 or higher** - Required for Android development
   - Download from: https://adoptium.net/temurin/releases/
   - Set JAVA_HOME environment variable

2. **Android Studio** (optional but recommended)
   - Download from: https://developer.android.com/studio
   - Install Android SDK and build tools

3. **Google Play Console Account**
   - Go to: https://play.google.com/console
   - Create a developer account ($25 one-time fee)

## Build Instructions

### Method 1: Using the Build Script (Recommended)

1. **Install Java JDK** if not already installed
2. **Run the build script:**
   ```bash
   ./build-android.bat
   ```
3. Follow the prompts to create the keystore
4. The APK will be generated at: `android/app/build/outputs/apk/release/app-release.apk`

### Method 2: Manual Build

1. **Install Java JDK**
2. **Generate keystore:**
   ```bash
   cd android
   keytool -genkey -v -keystore app/release.keystore -alias medicore_key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=MediCore Healthcare, OU=Development, O=MediCore, L=Kampala, ST=Central, C=UG"
   ```
3. **Build the APK:**
   ```bash
   cd android
   ./gradlew assembleRelease
   ```

## Google Play Store Deployment

### Step 1: Create/Update App in Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click "Create app" or select existing app
3. Fill in app details:
   - **App name:** MediCore Healthcare
   - **Default language:** English
   - **App type:** App (not game)
   - **Free or paid:** Free

### Step 2: Upload APK

1. In Play Console, go to "Release" → "Production"
2. Click "Create new release"
3. Upload the APK file: `android/app/build/outputs/apk/release/app-release.apk`
4. Fill in release notes

### Step 3: Store Listing

1. Go to "Main store listing"
2. **App name:** MediCore Healthcare
3. **Short description:** Complete healthcare management system for clinics
4. **Full description:**
   ```
   MediCore is a comprehensive healthcare management system designed for clinics and medical facilities. Features include:

   • Patient registration and management
   • Appointment scheduling
   • Electronic health records
   • Pharmacy management
   • Laboratory tracking
   • Billing and invoicing
   • Employee management
   • Real-time notifications
   • Secure data storage

   Perfect for small to medium-sized clinics looking to digitize their operations.
   ```
5. **App icon:** Use the medicore-logo.png (512x512 recommended)
6. **Feature graphic:** Create a 1024x500 banner
7. **Screenshots:** Take screenshots of the app (at least 2, max 8)
8. **Category:** Medical
9. **Contact details:** Add your contact information

### Step 4: Content Rating

1. Go to "App content"
2. Answer the content rating questionnaire
3. Select appropriate ratings

### Step 5: Pricing & Distribution

1. Go to "Pricing & distribution"
2. Set as Free app
3. Select countries for distribution
4. Agree to terms

### Step 6: Publish

1. Review all information
2. Click "Start rollout to production"
3. Wait for Google review (usually 1-3 days)

## App Store Metadata

### App Details
- **Package name:** com.medicore.healthcare
- **Version:** 1.0.0
- **Min Android version:** API 21 (Android 5.0)

### Required Permissions
- Internet access (for API calls)
- Network state (for connectivity checks)

## Troubleshooting

### Build Issues
- Ensure Java JDK is installed and JAVA_HOME is set
- Check that all dependencies are installed: `npm install`
- Make sure the web build is up to date: `npm run build`

### Play Store Issues
- APK must be signed with a valid keystore
- App must comply with Google Play policies
- All required metadata must be provided

### Common Errors
- **"App not compatible with device":** Check minSdkVersion in build.gradle
- **"APK not signed":** Ensure keystore is properly configured
- **"Missing required metadata":** Complete all store listing fields

## Support

For issues with the app or deployment process, check:
- [Capacitor Documentation](https://capacitorjs.com/docs)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android Developer Documentation](https://developer.android.com)