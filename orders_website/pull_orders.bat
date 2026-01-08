@echo off
echo ================================
echo  Pulling Orders from Android
echo ================================
echo.

set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

echo Checking ADB connection...
"%ADB%" devices

echo.
echo Checking if orders file exists...
"%ADB%" shell ls /sdcard/Download/burger_orders.json

echo.
echo Pulling burger_orders.json...
"%ADB%" pull /sdcard/Download/burger_orders.json .

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ SUCCESS! Orders file pulled successfully.
    echo.
    echo File location: %CD%\burger_orders.json
    echo.
    echo Opening dashboard now...
    start index.html
) else (
    echo.
    echo ✗ ERROR: Could not pull file.
    echo.
    echo ⚠ PLACE AN ORDER IN THE APP FIRST!
    echo.
    echo The app must place at least one order to create the file.
    echo After placing an order, run this script again.
)

echo.
pause
