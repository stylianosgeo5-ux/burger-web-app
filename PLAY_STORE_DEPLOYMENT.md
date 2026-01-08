# Google Play Store Deployment Guide

## Step 1: Create a Keystore for App Signing

The keystore is used to sign your app. Keep it secure and backed up!

Run this command in PowerShell:
```powershell
cd C:\Users\styli\flotter\burger_app\android\app
keytool -genkey -v -keystore burger-app-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias burger-app
```

You'll be asked to provide:
- Keystore password (remember this!)
- Key password (remember this!)
- Your name
- Organizational unit
- Organization name
- City
- State
- Country code

**IMPORTANT:** Save the keystore file and passwords securely! You cannot update your app without them.

## Step 2: Configure Signing in Gradle

Create a file `android/key.properties` with your keystore information:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=burger-app
storeFile=burger-app-key.jks
```

**IMPORTANT:** Add `key.properties` to your `.gitignore` to keep passwords secure!

## Step 3: Update Application ID and App Name

1. Change the application ID in `android/app/build.gradle`:
   - Current: `com.example.burger_app`
   - Change to: `com.yourcompany.burgername` (must be unique)

2. Update app name in `android/app/src/main/AndroidManifest.xml`:
   - Current: `android:label="burger_app"`
   - Change to: `android:label="Your Burger App Name"`

3. Remove unused permissions from AndroidManifest.xml (location permissions if not needed)

## Step 4: Build Release App Bundle

The App Bundle (.aab) is the recommended format for Play Store:

```powershell
cd C:\Users\styli\flotter\burger_app
flutter clean
flutter build appbundle --release
```

The output file will be at:
`build/app/outputs/bundle/release/app-release.aab`

## Step 5: Google Play Console Setup

1. Go to https://play.google.com/console
2. Pay one-time $25 registration fee
3. Create a new app:
   - App name
   - Default language
   - App type (Application)
   - Free or Paid

## Step 6: Complete Store Listing

In Play Console, fill out:

### Main store listing:
- App name (30 characters max)
- Short description (80 characters max)
- Full description (4000 characters max)
- App icon (512x512 PNG)
- Feature graphic (1024x500 PNG)
- Screenshots (at least 2, up to 8)
  - Phone: 16:9 or 9:16 ratio

### Content rating:
- Complete questionnaire (food ordering app)

### App content:
- Privacy policy URL (required)
- Ads declaration (does your app have ads?)
- Target audience

### Store settings:
- App category (Food & Drink)
- Contact details (email, phone optional)

## Step 7: Upload App Bundle

1. Go to "Release" → "Production"
2. Click "Create new release"
3. Upload your `app-release.aab`
4. Add release notes
5. Review and roll out to production

## Step 8: Review Process

- Google reviews your app (usually 1-3 days)
- You'll receive email notification
- If approved, app goes live
- If rejected, fix issues and resubmit

## Important Notes

### Version Management:
- Each update must have higher `versionCode` in `build.gradle`
- Update `versionName` for user-visible version (e.g., "1.0.1")

### App Signing by Google:
- Recommended: Let Google manage your signing key
- First time uploading: enroll in Play App Signing
- Google generates and manages the production key

### Testing Before Release:
- Use Internal Testing track first
- Add test users via email
- Test thoroughly before production

### Post-Launch:
- Monitor crashes in Play Console
- Respond to user reviews
- Update regularly

## Quick Commands Reference

```powershell
# Build release APK (for testing)
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Check app size
flutter build appbundle --release --analyze-size

# Build with obfuscation (optional, for security)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

## Troubleshooting

### "App not signed" error:
- Make sure key.properties exists and signing is configured

### "Duplicate permission" error:
- Check AndroidManifest.xml for duplicate permissions

### Build fails:
- Run `flutter clean` then rebuild
- Check `flutter doctor` for issues

### App rejected:
- Read rejection email carefully
- Common issues: privacy policy, permissions justification, content rating

## Need Help?
- Flutter docs: https://docs.flutter.dev/deployment/android
- Play Console Help: https://support.google.com/googleplay/android-developer
