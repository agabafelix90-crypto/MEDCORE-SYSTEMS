@echo off
echo Building MediCore Android APK for Google Play Store...
echo.

cd android

echo Generating keystore (you will be prompted for passwords)...
keytool -genkey -v -keystore app/release.keystore -alias medicore_key -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=MediCore Healthcare, OU=Development, O=MediCore, L=Kampala, ST=Central, C=UG"

echo.
echo Building release APK...
./gradlew assembleRelease

echo.
echo APK generated at: android/app/build/outputs/apk/release/app-release.apk
echo.
echo To deploy to Google Play Store:
echo 1. Go to https://play.google.com/console
echo 2. Create a new app or update existing one
echo 3. Upload the APK from the path above
echo 4. Fill in store listing, screenshots, and publish
echo.
pause