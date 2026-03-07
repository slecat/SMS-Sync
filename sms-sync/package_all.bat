@echo off
setlocal EnableExtensions
title SMS Sync One-Click Packager

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help

pushd "%~dp0" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Failed to enter repository root.
  exit /b 1
)

set "ROOT_DIR=%CD%"
set "MOBILE_DIR=%ROOT_DIR%\mobile"
set "DESKTOP_DIR=%ROOT_DIR%\desktop"
set "OUTPUT_DIR=%ROOT_DIR%\output"
set "APK_SRC=%MOBILE_DIR%\build\app\outputs\flutter-apk\app-release.apk"
set "APK_DST=%OUTPUT_DIR%\SmsSyncMobile.apk"
set "EXE_DST=%OUTPUT_DIR%\SmsSyncSetup.exe"

echo ==========================================
echo         SMS Sync One-Click Packager
echo ==========================================
echo Root   : %ROOT_DIR%
echo Output : %OUTPUT_DIR%
echo.

if not exist "%MOBILE_DIR%\pubspec.yaml" (
  echo [ERROR] Mobile project not found: %MOBILE_DIR%
  goto :fail
)
if not exist "%DESKTOP_DIR%\package.json" (
  echo [ERROR] Desktop project not found: %DESKTOP_DIR%
  goto :fail
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter is not in PATH.
  goto :fail
)
where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] node is not in PATH.
  goto :fail
)
where npm >nul 2>nul
if errorlevel 1 (
  echo [ERROR] npm is not in PATH.
  goto :fail
)
where java >nul 2>nul
if errorlevel 1 (
  echo [ERROR] java is not in PATH.
  goto :fail
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if exist "%APK_DST%" del /f /q "%APK_DST%" >nul 2>nul
if exist "%EXE_DST%" del /f /q "%EXE_DST%" >nul 2>nul

echo [STEP 1/5] Install mobile dependencies...
pushd "%MOBILE_DIR%" >nul
call flutter pub get
if errorlevel 1 (
  popd >nul
  goto :fail
)

echo [STEP 2/5] Build mobile release APK...
call flutter build apk --release
if errorlevel 1 (
  popd >nul
  goto :fail
)
popd >nul

if not exist "%APK_SRC%" (
  echo [ERROR] APK output not found: %APK_SRC%
  goto :fail
)

copy /Y "%APK_SRC%" "%APK_DST%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy APK to output.
  goto :fail
)

echo [STEP 3/5] Install desktop dependencies...
pushd "%DESKTOP_DIR%" >nul
call npm install --registry=https://registry.npmjs.org
if errorlevel 1 (
  popd >nul
  goto :fail
)

echo [STEP 4/5] Build desktop installer (NSIS exe only)...
set "ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/"
set "ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/"
call npx electron-builder --win nsis
if errorlevel 1 (
  popd >nul
  goto :fail
)

set "SETUP_EXE="
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -Path '%DESKTOP_DIR%\dist' -Filter '*Setup*.exe' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"') do (
  set "SETUP_EXE=%%F"
)

if "%SETUP_EXE%"=="" (
  echo [ERROR] Desktop setup exe not found in %DESKTOP_DIR%\dist
  popd >nul
  goto :fail
)

copy /Y "%SETUP_EXE%" "%EXE_DST%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy setup exe to output.
  popd >nul
  goto :fail
)
popd >nul

echo [STEP 5/5] Done.
echo.
echo APK : %APK_DST%
echo EXE : %EXE_DST%
echo.
echo [OK] One-click packaging completed.
goto :done

:help
echo Usage:
echo   package_all.bat
echo.
echo Output files:
echo   output\SmsSyncMobile.apk
echo   output\SmsSyncSetup.exe
exit /b 0

:fail
echo.
echo [ERROR] Packaging failed. Check logs above.
set "EXITCODE=1"
goto :exit

:done
set "EXITCODE=0"

:exit
popd >nul
endlocal & exit /b %EXITCODE%
