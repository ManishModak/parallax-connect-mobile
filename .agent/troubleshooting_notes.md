# Troubleshooting Notes

## MAC Randomization Issue

**Date**: 2025-12-02
**Reporter**: User
**Status**: Documented

### Issue

Intermittent local connection failures due to random MAC addresses on mobile devices.

### Root Cause

Modern Android/iOS devices randomize MAC addresses for privacy, which can occasionally cause network routing issues between phone and server on local WiFi.

### Current Solution

Users should disable WiFi MAC randomization in their phone WiFi settings:

- **Android**: Settings → WiFi → Network → Advanced → Privacy → Use device MAC
- **iOS**: Settings → WiFi → Network Info → Disable "Private Wi-Fi Address"

### Documentation Updated

- ✅ `SERVER_SETUP.md` - Added comprehensive troubleshooting section
- ✅ `README.md` - Added quick reference link
- ✅ `config_screen.dart` - Enhanced error messages with mode-specific hints

### TODO: Future Improvements

- [ ] Add network diagnostics tool in app (ping server, check subnet, etc.)
- [ ] Auto-detect and suggest MAC randomization as potential issue
- [ ] Consider mDNS/Bonjour for automatic local server discovery
- [ ] Add "Test Connection" button that provides detailed diagnostic info
