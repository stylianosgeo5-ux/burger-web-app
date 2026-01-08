# Deploy Your Burger App Publicly

This guide will help you make your burger app accessible from any phone.

## Quick Option: Using Render (Free & Easy)

### Step 1: Deploy Backend to Render

1. **Create a GitHub repository** (if you haven't already):
   ```bash
   cd c:\Users\styli\flotter\burger_app
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. **Go to [Render.com](https://render.com)** and sign up

3. **Create a New Web Service**:
   - Click "New +" → "Web Service"
   - Connect your GitHub repository
   - Configure:
     - **Name**: burger-app-backend
     - **Root Directory**: `orders_website`
     - **Build Command**: `npm install`
     - **Start Command**: `node server.js`
     - **Plan**: Free

4. **Deploy** - Render will give you a URL like: `https://burger-app-backend.onrender.com`

### Step 2: Update Flutter Web App

Update the server URL in your Flutter app to use the Render URL:

1. Edit `lib/main.dart` line 167:
   ```dart
   static String get serverUrl => kIsWeb 
     ? 'https://burger-app-backend.onrender.com' 
     : 'http://10.0.2.2:8000';
   ```

2. Update `lib/order_status_page.dart` and `lib/multi_order_status_page.dart` similarly

3. Rebuild the web app:
   ```bash
   flutter build web --release
   ```

### Step 3: Deploy Frontend to Netlify

1. **Go to [Netlify.com](https://netlify.com)** and sign up

2. **Deploy via Drag & Drop**:
   - Drag the `build/web` folder to Netlify's deploy area
   - Or use Netlify CLI:
     ```bash
     npm install -g netlify-cli
     netlify deploy --prod --dir=build/web
     ```

3. **Your app will be live at**: `https://your-app-name.netlify.app`

## Alternative: Using ngrok (Temporary Testing)

For quick testing without full deployment:

1. **Install ngrok**: Download from [ngrok.com](https://ngrok.com)

2. **Expose your backend**:
   ```bash
   ngrok http 8000
   ```
   This gives you a public URL like: `https://abc123.ngrok.io`

3. **Update Flutter app** to use ngrok URL temporarily

4. **Rebuild and deploy**:
   ```bash
   flutter build web --release
   netlify deploy --prod --dir=build/web
   ```

## Alternative: Firebase Hosting (Google)

### Backend (Firebase Functions):
```bash
npm install -g firebase-tools
firebase init hosting
firebase init functions
# Move your server.js logic to functions/index.js
firebase deploy
```

### Frontend:
```bash
flutter build web --release
firebase deploy --only hosting
```

## Testing Your Public App

1. Open the Netlify URL on any phone
2. Place a test order
3. Check the Render backend dashboard or your local dashboard

## Important Notes

- **Free Render** services sleep after inactivity - first request may be slow
- **ngrok** free tier URLs expire after 2 hours
- **Firebase** has generous free tier limits
- Update your **CORS settings** if needed for production domains
- Consider using **environment variables** for API URLs

## Recommended Production Setup

1. **Backend**: Render.com or Railway.app (free tier)
2. **Frontend**: Netlify or Vercel (free tier)
3. **Database**: Consider upgrading from JSON file to PostgreSQL or MongoDB for production
4. **SSL**: Automatically provided by Render/Netlify

Your customers can now order from anywhere! 🍔
