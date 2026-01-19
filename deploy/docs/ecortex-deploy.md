# eCortex Server Deployment Guide

## Cortalis Backup Remote Access System

This guide covers deploying eCortex as a self-hosted backup remote access solution for Cortalis technicians.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Server Deployment](#server-deployment)
4. [Initial Configuration](#initial-configuration)
5. [Security Hardening](#security-hardening)
6. [Device Groups Setup](#device-groups-setup)
7. [User Management & RBAC](#user-management--rbac)
8. [Token Generation](#token-generation)
9. [Backup & Recovery](#backup--recovery)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### Purpose

eCortex serves as a **backup remote access system** when primary tools fail:

| Scenario | Primary Tool | Backup (eCortex) |
|----------|-------------|---------------------|
| Remote Desktop | NinjaRemote | ✓ |
| RDP Blocked | NinjaRemote/RDP | ✓ |
| RustDesk Down | eRemote | ✓ |
| Browser-Only Access | N/A | ✓ |

### Architecture

```
Technician (Browser/Client)
        |
        | HTTPS (443)
        |
   [Traefik] ─── TLS/Let's Encrypt
        |
   [eCortex Server]
        |
   [MongoDB]
        |
   (Persistent Volumes)

        ⇅ Outbound TLS

   [eCortex Agent on Endpoints]
```

### Key Principles

- ✅ NinjaOne remains the system of record
- ✅ Agents deployed via NinjaOne policies
- ✅ No secrets in repositories
- ✅ MFA mandatory
- ✅ Strong RBAC

---

## Prerequisites

### Server Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Storage | 40 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

### Network Requirements

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 80 | TCP | Inbound | HTTP → HTTPS redirect |
| 443 | TCP | Inbound | HTTPS (Web + WebSocket) |
| 443 | TCP | Outbound | Agent connections |

### DNS Configuration

Create an A record pointing to your server:

```
ecortex.cortalis.com → <SERVER_PUBLIC_IP>
```

---

## Server Deployment

### Step 1: Prepare the Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
docker --version
docker compose version
```

### Step 2: Clone Deployment Files

```bash
# Clone the repository
git clone https://github.com/Celeratec/eCortex.git
cd eCortex/deploy

# Or download just the deploy folder
```

### Step 3: Run Setup Script

```bash
# Make setup script executable
chmod +x setup.sh

# Run setup (generates secrets, creates config)
sudo ./setup.sh
```

### Step 4: Configure Environment

Edit the generated `.env` file:

```bash
sudo nano .env
```

**Required changes:**

```ini
# Your domain (must match DNS)
MESHCENTRAL_HOSTNAME=ecortex.cortalis.com

# Email for Let's Encrypt
ACME_EMAIL=admin@dfwmsp.com

# Timezone
TZ=America/Chicago
```

### Step 5: Deploy Services

```bash
# Start all services
docker compose up -d

# Watch logs for issues
docker compose logs -f

# Verify all containers are running
docker compose ps
```

### Step 6: Verify Deployment

1. Open `https://ecortex.cortalis.com` in browser
2. Accept the certificate (or wait for Let's Encrypt)
3. You should see the eCortex login page

---

## Initial Configuration

### Create Admin Account

1. Navigate to `https://ecortex.cortalis.com`
2. Click "Create Account" (first user becomes admin)
3. Set a strong password (min 12 chars, mixed case, numbers, symbols)
4. **Immediately enable MFA** after login

> ⚠️ **Important**: After creating the admin account, new account creation is disabled in the configuration.

### Enable MFA for Admin

1. Click your username → "My Account"
2. Under "Account Security" click "Two-Factor Authentication"
3. Choose TOTP (Google Authenticator, Authy, etc.)
4. Scan QR code and verify
5. Save backup codes securely

### Disable New Account Creation

Verify in `config.json`:

```json
"domains": {
  "": {
    "NewAccounts": false,
    ...
  }
}
```

---

## Security Hardening

### Security Checklist

| Item | Status | Notes |
|------|--------|-------|
| TLS Enabled | ✅ | Via Traefik + Let's Encrypt |
| MFA Enforced | ✅ | `force2factor: true` |
| No Anonymous Access | ✅ | `NewAccounts: false` |
| Rate Limiting | ✅ | Traefik + eCortex config |
| Session Timeout | ✅ | 30 min idle timeout |
| Audit Logging | ✅ | `authLog` configured |
| Fail2ban | ✅ | Container included |

### Password Policy

Configured in `config.json`:

```json
"passwordRequirements": {
  "min": 12,
  "max": 128,
  "upper": 1,
  "lower": 1,
  "numeric": 1,
  "nonalpha": 1,
  "reset": 90,
  "force2factor": true,
  "oldPasswordBan": 5,
  "banCommonPasswords": true
}
```

### Firewall Rules (UFW)

```bash
# Allow only necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## Device Groups Setup

### Naming Convention

Device groups should follow:

```
[CLIENT_CODE] - [TYPE]
```

Examples:
- `ACME - Workstations`
- `ACME - Servers`
- `CONTOSO - All Devices`

### Creating Device Groups

1. Go to **My Devices** → **Add Group**
2. Enter group name (e.g., `ACME - Workstations`)
3. Configure features:
   - ✅ Desktop
   - ✅ Terminal
   - ✅ Files
   - ✅ Agent Console
4. Set consent options as needed
5. Click **Create**

### Group Permissions Matrix

| Group Type | Tier 1 | Tier 2 | Admin |
|------------|--------|--------|-------|
| Client Workstations | View, Remote | Full | Full |
| Client Servers | View Only | Full | Full |
| Internal Devices | Full | Full | Full |

---

## User Management & RBAC

### User Groups

Create user groups for technicians:

1. Go to **Users** → **User Groups** → **Create**
2. Create groups:
   - `Tier1-Technicians`
   - `Tier2-Technicians`  
   - `Administrators`

### Creating Technician Accounts

1. Go to **Users** → **New Account**
2. Enter username (use email format)
3. Set temporary password
4. Assign to appropriate user group
5. User must change password and enable MFA on first login

### Permission Assignment

1. Open device group
2. Click **Permissions**
3. Add user group with appropriate rights:
   - **Tier 1**: View, Desktop, Terminal
   - **Tier 2**: Full Control
   - **Admin**: Full Control + Manage

---

## Token Generation

### Agent Invite Tokens

Tokens are used for automated agent deployment via NinjaOne.

#### Generate Token (GUI Method)

1. Open the target device group
2. Click **Add Agent** → **Install Options**
3. Copy the installation command/link
4. Extract the `meshinstall` parameter

#### Generate Token (API Method)

```bash
# Using MeshCtrl
meshctrl --url wss://ecortex.cortalis.com \
         --loginuser admin \
         --loginpass 'password' \
         AddAgentInviteCode \
         --group "mesh//default//[GROUP_ID]" \
         --hours 24
```

### Token Security

| Requirement | Implementation |
|-------------|----------------|
| No hardcoded tokens | ✅ NinjaOne secure variables |
| Token expiration | ✅ 24-hour default |
| Per-group tokens | ✅ Unique per device group |
| Rotation | Manual, on schedule or compromise |

### Token Rotation Schedule

1. **Monthly**: Rotate all active deployment tokens
2. **Immediately**: If token is suspected compromised
3. **On staff departure**: Rotate all tokens

---

## Backup & Recovery

### Automatic Backups

Configured in `config.json`:

```json
"autoBackup": {
  "backupIntervalHours": 24,
  "keepLastDaysBackup": 30,
  "backupPath": "/opt/meshcentral/meshcentral-backups"
}
```

### Manual Backup

```bash
# Stop services
docker compose stop meshcentral

# Backup volumes
docker run --rm \
  -v meshcentral-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/meshcentral-data-$(date +%Y%m%d).tar.gz -C /data .

# Backup MongoDB
docker compose exec mongodb mongodump \
  --username=$MONGO_ROOT_USER \
  --password=$MONGO_ROOT_PASSWORD \
  --out=/tmp/backup

# Start services
docker compose start meshcentral
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore volumes
docker run --rm \
  -v meshcentral-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/meshcentral-data-YYYYMMDD.tar.gz -C /data

# Restore MongoDB
docker compose up -d mongodb
docker compose exec mongodb mongorestore \
  --username=$MONGO_ROOT_USER \
  --password=$MONGO_ROOT_PASSWORD \
  /tmp/backup

# Start all services
docker compose up -d
```

### Recovery Testing

**Quarterly**: Test restore procedure to verify backups are valid.

---

## Troubleshooting

### Common Issues

#### Cannot Access Web Interface

```bash
# Check container status
docker compose ps

# Check Traefik logs
docker compose logs traefik

# Check eCortex logs
docker compose logs meshcentral

# Verify DNS resolution
nslookup ecortex.cortalis.com
```

#### Agents Not Connecting

1. Verify server is reachable from endpoint
2. Check firewall allows outbound 443
3. Verify agent service is running
4. Check agent logs on endpoint

#### MongoDB Connection Issues

```bash
# Check MongoDB status
docker compose logs mongodb

# Test connection
docker compose exec mongodb mongosh \
  --username $MONGO_ROOT_USER \
  --password $MONGO_ROOT_PASSWORD
```

#### Certificate Issues

```bash
# Check Let's Encrypt status
docker compose exec traefik cat /letsencrypt/acme.json

# Force certificate renewal
docker compose restart traefik
```

### Log Locations

| Component | Log Location |
|-----------|--------------|
| Traefik | `docker compose logs traefik` |
| eCortex | `docker compose logs meshcentral` |
| MongoDB | `docker compose logs mongodb` |
| Fail2ban | `docker compose logs fail2ban` |
| Auth Log | `/opt/meshcentral/meshcentral-data/auth.log` |

### Support Resources

- [Upstream Documentation](https://meshcentral.com/docs/) (technical reference)

---

## Maintenance

### Weekly Tasks

- [ ] Review auth.log for suspicious activity
- [ ] Check disk space usage
- [ ] Verify backups are completing

### Monthly Tasks

- [ ] Rotate agent deployment tokens
- [ ] Review and update user access
- [ ] Apply security updates
- [ ] Review failed login attempts

### Quarterly Tasks

- [ ] Test backup restoration
- [ ] Review and update documentation
- [ ] Security audit of configurations
- [ ] Update container images

---

## Definition of Done

eCortex is production-ready when:

- [x] Server survives restart without data loss
- [x] Agents reconnect automatically
- [x] Technicians authenticate with MFA
- [x] NinjaOne can deploy agents silently
- [x] Technicians can reach endpoints when NinjaRemote is unavailable
- [x] No secrets exist in public repositories
