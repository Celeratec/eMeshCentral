# Technician Quick Start Guide

## eCortex Backup Remote Access

Quick reference for Cortalis technicians using eCortex as a backup remote access tool.

---

## ⚠️ When to Use eCortex

eCortex is a **BACKUP** tool. Use it only when:

| ❌ This Fails | ✅ Use eCortex |
|---------------|-------------------|
| NinjaRemote | ✅ |
| RDP (blocked) | ✅ |
| RustDesk/eRemote | ✅ |
| Need browser-only | ✅ |

**Always try NinjaRemote first!**

---

## 🔑 Logging In

1. Go to: `https://mesh.cortalis.com`
2. Enter your credentials
3. Complete MFA (required)

> 💡 **Tip**: Save the URL as a bookmark for quick access

---

## 🔍 Finding a Device

### Method 1: From NinjaOne (Preferred)

1. Open device in NinjaOne
2. Find **eCortex Device Link** in custom fields
3. Click the link → Opens directly to device

### Method 2: Search in eCortex

1. Use search bar at top
2. Search format: `CLIENTCODE-HOSTNAME`
3. Examples:
   - `ACME-WS001`
   - `CONTOSO-DC01`

---

## 🖥️ Starting a Remote Session

1. Click on the device
2. Choose session type:

| Icon | Type | Use For |
|------|------|---------|
| 🖥️ | Desktop | Full remote control |
| 📟 | Terminal | Command line only |
| 📁 | Files | File transfer |

3. Wait for connection (may take a few seconds)

---

## 🖱️ Desktop Controls

| Action | How |
|--------|-----|
| Full Screen | Click ⛶ icon |
| Ctrl+Alt+Del | Use toolbar button |
| Clipboard | Auto-syncs (or use menu) |
| File Transfer | Drag & drop or Files tab |

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Alt+Enter` | Toggle full screen |
| `Ctrl+Shift+C` | Copy to clipboard |
| `Ctrl+Shift+V` | Paste from clipboard |

---

## 📋 Session Best Practices

1. **Document usage** - Note in ticket when using eCortex
2. **Add session reason** - When prompted
3. **Close properly** - Don't leave sessions open
4. **Report issues** - If eCortex fails, inform admin

---

## 🚨 Troubleshooting

### Can't Connect to Device

1. Check if device is online in NinjaOne
2. Verify agent status in device details
3. Try refreshing the page
4. Ask admin to check agent health

### Slow/Laggy Session

1. Reduce quality: Settings → Quality → Low
2. Disable wallpaper on remote
3. Check your internet connection

### MFA Not Working

1. Verify time on your phone is correct
2. Try backup codes if available
3. Contact admin to reset MFA

---

## 🆘 Getting Help

| Issue | Contact |
|-------|---------|
| Can't log in | Admin/IT Manager |
| Device not showing | Admin (check agent) |
| Session issues | Try refresh, then escalate |

---

## 📱 Mobile Access

eCortex works in mobile browsers:
1. Navigate to `https://mesh.cortalis.com`
2. Log in with credentials + MFA
3. Search for device
4. Touch-friendly interface available

---

## ✅ Quick Checklist

Before starting an eCortex session:

- [ ] NinjaRemote tried first?
- [ ] Device online in NinjaOne?
- [ ] Ticket open/documented?
- [ ] Customer aware of session?

After session:

- [ ] Session closed properly?
- [ ] Ticket notes updated?
- [ ] Any issues reported?
