# 🍔 Burger Orders Dashboard - Setup Instructions

## How to View Orders on the Dashboard

### Method 1: Load File from Android Device (Recommended)

1. **Place an order** in the mobile app
2. **Find the orders file** on your Android device:
   - Location: `/storage/emulated/0/Download/burger_orders.json`
   - Use a file manager app on the Android emulator or device
   
3. **Transfer the file** to your computer:
   - **Option A**: Use ADB command:
     ```
     adb pull /sdcard/Download/burger_orders.json C:\Users\styli\Downloads\
     ```
   - **Option B**: In emulator, drag the file from Downloads folder to your PC

4. **Open the dashboard** (double-click `launcher.html`)

5. **Click "Load File" button** on the dashboard

6. **Select** the `burger_orders.json` file from your Downloads folder

7. Orders will appear immediately!

### Method 2: Quick ADB Command

Open PowerShell in the `orders_website` folder and run:

```powershell
adb pull /sdcard/Download/burger_orders.json .
```

Then refresh the dashboard.

## Dashboard Features

- 📊 **Real-time Statistics**: Total orders, revenue, burgers sold
- 🔍 **Search**: Filter orders by any text
- 📁 **Load File**: Import orders from JSON file
- 🔄 **Refresh**: Reload orders from file
- 🗑️ **Delete**: Remove individual orders or clear all
- 📥 **Export**: Download orders as JSON file

## Troubleshooting

### Orders not showing up?
1. Make sure you placed an order in the app (check console for "Orders saved to:" message)
2. Verify the file exists using: `adb shell ls /sdcard/Download/burger_orders.json`
3. Pull the file again using the ADB command
4. Click "Load File" on the dashboard and select the file

### Can't find ADB?
- ADB is included with Android SDK
- Location: `C:\Users\[YourName]\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- Or use Android Studio's Terminal which has ADB in PATH

## Auto-Sync Alternative

To automatically sync orders, you can:
1. Create a scheduled task to pull the file every minute
2. Or use the "Refresh" button manually after placing orders

---

**Note**: The mobile app saves orders to the Android device storage, and the website reads from a file. They don't automatically sync - you need to transfer the file manually or use ADB.
