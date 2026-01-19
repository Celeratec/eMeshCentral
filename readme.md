# eCortex

**Cortalis Backup Remote Access System**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## About

eCortex is Cortalis's customized deployment of MeshCentral, providing a self-hosted backup remote access system for IT technicians. It serves as a secondary fallback when primary remote tools (NinjaRemote, RDP, RustDesk) are unavailable.

### Key Features

- 🖥️ **Browser-based remote desktop** - No client software required
- 🔒 **Mandatory MFA** - All technician accounts require two-factor authentication
- 📁 **File transfer** - Upload/download files securely
- ⌨️ **Remote terminal** - Command line access to endpoints
- 🔐 **No hardcoded secrets** - All credentials generated at deployment
- 🚀 **NinjaOne integration** - Deploy agents via existing RMM policies
- ⚡ **Auto-deploy to AWS** - Push to main triggers automatic deployment

### When to Use eCortex

| Scenario | Primary Tool | eCortex |
|----------|-------------|---------|
| Remote Desktop | NinjaRemote | ✅ Backup |
| RDP Blocked | RDP | ✅ Alternative |
| RustDesk Down | eRemote | ✅ Fallback |
| Browser-Only | N/A | ✅ Primary |

**eCortex does NOT replace NinjaOne** - NinjaOne remains the system of record.

---

## Quick Start

### Option A: Auto-Deploy to AWS (Recommended)

**1. Prepare your EC2 instance:**
```bash
# SSH into fresh Ubuntu 22.04 EC2 instance
curl -sSL https://raw.githubusercontent.com/Celeratec/eCortex/main/deploy/scripts/server-setup.sh | sudo bash
```

**2. Configure GitHub Secrets:**
| Secret | Value |
|--------|-------|
| `AWS_EC2_HOST` | Your EC2 IP |
| `AWS_EC2_USER` | `ubuntu` |
| `AWS_EC2_SSH_KEY` | Private SSH key |
| `DEPLOY_PATH` | `/opt/ecortex` |

**3. Push to deploy:**
```bash
git push origin main  # Triggers automatic deployment
```

See [AWS Deployment Guide](deploy/docs/aws-deployment.md) for details.

### Option B: Manual Deploy

```bash
git clone https://github.com/Celeratec/eCortex.git
cd eCortex/deploy
chmod +x setup.sh
sudo ./setup.sh
docker compose up -d
```

### Access eCortex

Open: `https://ecortex.cortalis.com`

See [deploy/docs/ecortex-deploy.md](deploy/docs/ecortex-deploy.md) for complete deployment instructions.

---

## Documentation

| Document | Description |
|----------|-------------|
| [AWS Deployment Guide](deploy/docs/aws-deployment.md) | **Auto-deployment to AWS EC2** |
| [Server Deployment Guide](deploy/docs/ecortex-deploy.md) | Installing and configuring the eCortex server |
| [NinjaOne Integration](deploy/docs/ecortex-ninjaone.md) | Deploying agents via NinjaOne policies |
| [Technician Quick Start](deploy/docs/technician-quickstart.md) | How technicians use eCortex |

---

## Architecture

```
Technician (Browser)
       |
       | HTTPS (443)
       ↓
   [Traefik] ─── TLS/Let's Encrypt
       |
   [eCortex Server]
       |
   [MongoDB]

       ⇅ Outbound TLS (443)

   [eCortex Agent on Endpoints]
```

- **No inbound ports required** on endpoints
- Agents connect outbound to the eCortex server
- All traffic encrypted with TLS

---

## Security

| Feature | Implementation |
|---------|----------------|
| TLS | Traefik + Let's Encrypt |
| MFA | Mandatory for all users |
| Rate Limiting | Login attempt throttling |
| Brute Force | Fail2ban integration |
| Audit Logging | All sessions logged |
| Session Timeout | 30 minute idle disconnect |
| Password Policy | 12+ chars, complexity enforced |

---

## Repository Structure

```
eCortex/
├── .github/
│   └── workflows/
│       ├── deploy.yml       # Auto-deploy to AWS on push
│       └── security-scan.yml # Secret detection
├── deploy/                  # Production deployment files
│   ├── docker-compose.yml   # Container orchestration
│   ├── setup.sh             # Automated setup
│   ├── scripts/             # Server setup scripts
│   ├── ninjaone-scripts/    # Agent deployment scripts
│   └── docs/                # Deployment documentation
├── agents/                  # Agent binaries and scripts
├── public/                  # Web interface assets
├── views/                   # Handlebars templates
└── [core modules]           # Server-side JavaScript
```

---

## Based On

eCortex is a customized fork of [MeshCentral](https://github.com/Ylianst/MeshCentral), an open-source remote management platform.

- **Upstream**: [Ylianst/MeshCentral](https://github.com/Ylianst/MeshCentral)
- **Documentation**: [meshcentral.com/docs](https://meshcentral.com/docs/)

---

## License

This software is licensed under [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).

eCortex is based on MeshCentral by Ylian Saint-Hilaire.
