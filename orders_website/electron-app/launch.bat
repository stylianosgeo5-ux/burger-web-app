@echo off
cd /d "%~dp0"
echo Starting Burgercy Dashboard...
node_modules\.bin\electron.cmd .
pause
