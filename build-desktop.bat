@echo off
echo Building MediCore Desktop Application (Windows EXE)...
echo.

echo Checking for Rust installation...
where rustc >nul 2>nul
if %errorlevel% neq 0 (
    echo Rust not found. Installing Rust...
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    set PATH=%PATH%;%USERPROFILE%\.cargo\bin
    echo Rust installed. Please restart this script.
    pause
    exit /b 1
) else (
    echo Rust found. Proceeding with build...
)

echo.
echo Building the application...
npm run tauri:build

echo.
echo Build complete! Check these directories for the output:
echo - EXE Installer: src-tauri\target\release\bundle\nsis
echo - MSI Installer: src-tauri\target\release\bundle\msi
echo - Standalone EXE: src-tauri\target\release\
echo.
pause