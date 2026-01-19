#!/bin/bash
# =============================================================================
# eCortex Production Setup Script
# Cortalis Backup Remote Access System
# =============================================================================
# This script prepares the environment for eCortex deployment
# Run with: sudo ./setup.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# STEP 1: Check Prerequisites
# =============================================================================
log_info "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    log_info "Run: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose V2 is not installed."
    exit 1
fi

log_info "Prerequisites check passed."

# =============================================================================
# STEP 2: Create .env file from template
# =============================================================================
if [[ ! -f .env ]]; then
    log_info "Creating .env file from template..."
    cp env.example .env
    
    # Generate secure random values
    log_info "Generating secure random values..."
    
    # Generate MongoDB passwords
    MONGO_ROOT_PASS=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
    MONGO_APP_PASS=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
    
    # Generate eCortex keys
    SESSION_KEY=$(openssl rand -base64 64 | tr -d '/+=' | cut -c1-64)
    DB_ENCRYPT_KEY=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
    
    # Update .env file
    sed -i "s/MONGO_ROOT_PASSWORD=CHANGE_ME_GENERATE_STRONG_PASSWORD/MONGO_ROOT_PASSWORD=$MONGO_ROOT_PASS/" .env
    sed -i "s/MONGO_APP_PASSWORD=CHANGE_ME_GENERATE_STRONG_PASSWORD/MONGO_APP_PASSWORD=$MONGO_APP_PASS/" .env
    sed -i "s/MESHCENTRAL_SESSION_KEY=CHANGE_ME_GENERATE_64_CHAR_RANDOM_STRING/MESHCENTRAL_SESSION_KEY=$SESSION_KEY/" .env
    sed -i "s/MESHCENTRAL_DB_ENCRYPT_KEY=CHANGE_ME_GENERATE_32_CHAR_RANDOM_STRING/MESHCENTRAL_DB_ENCRYPT_KEY=$DB_ENCRYPT_KEY/" .env
    
    log_warn ".env file created with generated secrets."
    log_warn "IMPORTANT: Edit .env and set:"
    log_warn "  - MESHCENTRAL_HOSTNAME (your domain)"
    log_warn "  - ACME_EMAIL (for Let's Encrypt)"
    log_warn "  - TRAEFIK_DASHBOARD_AUTH (if using dashboard)"
else
    log_info ".env file already exists, skipping..."
fi

# =============================================================================
# STEP 3: Generate config.json from template
# =============================================================================
log_info "Generating config.json from template..."

# Source the .env file
set -a
source .env
set +a

# Check for template file
if [[ ! -f config.json.template ]]; then
    log_error "config.json.template not found!"
    exit 1
fi

# Create config from template with actual values
cp config.json.template config.json

# Update config.json with actual values (macOS compatible sed)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires backup extension
    sed -i '' "s|MONGO_APP_USER_PLACEHOLDER|${MONGO_APP_USER}|g" config.json
    sed -i '' "s|MONGO_APP_PASSWORD_PLACEHOLDER|${MONGO_APP_PASSWORD}|g" config.json
    sed -i '' "s|MESHCENTRAL_SESSION_KEY_PLACEHOLDER|${MESHCENTRAL_SESSION_KEY}|g" config.json
    sed -i '' "s|MESHCENTRAL_DB_ENCRYPT_KEY_PLACEHOLDER|${MESHCENTRAL_DB_ENCRYPT_KEY}|g" config.json
    sed -i '' "s|MESHCENTRAL_HOSTNAME_PLACEHOLDER|${MESHCENTRAL_HOSTNAME}|g" config.json
else
    # Linux sed
    sed -i "s|MONGO_APP_USER_PLACEHOLDER|${MONGO_APP_USER}|g" config.json
    sed -i "s|MONGO_APP_PASSWORD_PLACEHOLDER|${MONGO_APP_PASSWORD}|g" config.json
    sed -i "s|MESHCENTRAL_SESSION_KEY_PLACEHOLDER|${MESHCENTRAL_SESSION_KEY}|g" config.json
    sed -i "s|MESHCENTRAL_DB_ENCRYPT_KEY_PLACEHOLDER|${MESHCENTRAL_DB_ENCRYPT_KEY}|g" config.json
    sed -i "s|MESHCENTRAL_HOSTNAME_PLACEHOLDER|${MESHCENTRAL_HOSTNAME}|g" config.json
fi

# Secure the generated config
chmod 600 config.json

log_info "config.json generated with secrets (not tracked by git)."

# =============================================================================
# STEP 4: Generate MongoDB init script from template
# =============================================================================
log_info "Generating MongoDB initialization script from template..."

# Check for template file
if [[ ! -f init-mongo.js.template ]]; then
    log_error "init-mongo.js.template not found!"
    exit 1
fi

# Create init script from template
cp init-mongo.js.template init-mongo.js

# Update with actual values
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|MONGO_APP_USER_PLACEHOLDER|${MONGO_APP_USER}|g" init-mongo.js
    sed -i '' "s|MONGO_APP_PASSWORD_PLACEHOLDER|${MONGO_APP_PASSWORD}|g" init-mongo.js
else
    sed -i "s|MONGO_APP_USER_PLACEHOLDER|${MONGO_APP_USER}|g" init-mongo.js
    sed -i "s|MONGO_APP_PASSWORD_PLACEHOLDER|${MONGO_APP_PASSWORD}|g" init-mongo.js
fi

# Secure the generated file
chmod 600 init-mongo.js

log_info "MongoDB init script generated (not tracked by git)."

# =============================================================================
# STEP 5: Set permissions
# =============================================================================
log_info "Setting file permissions..."

chmod 600 .env
chmod 600 config.json
chmod 600 init-mongo.js
chmod 755 setup.sh

log_info "Permissions set."

# =============================================================================
# STEP 6: Create required directories
# =============================================================================
log_info "Creating required directories..."

mkdir -p fail2ban/filter.d

log_info "Directories created."

# =============================================================================
# FINAL INSTRUCTIONS
# =============================================================================
echo ""
echo "============================================================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "============================================================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Edit .env and verify all settings, especially:"
echo "   - MESHCENTRAL_HOSTNAME"
echo "   - ACME_EMAIL"
echo ""
echo "2. Ensure DNS is configured:"
echo "   - ${MESHCENTRAL_HOSTNAME} -> Your server's public IP"
echo ""
echo "3. Start the services:"
echo "   docker compose up -d"
echo ""
echo "4. Check logs:"
echo "   docker compose logs -f"
echo ""
echo "5. Access eCortex at:"
echo "   https://${MESHCENTRAL_HOSTNAME}"
echo ""
echo "6. First user to register becomes admin"
echo "   (NewAccounts is disabled after setup)"
echo ""
echo "============================================================================="
echo -e "${YELLOW}SECURITY REMINDERS:${NC}"
echo "============================================================================="
echo "- Change Traefik dashboard password if enabled"
echo "- Enable MFA for all admin accounts immediately"
echo "- Create device groups for each client"
echo "- Never commit .env or secrets to git"
echo "============================================================================="
