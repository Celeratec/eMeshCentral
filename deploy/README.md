# eCortex Deployment - Cortalis Backup Remote Access

Production deployment files for eCortex as a backup remote access system, deployed and managed via NinjaOne.

## 📋 Overview

eCortex serves as a **secondary, technician-initiated fallback** when:
- NinjaRemote fails
- RDP is blocked
- RustDesk is unavailable
- Browser-only emergency access is required

**eCortex does NOT replace NinjaOne** - NinjaOne remains the system of record.

## 📁 Directory Structure

```
deploy/
├── docker-compose.yml          # Production container orchestration
├── config.json                 # eCortex server configuration
├── env.example                 # Environment variables template
├── setup.sh                    # Automated setup script
├── init-mongo.js               # MongoDB initialization
├── fail2ban/
│   ├── jail.local              # Fail2ban configuration
│   └── filter.d/
│       ├── traefik-auth.conf   # Auth failure detection
│       └── ecortex-auth.conf
├── ninjaone-scripts/
│   ├── Install-MeshAgent-Windows.ps1   # Windows agent deployment
│   ├── Install-MeshAgent-macOS.sh      # macOS agent deployment
│   ├── Validate-MeshAgent.ps1          # Health check script
│   └── Uninstall-MeshAgent.ps1         # Agent removal
└── docs/
    ├── ecortex-deploy.md       # Server deployment guide
    └── ecortex-ninjaone.md     # NinjaOne integration guide
```

## 🚀 Quick Start

### Prerequisites
- Ubuntu 22.04 LTS server
- Docker & Docker Compose V2
- DNS pointing `ecortex.cortalis.com` to server IP
- Ports 80 and 443 open

### Deploy

```bash
# Clone repository
git clone https://github.com/Celeratec/eCortex.git
cd eCortex/deploy

# Run setup (generates secrets)
chmod +x setup.sh
sudo ./setup.sh

# Edit configuration
sudo nano .env   # Set MESHCENTRAL_HOSTNAME and ACME_EMAIL

# Start services
docker compose up -d

# View logs
docker compose logs -f
```

### Post-Deployment

1. Access `https://ecortex.cortalis.com`
2. Create admin account (first user)
3. **Enable MFA immediately**
4. Create device groups per client
5. Generate deployment tokens for NinjaOne

## 🔒 Security Features

| Feature | Implementation |
|---------|---------------|
| TLS | Traefik + Let's Encrypt |
| MFA | Mandatory (`force2factor: true`) |
| Rate Limiting | Traefik + eCortex |
| Brute Force Protection | Fail2ban |
| Audit Logging | `authLog` enabled |
| Session Timeout | 30 min idle |
| Password Policy | 12+ chars, complexity, history |

## 📝 No Hardcoded Secrets

All sensitive values are:
- ✅ Generated at deployment time by `setup.sh`
- ✅ Stored in `.env` (gitignored)
- ✅ Injected via NinjaOne secure variables
- ❌ Never committed to repository

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [docs/ecortex-deploy.md](docs/ecortex-deploy.md) | Server deployment & administration |
| [docs/ecortex-ninjaone.md](docs/ecortex-ninjaone.md) | NinjaOne integration & workflows |

## 🔄 Token Rotation

Agent deployment tokens should be rotated:
- **Monthly**: Standard rotation
- **Immediately**: On suspected compromise
- **On termination**: When staff leave

## ✅ Definition of Done

- [x] Server survives restart without data loss
- [x] Agents reconnect automatically
- [x] Technicians authenticate with MFA
- [x] NinjaOne can deploy agents silently
- [x] Technicians can reach endpoints when NinjaRemote fails
- [x] No secrets in public repositories

## 📞 Support

For issues with this deployment:
1. Check [troubleshooting docs](docs/ecortex-deploy.md#troubleshooting)
2. Review container logs: `docker compose logs`

---

## License

eCortex is based on [MeshCentral](https://github.com/Ylianst/MeshCentral) and licensed under [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).
