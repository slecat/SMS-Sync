@echo off
setlocal EnableExtensions
title SMS Sync Desktop Packager

pushd "%~dp0" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Failed to switch to script directory.
  echo Script path: %~dp0
  pause
  exit /b 1
)

set "MODE=%~1"
if "%MODE%"=="" (
  echo ==========================================
  echo        SMS Sync Desktop Packager
  echo ==========================================
  echo.
  echo [1] Quick package (recommended)
  echo [2] Safe package (run test/lint/format check)
  echo [3] Clean + safe package (remove dist first)
  echo.
  set /p MODE=Select mode (1/2/3, default 1): 
)

if "%MODE%"=="" set "MODE=1"
if /I not "%MODE%"=="1" if /I not "%MODE%"=="2" if /I not "%MODE%"=="3" (
  echo [WARN] Invalid mode. Use default mode 1.
  set "MODE=1"
)

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js was not found in PATH.
  goto :fail
)

where npm >nul 2>nul
if errorlevel 1 (
  echo [ERROR] npm was not found in PATH.
  goto :fail
)

if "%MODE%"=="3" (
  echo.
  echo [STEP] Remove dist directory...
  if exist dist rmdir /s /q dist
)

echo.
echo [STEP] Install dependencies...
call npm install --registry=https://registry.npmjs.org
if errorlevel 1 goto :fail

if "%MODE%"=="2" goto :verify
if "%MODE%"=="3" goto :verify
goto :build

:verify
echo.
echo [STEP] Run tests...
call npm test
if errorlevel 1 goto :fail

echo.
echo [STEP] Run lint...
call npm run lint
if errorlevel 1 goto :fail

echo.
echo [STEP] Run format check...
call npm run format:check
if errorlevel 1 goto :fail

:build
echo.
echo [STEP] Build Windows packages with mirror...
set "ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/"
set "ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/"
call npm run dist:win:mirror
if errorlevel 1 goto :fail

echo.
echo [OK] Build completed. Outputs in:
echo %CD%\dist
if exist dist dir /b dist
goto :done

:fail
echo.
echo [ERROR] Build failed. Check logs above.
set "EXITCODE=1"
goto :exit

:done
set "EXITCODE=0"

:exit
echo.
pause
popd
endlocal & exit /b %EXITCODE%
