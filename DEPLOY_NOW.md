# 🚀 DEPLOY YOUR BURGER APP - STEP BY STEP GUIDE

Your code is ready! Follow these exact steps:

## ✅ STEP 1: Create GitHub Repository (5 minutes)

1. Go to https://github.com/new
2. Create a new repository:
   - Name: `burger-app`
   - Make it **Public**
   - Don't initialize with README
3. Copy the repository URL (looks like: `https://github.com/YOUR_USERNAME/burger-app.git`)

4. Run these commands in your terminal:
```powershell
cd c:\Users\styli\flotter\burger_app
git remote add origin https://github.com/stylianosgeo5-ux/burger-web-app.git
git branch -M main
git push -u origin main
```

## ✅ STEP 2: Deploy Backend to Render (5 minutes)

1. Go to https://render.com and sign up (use GitHub)
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository `burger-app`
4. Configure:
   - **Name**: `burger-backend`
   - **Root Directory**: `orders_website`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
   - **Instance Type**: `Free`

5. Click **"Advanced"** and add Environment Variable:
   - Key: `PORT`
   - Value: `10000` (Render requires this)

6. Click **"Create Web Service"**

7. **Wait 2-3 minutes** for deployment. You'll get a URL like:
   `https://burger-backend.onrender.com`

8. **COPY THIS URL** - you'll need it!

## ✅ STEP 3: Update Flutter App with Backend URL

Replace `YOUR_RENDER_URL` below with your actual Render URL, then run:

```powershell
# Update main.dart
(Get-Content c:\Users\styli\flotter\burger_app\lib\main.dart) -replace 'http://localhost:8000', 'YOUR_RENDER_URL' | Set-Content c:\Users\styli\flotter\burger_app\lib\main.dart

# Update order_status_page.dart
(Get-Content c:\Users\styli\flotter\burger_app\lib\order_status_page.dart) -replace 'http://localhost:8000', 'YOUR_RENDER_URL' | Set-Content c:\Users\styli\flotter\burger_app\lib\order_status_page.dart

# Update multi_order_status_page.dart
(Get-Content c:\Users\styli\flotter\burger_app\lib\multi_order_status_page.dart) -replace 'http://localhost:8000', 'YOUR_RENDER_URL' | Set-Content c:\Users\styli\flotter\burger_app\lib\multi_order_status_page.dart
```

Or just tell me your Render URL and I'll update the files for you!

## ✅ STEP 4: Rebuild Flutter Web App

```powershell
cd c:\Users\styli\flotter\burger_app
flutter build web --release
```

## ✅ STEP 5: Deploy Frontend to Netlify (3 minutes)

### Option A: Drag & Drop (Easiest)
1. Go to https://app.netlify.com/drop
2. Drag the folder `c:\Users\styli\flotter\burger_app\build\web` onto the page
3. Done! You'll get a URL like: `https://random-name.netlify.app`

### Option B: Netlify CLI (More Control)
```powershell
npm install -g netlify-cli
cd c:\Users\styli\flotter\burger_app
netlify deploy --dir=build/web --prod
```

## 🎉 YOU'RE LIVE!

Your app is now accessible from any phone at your Netlify URL!

### Test It:
1. Open your Netlify URL on your phone: `https://your-app.netlify.app`
2. Place a test order
3. Check the dashboard at: `https://burger-backend.onrender.com`

### Important Notes:
- **Free Render services sleep after 15 min of inactivity** - first request may take 30 seconds
- **Save your URLs**:
  - Backend: `https://burger-backend.onrender.com`
  - Frontend: `https://your-app.netlify.app`
  - Dashboard: `https://burger-backend.onrender.com` (same as backend)

### Custom Domain (Optional):
- Netlify: Settings → Domain Management → Add custom domain
- Render: Settings → Add custom domain

## 🔧 Update Later:
When you make changes:
```powershell
cd c:\Users\styli\flotter\burger_app

# Commit changes
git add .
git commit -m "Update app"
git push

# Rebuild and redeploy frontend
flutter build web --release
netlify deploy --dir=build/web --prod
```

Render will auto-deploy when you push to GitHub!

---

**Need help?** Just ask! Tell me when you've completed each step.
