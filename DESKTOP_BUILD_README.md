# MediCore Desktop Application - Windows EXE Build Guide

This guide provides two methods to build the MediCore healthcare management system as a Windows desktop application: **Tauri** (recommended) and **Electron**.

## Prerequisites

### Required Software
1. **Node.js** (v16 or higher) - Already installed
2. **Rust** (for Tauri only) - Will be installed automatically
3. **Visual Studio Build Tools** (for Tauri) - Required for Rust compilation

### Optional but Recommended
- **Visual Studio 2022** with C++ build tools (for Tauri)
- **Windows SDK** (latest version)

## Quick Build Options

### Method 1: Electron (Easier, Faster)
Electron is simpler to set up and build. Use this for quick deployment.

1. **Run the automated build script:**
   ```bash
   ./build-electron.bat
   ```
2. Wait for the build process (5-15 minutes)
3. Find the EXE installer in: `dist-electron\`

### Method 2: Tauri (Smaller, More Secure)
Tauri creates smaller, more secure applications but requires Rust.

1. **Run the automated build script:**
   ```bash
   ./build-desktop.bat
   ```
2. Wait for Rust installation and compilation (may take 10-30 minutes first time)
3. Find the EXE installer in: `src-tauri\target\release\bundle\nsis\`

## Output Files

### Electron Build Output
- **Location:** `dist-electron\`
- **File:** `MediCore Healthcare Setup 1.0.0.exe`
- **Type:** NSIS installer with desktop shortcuts
- **Size:** ~150-200MB (includes Node.js runtime)

### Tauri Build Output
- **Location:** `src-tauri\target\release\bundle\nsis\`
- **File:** `MediCore_1.0.0_x64-setup.exe`
- **Type:** NSIS installer
- **Size:** ~50-80MB (smaller, no Node.js runtime)

## Application Features

Both versions include all web features:
- ✅ Patient management
- ✅ Appointment scheduling
- ✅ Pharmacy management
- ✅ Laboratory tracking
- ✅ Employee management
- ✅ Billing system
- ✅ Real-time notifications
- ✅ Secure authentication

## Development

### Electron Development
```bash
npm run electron:dev
```

### Tauri Development
```bash
npm run tauri:dev
```

Both open the application in development mode with hot reload.

## Troubleshooting

### Electron Issues

**Build Fails:**
```bash
# Clear cache and retry
npm run electron:build:win -- --publish=never
```

**App Won't Start:**
- Check if dist folder exists
- Verify electron.js is in root directory
- Check Windows Event Viewer

### Tauri Issues

**Rust Installation Fails:**
```bash
# Manual installation
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

**Build Tools Missing:**
- Install Visual Studio 2022 with "Desktop development with C++"
- Include Windows SDK 10+

**Permission Errors:**
- Run as Administrator
- Check antivirus exclusions

## System Requirements

### Minimum Requirements
- **OS:** Windows 10 (64-bit)
- **RAM:** 4GB
- **Storage:** 500MB free space
- **Internet:** Required for data sync

### Recommended Requirements
- **OS:** Windows 10/11 (64-bit)
- **RAM:** 8GB
- **Storage:** 1GB free space
- **Internet:** Stable broadband connection

## Distribution

### For Internal Use
- Share the EXE installer with clinic staff
- No additional installation requirements
- Runs as standalone Windows application

### For Commercial Distribution
- Code sign the executable for security
- Create custom installer branding
- Consider auto-update functionality

## Security Notes

- Both desktop apps include the same security measures as the web version
- Data is encrypted in transit and at rest
- User authentication required for all operations
- Regular security updates recommended

## File Structure

```
MediCore/
├── electron.js              # Electron main process
├── src-tauri/              # Tauri Rust project
│   ├── src/main.rs         # Tauri main process
│   ├── tauri.conf.json     # Tauri config
│   └── Cargo.toml          # Rust dependencies
├── dist/                   # Built web assets
├── dist-electron/          # Electron build output
└── build-*.bat            # Build scripts
```

## Support

For build issues:
1. Try Electron first (simpler)
2. Check [Electron Documentation](https://electronjs.org/)
3. Check [Tauri Documentation](https://tauri.app/)
4. Test on target Windows environments