# NinjaOne + eCortex Integration Guide

## Cortalis Backup Remote Access System

This guide covers integrating eCortex with NinjaOne for automated agent deployment and technician access.

---

## Table of Contents

1. [Overview](#overview)
2. [NinjaOne Custom Fields Setup](#ninjaone-custom-fields-setup)
3. [Agent Deployment](#agent-deployment)
4. [Technician Workflow](#technician-workflow)
5. [Monitoring & Validation](#monitoring--validation)
6. [Offboarding Process](#offboarding-process)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         NinjaOne                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Organization │  │ Custom Fields│  │ Deployment Scripts   │  │
│  │   (Client)   │──│ (Secure Vars)│──│ (Install-MeshAgent)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         eCortex                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Device Group │  │  MeshAgent   │  │   Remote Session     │  │
│  │ (Per Client) │──│ (On Endpoint)│──│  (Desktop/Terminal)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Principles

- **No Hardcoded Secrets**: All tokens via NinjaOne secure variables
- **Naming Convention**: `CLIENTCODE-HOSTNAME`
- **Visibility Rules**: Technicians only see authorized devices
- **NinjaOne Integration**: Click-to-connect from NinjaOne

---

## NinjaOne Custom Fields Setup

### Required Custom Fields

Create these custom fields in NinjaOne Admin:

#### Organization-Level Fields

| Field Name | Type | Purpose |
|------------|------|---------|
| `meshcentral_server_url` | Text | eCortex server URL |
| `meshcentral_invite_token` | Secure | Agent installation token |
| `meshcentral_group_id` | Text | Device group ID |
| `client_code` | Text | Short client identifier |

#### Device-Level Fields

| Field Name | Type | Purpose |
|------------|------|---------|
| `meshcentral_device_url` | Text/URL | Direct link to device in eCortex |
| `meshcentral_agent_status` | Text | Agent health status |
| `meshcentral_agent_version` | Text | Installed agent version |
| `meshcentral_last_check` | Date/Time | Last validation check |

### Creating Custom Fields in NinjaOne

1. Go to **Administration** → **Devices** → **Global Custom Fields**
2. Click **Add** → **Create new field**
3. Configure each field:

**meshcentral_server_url**
```
Name: meshcentral_server_url
Label: eCortex Server URL
Type: Text
Scope: Organization
Technician Permission: Read Only
Default Value: https://mesh.cortalis.com
```

**meshcentral_invite_token**
```
Name: meshcentral_invite_token  
Label: eCortex Invite Token
Type: Secure Text
Scope: Organization
Technician Permission: None (Hidden)
```

**client_code**
```
Name: client_code
Label: Client Code
Type: Text
Scope: Organization
Technician Permission: Read Only
```

**meshcentral_device_url**
```
Name: meshcentral_device_url
Label: eCortex Device Link
Type: URL
Scope: Device
Technician Permission: Read Only
```

---

## Agent Deployment

### Step 1: Generate Installation Token

In eCortex:

1. Navigate to target device group
2. Click **Add Agent** → **Invite Link**
3. Set expiration (24-48 hours recommended)
4. Copy the installation link

Extract the token portion:
```
https://mesh.cortalis.com/?installcli=4&meshinstall=XXXXXX
                                                  ^^^^^^
                                            This is the token
```

### Step 2: Configure NinjaOne Organization

1. Open the client organization in NinjaOne
2. Go to **Details** → **Custom Fields**
3. Set values:
   - `meshcentral_server_url`: `https://mesh.cortalis.com`
   - `meshcentral_invite_token`: (paste token from Step 1)
   - `meshcentral_group_id`: (group ID from eCortex)
   - `client_code`: `ACME` (short code for client)

### Step 3: Deploy Scripts to NinjaOne

#### Upload Scripts

1. Go to **Administration** → **Library** → **Automation**
2. Click **Add** → **New Script**
3. Upload each script:

| Script | File | Purpose |
|--------|------|---------|
| Install MeshAgent (Windows) | `Install-MeshAgent-Windows.ps1` | Windows agent install |
| Install MeshAgent (macOS) | `Install-MeshAgent-macOS.sh` | macOS agent install |
| Validate MeshAgent | `Validate-MeshAgent.ps1` | Health check |
| Uninstall MeshAgent | `Uninstall-MeshAgent.ps1` | Agent removal |

#### Script Configuration

For **Install-MeshAgent-Windows.ps1**:
```
Name: Install MeshAgent (Windows)
Type: PowerShell
Architecture: All
Categories: Remote Access, Installation
Parameters: None (uses custom fields)
Run As: System
Timeout: 300 seconds
```

### Step 4: Create Deployment Policy

1. Go to **Administration** → **Policies**
2. Create or edit policy for client
3. Under **Scripts** → **Scheduled Scripts**
4. Add "Install MeshAgent (Windows)"
5. Set schedule: Run once on policy application

### Step 5: Apply Policy to Client

1. Open client organization
2. Assign the policy with MeshAgent deployment
3. Agents will install automatically

---

## Technician Workflow

### When to Use eCortex

Use eCortex as a **backup** when:

1. ❌ NinjaRemote fails to connect
2. ❌ RDP is blocked by firewall/policy
3. ❌ RustDesk (eRemote) is unavailable
4. ✅ Emergency browser-only access needed

### Connecting via NinjaOne Custom Field

**Preferred Method:**

1. Open device in NinjaOne
2. Look for **eCortex Device Link** custom field
3. Click the link to open eCortex directly to that device
4. Authenticate with eCortex credentials + MFA
5. Start remote session

### Connecting via eCortex Directly

1. Open `https://mesh.cortalis.com`
2. Log in with credentials + MFA
3. Search for device: `CLIENTCODE-HOSTNAME`
4. Click device → Select session type (Desktop/Terminal/Files)

### Session Types Available

| Session Type | Use Case |
|--------------|----------|
| Desktop | Full remote desktop control |
| Terminal | Command line access |
| Files | File transfer/management |
| Events | View device events |
| Console | Agent diagnostics |

### Best Practices for Technicians

1. **Always try NinjaRemote first** - eCortex is backup only
2. **Log your sessions** - Document in ticket when using eCortex
3. **Use named sessions** - Add reason when starting session
4. **Close sessions properly** - Don't leave sessions open
5. **Report issues** - If eCortex doesn't work, report to admin

---

## Monitoring & Validation

### Automated Health Checks

Deploy `Validate-MeshAgent.ps1` as a scheduled condition:

1. Go to **Administration** → **Policies**
2. Add **Scheduled Scripts** → `Validate MeshAgent`
3. Schedule: Weekly or Daily
4. Output updates `meshcentral_agent_status` field

### Custom Monitoring Condition

Create a condition based on agent status:

```
Condition: MeshAgent Not Healthy
Trigger: Script Output
Script: Validate MeshAgent
Condition: Exit code != 0
Severity: Warning
Action: Create ticket / Alert
```

### Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| Healthy | Agent running, connected | None |
| Degraded | Service issues | Restart service |
| Not Installed | Agent missing | Re-run install |

---

## Offboarding Process

### Client Offboarding

When removing a client from service:

#### Step 1: Remove from eCortex

1. Log in to eCortex as admin
2. Navigate to client's device group
3. Select all devices
4. Click **Delete** (removes from eCortex inventory)
5. Delete the device group

#### Step 2: Uninstall Agents via NinjaOne

1. Create automation job in NinjaOne
2. Target all client devices
3. Run `Uninstall-MeshAgent.ps1`
4. Verify removal completes

#### Step 3: Revoke Tokens

1. In NinjaOne, clear organization custom fields:
   - `meshcentral_invite_token` → (blank)
   - `meshcentral_group_id` → (blank)

#### Step 4: Remove User Access

1. In eCortex, remove technician access to device group
2. Or delete group entirely

### Device Offboarding

When decommissioning a single device:

1. Run `Uninstall-MeshAgent.ps1` on device
2. In eCortex, delete the device record
3. Clear NinjaOne `meshcentral_device_url` field

---

## Troubleshooting

### Agent Not Installing

**Symptoms:**
- Script runs but agent doesn't appear in eCortex
- Service not created

**Checks:**
1. Verify custom fields are set in NinjaOne organization
2. Check token hasn't expired
3. Verify network connectivity to eCortex server
4. Review script output in NinjaOne activity log

**Solution:**
```powershell
# Manual test on endpoint
$env:MESHCENTRAL_SERVER_URL = "https://mesh.cortalis.com"
$env:MESHCENTRAL_INVITE_TOKEN = "your-token-here"
.\Install-MeshAgent-Windows.ps1 -Verbose
```

### Agent Shows Offline in eCortex

**Symptoms:**
- Agent installed but shows offline
- Was working previously

**Checks:**
1. Service status: `Get-Service MeshAgent`
2. Process running: `Get-Process MeshAgent`
3. Network connectivity to server port 443
4. Server SSL certificate valid

**Solution:**
```powershell
# Restart agent service
Restart-Service MeshAgent

# Or run validation script
.\Validate-MeshAgent.ps1
```

### Token Expired During Deployment

**Symptoms:**
- Deployments failing with auth errors
- New devices not registering

**Solution:**
1. Generate new token in eCortex
2. Update NinjaOne organization's `meshcentral_invite_token`
3. Re-run deployment on affected devices

### Custom Field Not Populated

**Symptoms:**
- `meshcentral_device_url` is blank
- Scripts complete but field empty

**Checks:**
- Verify NinjaOne API/scripting can write to custom fields
- Check script permissions in NinjaOne

**Solution:**
Manually populate or update script to use correct NinjaOne API syntax.

---

## Quick Reference

### NinjaOne Custom Fields Summary

| Field | Level | Purpose |
|-------|-------|---------|
| meshcentral_server_url | Org | Server URL |
| meshcentral_invite_token | Org | Install token (secure) |
| meshcentral_group_id | Org | Device group |
| client_code | Org | Short client ID |
| meshcentral_device_url | Device | Direct device link |
| meshcentral_agent_status | Device | Health status |

### Script Reference

| Script | Purpose | Run As |
|--------|---------|--------|
| Install-MeshAgent-Windows.ps1 | Install agent | System |
| Install-MeshAgent-macOS.sh | Install agent | Root |
| Validate-MeshAgent.ps1 | Health check | System |
| Uninstall-MeshAgent.ps1 | Remove agent | System |

### Device Naming Convention

```
CLIENTCODE-HOSTNAME

Examples:
ACME-WS001
CONTOSO-DC01
INITECH-LAPTOP42
```

### Support Escalation

1. **Level 1**: Check agent status, restart service
2. **Level 2**: Re-deploy agent, check network
3. **Level 3**: Contact eCortex admin for server issues
