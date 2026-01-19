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

### Deploy the Server

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
├── deploy/                  # Production deployment files
│   ├── docker-compose.yml   # Container orchestration
│   ├── setup.sh             # Automated setup
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
