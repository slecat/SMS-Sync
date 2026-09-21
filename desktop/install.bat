@echo off
echo Setting up environment variables...
set ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
set npm_config_registry=https://registry.npmmirror.com

echo Installing dependencies...
npm install

echo Installation complete!
pause
