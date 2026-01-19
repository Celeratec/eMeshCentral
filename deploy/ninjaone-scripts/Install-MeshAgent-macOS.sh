#!/bin/bash
# =============================================================================
# eCortex Agent Installation Script for NinjaOne Deployment (macOS)
# =============================================================================
# Silent installation of eCortex Agent on macOS endpoints.
# Designed for deployment via NinjaOne with secure variable injection.
#
# NO SECRETS ARE HARDCODED - All sensitive values come from NinjaOne variables.
#
# Author: Cortalis
# Version: 1.0.0
# Deployment: NinjaOne Policy/Script
# =============================================================================

set -e

# =============================================================================
# LOGGING
# =============================================================================
LOG_FILE="/var/log/meshagent-install.log"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# =============================================================================
# CONFIGURATION - Values from NinjaOne environment variables
# =============================================================================

# NinjaOne injects these as environment variables or we read from custom fields
MESH_SERVER_URL="${MESHCENTRAL_SERVER_URL:-}"
MESH_INVITE_TOKEN="${MESHCENTRAL_INVITE_TOKEN:-}"
MESH_GROUP_ID="${MESHCENTRAL_GROUP_ID:-}"
CLIENT_CODE="${CLIENT_CODE:-}"

# Try to get from NinjaOne custom fields if not in environment
if command -v ninja-property-get &> /dev/null; then
    [ -z "$MESH_SERVER_URL" ] && MESH_SERVER_URL=$(ninja-property-get meshcentral_server_url 2>/dev/null || true)
    [ -z "$MESH_INVITE_TOKEN" ] && MESH_INVITE_TOKEN=$(ninja-property-get meshcentral_invite_token 2>/dev/null || true)
    [ -z "$MESH_GROUP_ID" ] && MESH_GROUP_ID=$(ninja-property-get meshcentral_group_id 2>/dev/null || true)
    [ -z "$CLIENT_CODE" ] && CLIENT_CODE=$(ninja-property-get client_code 2>/dev/null || true)
fi

# =============================================================================
# MAIN SCRIPT
# =============================================================================

log_info "=========================================="
log_info "eCortex Agent Installation (macOS)"
log_info "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# =============================================================================
# VALIDATION
# =============================================================================
log_info "Validating configuration..."
log_info "Server URL: $MESH_SERVER_URL"
log_info "Client Code: $CLIENT_CODE"
log_info "Group ID: ${MESH_GROUP_ID:0:10}..."

if [ -z "$MESH_SERVER_URL" ]; then
    log_error "eCortex server URL not configured"
    log_error "Set the 'meshcentral_server_url' custom field in NinjaOne"
    exit 1
fi

if [ -z "$MESH_INVITE_TOKEN" ]; then
    log_error "eCortex invite token not configured"
    log_error "Generate a token in eCortex and set 'meshcentral_invite_token' in NinjaOne"
    exit 1
fi

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
log_info "Performing pre-flight checks..."

# Check if already installed
MESH_AGENT_PATH="/opt/meshagent/meshagent"
MESH_AGENT_PLIST="/Library/LaunchDaemons/meshagent.plist"

if [ -f "$MESH_AGENT_PATH" ] && [ -f "$MESH_AGENT_PLIST" ]; then
    # Check if service is running
    if launchctl list | grep -q "meshagent"; then
        log_info "MeshAgent is already installed and running"
        log_info "Verifying connection to server..."
        
        # Quick health check
        if pgrep -x "meshagent" > /dev/null; then
            log_info "MeshAgent process is active"
            log_info "Installation skipped - agent already present"
            exit 0
        fi
    fi
fi

# Check for custom service name
if launchctl list | grep -q "ecortexagent"; then
    log_info "eCortex Agent is already installed and running"
    exit 0
fi

# =============================================================================
# DOWNLOAD AGENT
# =============================================================================
log_info "Downloading MeshAgent from server..."

TEMP_DIR=$(mktemp -d)
INSTALLER_PATH="$TEMP_DIR/meshagent"

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Determine macOS architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        AGENT_ID="6"  # macOS x86-64
        log_info "Detected architecture: Intel (x86_64)"
        ;;
    arm64)
        AGENT_ID="29"  # macOS ARM64
        log_info "Detected architecture: Apple Silicon (arm64)"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download URL
DOWNLOAD_URL="${MESH_SERVER_URL}/meshagents?id=${AGENT_ID}"

log_info "Downloading from: $DOWNLOAD_URL"

# Download with curl
if ! curl -fsSL -o "$INSTALLER_PATH" "$DOWNLOAD_URL"; then
    log_error "Failed to download MeshAgent"
    exit 1
fi

# Verify download
if [ ! -f "$INSTALLER_PATH" ] || [ $(stat -f%z "$INSTALLER_PATH" 2>/dev/null || stat -c%s "$INSTALLER_PATH") -lt 100000 ]; then
    log_error "Downloaded file is missing or too small"
    exit 1
fi

chmod +x "$INSTALLER_PATH"
log_info "Download complete: $(stat -f%z "$INSTALLER_PATH" 2>/dev/null || stat -c%s "$INSTALLER_PATH") bytes"

# =============================================================================
# INSTALL AGENT
# =============================================================================
log_info "Installing MeshAgent..."

# Build device name: CLIENTCODE-HOSTNAME
HOSTNAME=$(hostname -s)
if [ -n "$CLIENT_CODE" ]; then
    DEVICE_NAME="${CLIENT_CODE}-${HOSTNAME}"
else
    DEVICE_NAME="$HOSTNAME"
fi

log_info "Device name will be: $DEVICE_NAME"

# Create installation directory
mkdir -p /opt/meshagent

# If we have a full MSH installation link
if [[ "$MESH_INVITE_TOKEN" == meshcentral://* ]]; then
    log_info "Using direct installation link"
    
    # Run installer with MSH link
    if ! "$INSTALLER_PATH" -install --msh="$MESH_INVITE_TOKEN"; then
        log_error "Installation failed"
        exit 1
    fi
else
    # Manual installation with parameters
    INSTALL_ARGS=("-install")
    INSTALL_ARGS+=("-serverurl=$MESH_SERVER_URL")
    
    if [ -n "$MESH_GROUP_ID" ]; then
        INSTALL_ARGS+=("-meshid=$MESH_GROUP_ID")
    fi
    
    if [ -n "$MESH_INVITE_TOKEN" ]; then
        INSTALL_ARGS+=("-installtoken=$MESH_INVITE_TOKEN")
    fi
    
    log_info "Running installer..."
    if ! "$INSTALLER_PATH" "${INSTALL_ARGS[@]}"; then
        log_error "Installation failed"
        exit 1
    fi
fi

log_info "Installation process completed"

# =============================================================================
# VERIFY INSTALLATION
# =============================================================================
log_info "Verifying installation..."

sleep 5

# Check if installed
if [ -f "$MESH_AGENT_PATH" ]; then
    log_info "MeshAgent binary found at: $MESH_AGENT_PATH"
else
    log_error "MeshAgent binary not found after installation"
    exit 1
fi

# Check LaunchDaemon
if [ -f "$MESH_AGENT_PLIST" ]; then
    log_info "LaunchDaemon plist found"
else
    log_error "LaunchDaemon plist not found"
    exit 1
fi

# Check if service is running
if launchctl list | grep -q "meshagent"; then
    log_info "MeshAgent service is loaded"
else
    log_info "Loading MeshAgent service..."
    launchctl load "$MESH_AGENT_PLIST"
    sleep 2
fi

# Verify process is running
if pgrep -x "meshagent" > /dev/null; then
    log_info "MeshAgent process is running"
else
    log_error "MeshAgent process is not running"
    exit 1
fi

# =============================================================================
# STORE ECORTEX URL IN NINJAONE (for quick access)
# =============================================================================
if command -v ninja-property-set &> /dev/null; then
    MESH_DEVICE_URL="${MESH_SERVER_URL}/?node=${HOSTNAME}"
    ninja-property-set meshcentral_device_url "$MESH_DEVICE_URL" 2>/dev/null || true
    log_info "eCortex device URL stored in NinjaOne custom field"
fi

# =============================================================================
# SUCCESS
# =============================================================================
log_info "=========================================="
log_info "eCortex Agent Installation Complete!"
log_info "=========================================="
log_info "Server: $MESH_SERVER_URL"
log_info "Device: $DEVICE_NAME"
log_info "Service Status: Running"
log_info "=========================================="

exit 0
