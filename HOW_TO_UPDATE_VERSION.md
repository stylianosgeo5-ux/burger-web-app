# How to Update App Version

## Automatic Update Notifications System

The app now has an **automatic update notification system** that alerts users when a new version is available!

### How it Works

1. **Every 5 minutes**, the app checks `https://burgercy.com/version.json`
2. If the server version differs from the app version, users see an update dialog
3. Users can choose to:
   - **Update Now** - Reloads the page immediately
   - **Later** - Reminds them in 1 hour

### When You Make Changes

**Every time you deploy new changes**, follow these steps:

#### Step 1: Update Version in Code
Edit `lib/update_checker.dart` line 9:
```dart
static const String currentVersion = '2.5.0'; // ← Change this to next version (e.g., 2.6.0)
```

#### Step 2: Update Version JSON
Edit `web/version.json`:
```json
{
  "version": "2.6.0",
  "updateMessage": "Describe what changed!",
  "releaseDate": "2026-02-18"
}
```

#### Step 3: Build and Deploy
```bash
flutter build web --release
git add -A
git commit -m "Update to version 2.6.0"
git push origin main
```

### Version Numbers

Use semantic versioning: **MAJOR.MINOR.PATCH**

- **2.5.0** → **2.5.1** - Bug fixes
- **2.5.0** → **2.6.0** - New features
- **2.5.0** → **3.0.0** - Major changes

### Current Version

**Version 2.5.0** includes:
- ✅ Guest user auto-creation (no login required)
- ✅ Server-side cart persistence
- ✅ Cyprus phone number validation
- ✅ Checkout guest-to-permanent conversion
- ✅ Admin panel for user management
- ✅ Removed Account page
- ✅ Automatic update notifications

### Files to Update for Each Release

1. ✅ `lib/update_checker.dart` - currentVersion
2. ✅ `web/version.json` - version, updateMessage, releaseDate
3. ✅ Build and deploy

That's it! Users will automatically be notified of updates.
