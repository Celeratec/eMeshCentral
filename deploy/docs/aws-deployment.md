# AWS Deployment Guide

## eCortex Auto-Deployment to AWS EC2

This guide covers setting up automatic deployment of eCortex to an AWS EC2 instance using GitHub Actions.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AWS Infrastructure Setup](#aws-infrastructure-setup)
3. [Server Preparation](#server-preparation)
4. [GitHub Configuration](#github-configuration)
5. [First Deployment](#first-deployment)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────┐     Push to main     ┌──────────────────┐
│   Developer     │ ─────────────────────▶│   GitHub Repo    │
│   Workstation   │                       │   (eCortex)      │
└─────────────────┘                       └────────┬─────────┘
                                                   │
                                          GitHub Actions
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  GitHub Actions  │
                                          │    Runner        │
                                          └────────┬─────────┘
                                                   │
                                              SSH Deploy
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                     AWS EC2 Instance                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    Docker                            │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌────────┐ │    │
│  │  │ Traefik │  │ eCortex │  │ MongoDB │  │Fail2ban│ │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Flow

1. Developer pushes changes to `main` branch
2. GitHub Actions workflow triggers
3. Workflow validates deployment files
4. Workflow connects to EC2 via SSH
5. New files are uploaded and extracted
6. Docker Compose restarts services
7. Health checks verify deployment
8. Notifications sent (optional)

---

## AWS Infrastructure Setup

### Step 1: Create EC2 Instance

**Recommended Specifications:**

| Setting | Value |
|---------|-------|
| AMI | Ubuntu 22.04 LTS |
| Instance Type | t3.medium (2 vCPU, 4GB RAM) |
| Storage | 50GB gp3 SSD |
| Security Group | See below |

**Security Group Rules:**

| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | Your IP / GitHub Actions IPs | Management access |
| HTTP | 80 | 0.0.0.0/0 | Redirect to HTTPS |
| HTTPS | 443 | 0.0.0.0/0 | Web interface + agents |

> **Note:** For production, restrict SSH to specific IPs or use AWS Systems Manager Session Manager.

### Step 2: Create Elastic IP

1. Go to **EC2 → Elastic IPs**
2. Click **Allocate Elastic IP address**
3. Associate with your EC2 instance

This ensures your server IP doesn't change on restart.

### Step 3: Configure DNS

Create an A record pointing to your Elastic IP:

```
ecortex.cortalis.com → <ELASTIC_IP>
```

Wait for DNS propagation (usually 5-15 minutes).

### Step 4: Create IAM User for Backups (Optional)

If you want S3 backups:

1. Go to **IAM → Users → Create User**
2. Name: `ecortex-backup`
3. Attach policy: `AmazonS3FullAccess` (or create a restricted policy)
4. Create access keys and save them securely

---

## Server Preparation

### Option A: Automated Setup (Recommended)

SSH into your EC2 instance and run:

```bash
# Download and run setup script
curl -sSL https://raw.githubusercontent.com/Celeratec/eCortex/main/deploy/scripts/server-setup.sh | sudo bash
```

This script will:
- Update the system
- Install Docker and Docker Compose
- Configure firewall (UFW)
- Set up fail2ban
- Create deployment user and directories
- Generate SSH keys for GitHub Actions

### Option B: Manual Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Create deployment directory
sudo mkdir -p /opt/ecortex
sudo chown $USER:$USER /opt/ecortex

# Clone repository
git clone https://github.com/Celeratec/eCortex.git /opt/ecortex/repo
cp -r /opt/ecortex/repo/deploy/* /opt/ecortex/deploy/

# Run initial setup
cd /opt/ecortex/deploy
chmod +x setup.sh
./setup.sh

# Configure environment
nano .env  # Set MESHCENTRAL_HOSTNAME and ACME_EMAIL

# Start services
docker compose up -d
```

### Generate SSH Key for GitHub Actions

```bash
# Generate key pair
ssh-keygen -t ed25519 -f ~/.ssh/github_deploy -N "" -C "github-actions-deploy"

# Add public key to authorized_keys
cat ~/.ssh/github_deploy.pub >> ~/.ssh/authorized_keys

# Display private key (copy this for GitHub Secret)
cat ~/.ssh/github_deploy
```

---

## GitHub Configuration

### Required Secrets

Go to **Repository → Settings → Secrets and variables → Actions** and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_EC2_HOST` | `12.34.56.78` | Your EC2 Elastic IP or hostname |
| `AWS_EC2_USER` | `ubuntu` or `ecortex` | SSH username |
| `AWS_EC2_SSH_KEY` | `-----BEGIN OPENSSH...` | Private SSH key (entire content) |
| `DEPLOY_PATH` | `/opt/ecortex` | Path on server |
| `ECORTEX_HOSTNAME` | `ecortex.cortalis.com` | Your domain (for health checks) |

### Optional Secrets

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/...` | Slack notifications |
| `DISCORD_WEBHOOK_URL` | `https://discord.com/api/webhooks/...` | Discord notifications |

### Adding the SSH Key

1. Copy the **entire** private key including headers:
   ```
   -----BEGIN OPENSSH PRIVATE KEY-----
   ...key content...
   -----END OPENSSH PRIVATE KEY-----
   ```

2. In GitHub, create secret `AWS_EC2_SSH_KEY`
3. Paste the entire key

---

## First Deployment

### Verify Server is Ready

```bash
# SSH into server
ssh ubuntu@<your-ec2-ip>

# Check Docker is running
docker --version
docker compose version

# Check deployment directory exists
ls -la /opt/ecortex/

# Verify .env is configured
cat /opt/ecortex/deploy/.env | grep -E "HOSTNAME|EMAIL"
```

### Trigger Deployment

Option 1: **Push to main branch**
```bash
git add .
git commit -m "Deploy eCortex"
git push origin main
```

Option 2: **Manual trigger**
1. Go to **Actions** tab in GitHub
2. Select **Deploy to AWS** workflow
3. Click **Run workflow**
4. Select branch and environment
5. Click **Run workflow**

### Monitor Deployment

1. Go to **Actions** tab
2. Click on the running workflow
3. Expand each step to see logs

### Verify Deployment

```bash
# SSH into server
ssh ubuntu@<your-ec2-ip>

# Check containers are running
docker compose -f /opt/ecortex/deploy/docker-compose.yml ps

# Check logs
docker compose -f /opt/ecortex/deploy/docker-compose.yml logs -f

# Test web interface
curl -I https://ecortex.cortalis.com
```

---

## Monitoring & Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f meshcentral

# Last 100 lines
docker compose logs --tail=100
```

### Service Management

```bash
# Stop all services
docker compose down

# Start all services
docker compose up -d

# Restart specific service
docker compose restart meshcentral

# Update images
docker compose pull
docker compose up -d
```

### Backups

Automatic backups are stored in `/opt/ecortex/deploy/backups/` (deployment backups) and Docker volumes for data.

**Manual backup:**
```bash
# Backup MongoDB
docker exec meshcentral-mongodb mongodump --out /data/backup
docker cp meshcentral-mongodb:/data/backup ./mongodb-backup-$(date +%Y%m%d)

# Backup eCortex data volume
docker run --rm -v meshcentral-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/meshcentral-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Updates

The deployment workflow automatically:
1. Backs up current deployment
2. Pulls latest Docker images
3. Restarts services
4. Runs health checks

For manual updates:
```bash
cd /opt/ecortex/deploy
git pull
docker compose pull
docker compose up -d
```

---

## Troubleshooting

### Deployment Fails: SSH Connection

**Symptoms:** `ssh: connect to host ... port 22: Connection timed out`

**Solutions:**
1. Verify EC2 Security Group allows SSH from GitHub Actions IPs
2. Check EC2 instance is running
3. Verify SSH key is correct in GitHub Secrets

### Deployment Fails: Permission Denied

**Symptoms:** `Permission denied (publickey)`

**Solutions:**
1. Verify SSH public key is in `~/.ssh/authorized_keys` on server
2. Check SSH key format in GitHub Secrets (must include headers)
3. Verify `AWS_EC2_USER` matches actual username

### Services Won't Start

**Symptoms:** Containers exit immediately

**Solutions:**
```bash
# Check container logs
docker compose logs meshcentral

# Verify config.json is valid
cat /opt/ecortex/deploy/config.json | jq .

# Check .env values
cat /opt/ecortex/deploy/.env
```

### Certificate Issues

**Symptoms:** HTTPS not working, certificate errors

**Solutions:**
1. Verify DNS is pointing to correct IP
2. Check Traefik logs: `docker compose logs traefik`
3. Verify Let's Encrypt rate limits not exceeded
4. Check port 80 is accessible (required for HTTP challenge)

### Health Check Fails

**Symptoms:** Deployment succeeds but health check fails

**Solutions:**
1. Allow more time for services to start
2. Check if MongoDB is healthy first
3. Verify `MESHCENTRAL_HOSTNAME` in .env matches actual domain

### Rollback

If a deployment fails and needs rollback:

```bash
# SSH into server
cd /opt/ecortex

# List available backups
ls -la backups/

# Restore from backup
cp -r backups/deploy-YYYYMMDD-HHMMSS/* deploy/

# Restart services
cd deploy
docker compose down
docker compose up -d
```

---

## Security Considerations

### SSH Access

- Use SSH keys only (no passwords)
- Restrict Security Group to known IPs when possible
- Consider using AWS Systems Manager Session Manager instead of SSH
- Rotate SSH keys periodically

### Secrets Management

- Never commit secrets to repository
- Use GitHub Secrets for all sensitive values
- Rotate secrets periodically
- Use AWS Secrets Manager for production

### Network Security

- All traffic is encrypted (HTTPS/TLS)
- MongoDB is not exposed externally
- Fail2ban protects against brute force
- UFW firewall restricts access

---

## Quick Reference

### GitHub Secrets Required

```
AWS_EC2_HOST=<your-elastic-ip>
AWS_EC2_USER=ubuntu
AWS_EC2_SSH_KEY=<private-key>
DEPLOY_PATH=/opt/ecortex
ECORTEX_HOSTNAME=ecortex.cortalis.com
```

### Useful Commands

```bash
# Check deployment status
docker compose ps

# View logs
docker compose logs -f

# Restart services
docker compose restart

# Manual deploy
docker compose pull && docker compose up -d

# Check disk space
df -h

# Check memory
free -m
```

### Support

- [eCortex Server Deployment Guide](ecortex-deploy.md)
- [NinjaOne Integration Guide](ecortex-ninjaone.md)
- [Upstream MeshCentral Docs](https://meshcentral.com/docs/)
