@echo off
echo Building MediCore Desktop Application (Electron - Windows EXE)...
echo.

echo Building web assets...
npm run build

echo.
echo Building Electron application...
npm run electron:build:win

echo.
echo Build complete! Check the dist-electron directory for the installer.
echo The EXE installer will be in: dist-electron\MediCore Healthcare Setup X.X.X.exe
echo.
pause