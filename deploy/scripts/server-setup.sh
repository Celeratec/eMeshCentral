#!/bin/bash
# =============================================================================
# eCortex AWS Server Initial Setup Script
# =============================================================================
# Run this script ONCE on a fresh Ubuntu 22.04 EC2 instance to prepare it
# for eCortex deployment.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Celeratec/eCortex/main/deploy/scripts/server-setup.sh | sudo bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/Celeratec/eCortex/main/deploy/scripts/server-setup.sh
#   chmod +x server-setup.sh
#   sudo ./server-setup.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ECORTEX_USER="${ECORTEX_USER:-ecortex}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/ecortex}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/Celeratec/eCortex.git}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  eCortex AWS Server Setup"
echo "  Cortalis Backup Remote Access"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    log_error "Cannot detect OS"
    exit 1
fi

log_info "Detected OS: $OS $VERSION"

# =============================================================================
# Step 1: System Updates
# =============================================================================
log_info "Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# =============================================================================
# Step 2: Install Dependencies
# =============================================================================
log_info "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq \
    unzip \
    htop \
    fail2ban \
    ufw

# =============================================================================
# Step 3: Install Docker
# =============================================================================
if command -v docker &> /dev/null; then
    log_info "Docker already installed: $(docker --version)"
else
    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    log_success "Docker installed: $(docker --version)"
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker

# =============================================================================
# Step 4: Create eCortex User
# =============================================================================
if id "$ECORTEX_USER" &>/dev/null; then
    log_info "User $ECORTEX_USER already exists"
else
    log_info "Creating user: $ECORTEX_USER"
    useradd -m -s /bin/bash "$ECORTEX_USER"
    usermod -aG docker "$ECORTEX_USER"
fi

# =============================================================================
# Step 5: Setup Directory Structure
# =============================================================================
log_info "Setting up directory structure..."

mkdir -p "$DEPLOY_PATH"/{deploy,backups,logs}
chown -R "$ECORTEX_USER:$ECORTEX_USER" "$DEPLOY_PATH"
chmod 750 "$DEPLOY_PATH"

# =============================================================================
# Step 6: Clone Repository
# =============================================================================
log_info "Cloning eCortex repository..."

if [ -d "$DEPLOY_PATH/.git" ]; then
    log_info "Repository already exists, pulling latest..."
    cd "$DEPLOY_PATH"
    sudo -u "$ECORTEX_USER" git pull
else
    sudo -u "$ECORTEX_USER" git clone "$GITHUB_REPO" "$DEPLOY_PATH/repo"
    # Copy deploy files
    cp -r "$DEPLOY_PATH/repo/deploy/"* "$DEPLOY_PATH/deploy/"
    chown -R "$ECORTEX_USER:$ECORTEX_USER" "$DEPLOY_PATH"
fi

# =============================================================================
# Step 7: Configure Firewall
# =============================================================================
log_info "Configuring firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

log_success "Firewall configured"
ufw status

# =============================================================================
# Step 8: Configure Fail2ban
# =============================================================================
log_info "Configuring fail2ban..."

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# =============================================================================
# Step 9: Setup SSH for GitHub Actions
# =============================================================================
log_info "Setting up SSH directory for deployments..."

ECORTEX_HOME=$(eval echo ~$ECORTEX_USER)
mkdir -p "$ECORTEX_HOME/.ssh"
chmod 700 "$ECORTEX_HOME/.ssh"
touch "$ECORTEX_HOME/.ssh/authorized_keys"
chmod 600 "$ECORTEX_HOME/.ssh/authorized_keys"
chown -R "$ECORTEX_USER:$ECORTEX_USER" "$ECORTEX_HOME/.ssh"

# =============================================================================
# Step 10: Create systemd service for auto-restart
# =============================================================================
log_info "Creating systemd service..."

cat > /etc/systemd/system/ecortex.service << EOF
[Unit]
Description=eCortex Remote Access Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_PATH/deploy
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$ECORTEX_USER
Group=$ECORTEX_USER

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ecortex.service

# =============================================================================
# Step 11: Generate deployment SSH key
# =============================================================================
log_info "Generating deployment SSH key..."

DEPLOY_KEY_PATH="$ECORTEX_HOME/.ssh/deploy_key"
if [ ! -f "$DEPLOY_KEY_PATH" ]; then
    sudo -u "$ECORTEX_USER" ssh-keygen -t ed25519 -f "$DEPLOY_KEY_PATH" -N "" -C "ecortex-deploy"
    cat "$DEPLOY_KEY_PATH.pub" >> "$ECORTEX_HOME/.ssh/authorized_keys"
    log_success "Deployment key generated"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
echo "  eCortex Server Setup Complete!"
echo "=========================================="
echo ""
log_success "Server is ready for eCortex deployment"
echo ""
echo "Next Steps:"
echo ""
echo "1. Configure eCortex:"
echo "   cd $DEPLOY_PATH/deploy"
echo "   sudo -u $ECORTEX_USER ./setup.sh"
echo ""
echo "2. Edit environment variables:"
echo "   nano $DEPLOY_PATH/deploy/.env"
echo ""
echo "3. Start eCortex:"
echo "   cd $DEPLOY_PATH/deploy"
echo "   docker compose up -d"
echo ""
echo "4. Add this SSH key to GitHub Secrets (AWS_EC2_SSH_KEY):"
echo "   cat $DEPLOY_KEY_PATH"
echo ""
echo "5. Configure GitHub Secrets:"
echo "   - AWS_EC2_HOST: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<your-server-ip>')"
echo "   - AWS_EC2_USER: $ECORTEX_USER"
echo "   - DEPLOY_PATH: $DEPLOY_PATH"
echo ""
echo "=========================================="
