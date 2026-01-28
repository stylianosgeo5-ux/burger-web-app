# Burger App - Copilot Instructions

## Project Overview

This is a **Flutter mobile & web burger ordering app** with a **Node.js/Express backend**. The app supports Android, iOS (macOS), Linux, Windows, and web platforms. Orders are managed through a dashboard server and local JSON file storage.

**Key Components:**
- **Flutter Frontend** (`lib/`): Multi-platform mobile/web UI
- **Node.js Backend** (`orders_website/`): Express server managing orders, user authentication, discounts, and opening hours
- **Data Storage**: JSON files (burger_orders.json, users.json, discount_codes.json, fulfilled_orders_history.json)

---

## Architecture & Data Flow

### Multi-Platform Architecture
- **Mobile/Desktop**: Native Flutter apps for Android, iOS, macOS, Linux, Windows
- **Web**: Flutter web + separate web dashboard in `orders_website/`
- **Platform Detection**: Code uses `kIsWeb` to differentiate web from mobile runtime behavior
  - Web paths: `static const String serverUrl = 'https://...'` (public URL)
  - Mobile paths: Local HTTP calls to `'http://10.0.2.2:8000'` (Android emulator bridge) or actual server URL

### Communication Pattern
1. **Flutter App** → HTTP requests (via `package:http`) → **Express Backend**
2. Backend reads/writes JSON files as persistent storage
3. **Web Dashboard** (`index.html` + JS) loads local burger_orders.json for real-time visualization
4. Mobile app saves orders locally to device Downloads folder AND sends to backend

### Key API Endpoints (server.js)
- `POST /api/auth/register`, `/api/auth/login`: User authentication with token-based sessions
- `POST /api/orders`: Create new order
- `GET /api/orders`: List orders
- `PATCH /api/orders/:id`: Update order status (confirmed → preparing → cooked → fulfilled)
- `DELETE /api/orders/:id`: Remove order
- `GET /api/discounts`: Fetch discount codes
- `GET /api/opening-hours`: Store hours

---

## Current Version & Update System

**Current App Version:** 2.3.0 (defined in [update_checker.dart](../lib/update_checker.dart#L7))

The `UpdateChecker` class monitors version.json on `burgercy.com` and prompts users to reload the web app. Update this version number when shipping new features.

---

## Critical Workflows

### Building & Running

```bash
# Flutter app (mobile/desktop)
flutter run                    # Run on connected device/emulator
flutter build apk --release   # Android APK
flutter build web --release   # Web build → output in build/web/

# Backend server (local development)
cd orders_website
npm install
npm start                      # Runs on :8000
```

### Data Handling

- **Orders saved locally**: Flutter app writes to device Downloads folder via file I/O
- **Server sync**: Orders POST to Express backend; backend stores in `burger_orders.json`
- **Dashboard access**: Load burger_orders.json file via UI button (Method 1 in orders_website/README.md uses ADB)
- **File locations**: All JSON files in `orders_website/` directory (unless `PERSISTENT_STORAGE_DIR` env var set for production)

### Testing Orders Locally

1. Run Express backend: `npm start` in orders_website/
2. Update Flutter app to point to localhost: `static String get serverUrl => 'http://10.0.2.2:8000'` (Android emulator) or `'http://localhost:8000'` (web)
3. Create order in app
4. Dashboard: Open `orders_website/index.html` → "Load File" → select burger_orders.json
5. View order details, update status, export/delete

---

## Code Organization

| File | Purpose |
|------|---------|
| [lib/main.dart](../lib/main.dart) | App entry point, navigation bar, home page UI |
| [lib/auth_page.dart](../lib/auth_page.dart) | Login/register form, token management |
| [lib/order_status_page.dart](../lib/order_status_page.dart) | Single order detail view, status polling, animations |
| [lib/multi_order_status_page.dart](../lib/multi_order_status_page.dart) | List of user's orders, batch operations |
| [lib/update_checker.dart](../lib/update_checker.dart) | Web-only: checks version.json every 5 min, triggers reload |
| [orders_website/server.js](../orders_website/server.js) | Express API, authentication, order CRUD, file I/O |
| [orders_website/index.html](../orders_website/index.html) | Admin dashboard for order management |

---

## Patterns & Conventions

### HTTP Requests
- Always use `try/catch` with `http.get()` / `http.post()` 
- Errors silently log in debug; silent fail on production (see `update_checker.dart`)
- Authentication: Bearer token in Authorization header
- Example: `headers: {'Authorization': 'Bearer $token'}`

### State Management
- Uses Flutter's native `StatefulWidget` with `setState()`
- Timer-based polling: `Timer.periodic()` for real-time status updates
- Animations: `AnimationController` + `CurvedAnimation` for pulse effects

### UI Styling
- **Primary Color**: `Colors.orange` for buttons, highlights, tabs
- **Backgrounds**: `Colors.orange[50]` for sections, `Colors.white` for cards
- **Navigation**: Custom `AppNavigationBar` with 3 tabs (Home, Order, Status)

### Platform-Specific Code
```dart
if (kIsWeb) {
  // Web-specific: use public server URL, reload capability
} else {
  // Mobile: use local emulator bridge or public server URL
}
```

---

## Dependencies

### Flutter (pubspec.yaml)
- `shared_preferences`: Local key-value storage
- `http`: HTTP client for API calls
- `cupertino_icons`: iOS-style icons
- `flutter_lints`: Code quality rules

### Node.js (orders_website/package.json)
- `express`: Web framework
- `cors`: Cross-origin request handling
- `xlsx`: Excel export (for reports)

---

## Deployment Notes

- **Backend**: Render.com (env var: `PERSISTENT_STORAGE_DIR` for persistent storage)
- **Web Frontend**: Netlify (Flutter web build from `flutter build web`)
- **Mobile Apps**: Play Store (Android), App Store (iOS) via release build
- **Server URL**: Update across [auth_page.dart](../lib/auth_page.dart#L24), [order_status_page.dart](../lib/order_status_page.dart#L27), [multi_order_status_page.dart](../lib/multi_order_status_page.dart) when changing backend

See [DEPLOYMENT_PUBLIC.md](../DEPLOYMENT_PUBLIC.md) for detailed Render + Netlify setup.

---

## Common Tasks

**Add a new order field:**
1. Update Express endpoint in server.js
2. Modify Dart order model (Map<String, dynamic> in main.dart)
3. Update UI in order_status_page.dart or auth_page.dart
4. Increment version in update_checker.dart

**Fix a bug in mobile UI:**
- Edit relevant .dart file in lib/
- Run `flutter run` to hot-reload
- Test on Android emulator or physical device

**Modify dashboard:**
- Edit HTML/JS in orders_website/index.html
- Refresh browser (no rebuild needed)
- For backend logic, update server.js and restart `npm start`
