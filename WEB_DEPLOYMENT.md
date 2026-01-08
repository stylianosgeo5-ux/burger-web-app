# 🌐 Web Deployment Guide

## Your burger app has been built for web!

The web files are located in: `build/web/`

## Option 1: Test Locally (Quick Preview)

Run a local web server to test:

```powershell
# Option A: Using Python (if installed)
cd build/web
python -m http.server 8080

# Option B: Using Node.js http-server
cd build/web
npx http-server -p 8080
```

Then open your browser to: **http://localhost:8080**

## Option 2: Deploy to Free Hosting

### Firebase Hosting (Recommended - Free)

1. Install Firebase CLI:
```powershell
npm install -g firebase-tools
```

2. Login to Firebase:
```powershell
firebase login
```

3. Initialize Firebase in your project:
```powershell
cd C:\Users\styli\flotter\burger_app
firebase init hosting
```
- Choose "Use an existing project" or create a new one
- Set public directory to: `build/web`
- Configure as single-page app: Yes
- Don't overwrite index.html

4. Deploy:
```powershell
firebase deploy --only hosting
```

Your app will be live at: `https://your-project.web.app`

### GitHub Pages (Free)

1. Create a new repository on GitHub
2. Copy contents of `build/web/` to your repo
3. Enable GitHub Pages in repo settings
4. Your app will be at: `https://yourusername.github.io/repo-name`

### Netlify (Free - Easiest)

1. Go to: https://netlify.com
2. Sign up for free
3. Drag and drop the `build/web` folder
4. Your app is instantly live!

### Vercel (Free)

1. Go to: https://vercel.com
2. Sign up for free
3. Connect your GitHub repo or upload `build/web`
4. Instant deployment!

## Important Notes for Web Version

⚠️ **Server URL Issue**: 
- The app currently uses `http://10.0.2.2:8000` which only works for Android emulator
- For web, you need to change this to your actual server URL

To fix this before deploying:

1. Open `lib/order_status_page.dart` and `lib/multi_order_status_page.dart`
2. Change `static const String serverUrl = 'http://10.0.2.2:8000';`
3. To: `static const String serverUrl = 'http://YOUR_SERVER_IP:8000';`
4. Rebuild: `flutter build web --release`

You can also deploy the Node.js server to:
- **Heroku** (free tier)
- **Railway** (free tier)
- **Render** (free tier)
- **Glitch** (free)

## Features Working on Web:
✅ Order placement
✅ Multiple burger customization
✅ Multi-order status tracking
✅ Real-time status updates
✅ Order tabs
❌ Google Maps (requires API key configuration for web)
❌ Geolocation (needs HTTPS)

Enjoy your web app! 🍔🌐
