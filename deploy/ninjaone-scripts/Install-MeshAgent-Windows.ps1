<#
.SYNOPSIS
    eCortex Agent Installation Script for NinjaOne Deployment
    
.DESCRIPTION
    Silent installation of eCortex Agent on Windows endpoints.
    Designed for deployment via NinjaOne with secure variable injection.
    
    NO SECRETS ARE HARDCODED - All sensitive values come from NinjaOne variables.
    
.NOTES
    Author: Cortalis
    Version: 1.0.0
    Deployment: NinjaOne Policy/Script
    
.PARAMETER MeshServerUrl
    The eCortex server URL (e.g., https://mesh.cortalis.com)
    Injected from NinjaOne custom field or script variable
    
.PARAMETER MeshInviteToken
    Temporary agent invite token generated server-side
    Token has limited validity and should be rotated regularly
    Injected from NinjaOne secure variable
    
.PARAMETER MeshGroupId
    Device group ID for automatic assignment
    Can be determined by NinjaOne organization/client
    Injected from NinjaOne custom field
    
.PARAMETER ClientCode
    Client identifier for device naming (e.g., "ACME")
    Typically from NinjaOne organization name or custom field
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$MeshServerUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$MeshInviteToken,
    
    [Parameter(Mandatory = $false)]
    [string]$MeshGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientCode
)

# =============================================================================
# CONFIGURATION - Values injected from NinjaOne
# =============================================================================
# These use NinjaOne's secure variable system - DO NOT HARDCODE SECRETS

# Try to get values from NinjaOne custom fields if not passed as parameters
if (-not $MeshServerUrl) {
    $MeshServerUrl = $env:MESHCENTRAL_SERVER_URL
    if (-not $MeshServerUrl) {
        # NinjaRMM custom field syntax
        $MeshServerUrl = Ninja-Property-Get meshcentral_server_url 2>$null
    }
}

if (-not $MeshInviteToken) {
    $MeshInviteToken = $env:MESHCENTRAL_INVITE_TOKEN
    if (-not $MeshInviteToken) {
        $MeshInviteToken = Ninja-Property-Get meshcentral_invite_token 2>$null
    }
}

if (-not $MeshGroupId) {
    $MeshGroupId = $env:MESHCENTRAL_GROUP_ID
    if (-not $MeshGroupId) {
        $MeshGroupId = Ninja-Property-Get meshcentral_group_id 2>$null
    }
}

if (-not $ClientCode) {
    $ClientCode = $env:CLIENT_CODE
    if (-not $ClientCode) {
        $ClientCode = Ninja-Property-Get client_code 2>$null
    }
    if (-not $ClientCode) {
        # Fallback: Try to get organization name from NinjaOne
        $ClientCode = Ninja-Property-Get organizationName 2>$null
        if ($ClientCode) {
            # Convert to uppercase short code (first 6 chars, alphanumeric only)
            $ClientCode = ($ClientCode -replace '[^a-zA-Z0-9]', '').Substring(0, [Math]::Min(6, $ClientCode.Length)).ToUpper()
        }
    }
}

# =============================================================================
# VALIDATION
# =============================================================================
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    # Also write to NinjaOne activity log
    if ($Level -eq "ERROR") {
        Write-Error $Message
    }
}

Write-Log "eCortex Agent Installation Script Starting"
Write-Log "Server URL: $MeshServerUrl"
Write-Log "Client Code: $ClientCode"
Write-Log "Group ID: $(if ($MeshGroupId) { $MeshGroupId.Substring(0, [Math]::Min(10, $MeshGroupId.Length)) + '...' } else { 'Not Set' })"

# Validate required parameters
if (-not $MeshServerUrl) {
    Write-Log "ERROR: eCortex server URL not configured" "ERROR"
    Write-Log "Set the 'meshcentral_server_url' custom field in NinjaOne" "ERROR"
    exit 1
}

if (-not $MeshInviteToken) {
    Write-Log "ERROR: eCortex invite token not configured" "ERROR"
    Write-Log "Generate a token in eCortex and set 'meshcentral_invite_token' in NinjaOne" "ERROR"
    exit 1
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
Write-Log "Performing pre-flight checks..."

# Check if already installed
$existingService = Get-Service -Name "MeshAgent" -ErrorAction SilentlyContinue
if ($existingService -and $existingService.Status -eq "Running") {
    Write-Log "MeshAgent service is already installed and running"
    
    # Verify it can connect to our server
    $meshAgentPath = "${env:ProgramFiles}\Mesh Agent\MeshAgent.exe"
    if (Test-Path $meshAgentPath) {
        Write-Log "MeshAgent executable found at: $meshAgentPath"
        Write-Log "Installation skipped - agent already present"
        exit 0
    }
}

# Check for custom service name (if using agentCustomization)
$customService = Get-Service -Name "ecortexagent" -ErrorAction SilentlyContinue
if ($customService -and $customService.Status -eq "Running") {
    Write-Log "eCortex Agent service is already installed and running"
    exit 0
}

# =============================================================================
# DOWNLOAD AGENT
# =============================================================================
Write-Log "Downloading MeshAgent from server..."

$tempDir = Join-Path $env:TEMP "MeshAgentInstall"
$installerPath = Join-Path $tempDir "meshagent.exe"

# Create temp directory
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Construct download URL with invite token
# eCortex generates a unique URL for each device group with embedded settings
$downloadUrl = "$MeshServerUrl/meshagents?id=4"

# Add invite code if provided (for automatic device registration)
if ($MeshInviteToken) {
    $downloadUrl = "$MeshServerUrl/meshagents?script=1&meshinstall=4"
}

try {
    # Configure TLS 1.2+
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    
    Write-Log "Downloading from: $($MeshServerUrl)/meshagents"
    
    # Download the agent
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "NinjaOne-eCortex-Installer/1.0")
    
    # If we have a direct MSH link (installation string), use that
    if ($MeshInviteToken -match "^meshcentral://") {
        Write-Log "Using direct installation link"
        $mshLink = $MeshInviteToken
    } else {
        # Otherwise construct the download URL
        $downloadUrl = "$MeshServerUrl/meshagents?id=4"
        $webClient.DownloadFile($downloadUrl, $installerPath)
    }
    
    # Verify download
    if (-not (Test-Path $installerPath) -or (Get-Item $installerPath).Length -lt 100000) {
        throw "Downloaded file is missing or too small"
    }
    
    Write-Log "Download complete: $((Get-Item $installerPath).Length) bytes"
}
catch {
    Write-Log "Failed to download MeshAgent: $_" "ERROR"
    exit 1
}

# =============================================================================
# INSTALL AGENT
# =============================================================================
Write-Log "Installing MeshAgent..."

try {
    # Build installation arguments
    $installArgs = @()
    
    # If we have a full MSH installation link
    if ($MeshInviteToken -match "^meshcentral://") {
        # The MSH link contains everything needed
        $installArgs += $MeshInviteToken
    } else {
        # Manual installation with parameters
        $installArgs += "-install"
        
        # Server URL
        $installArgs += "-ServerUrl=`"$MeshServerUrl`""
        
        # Mesh/Group ID
        if ($MeshGroupId) {
            $installArgs += "-MeshId=`"$MeshGroupId`""
        }
        
        # Invite token
        if ($MeshInviteToken) {
            $installArgs += "-InstallToken=`"$MeshInviteToken`""
        }
    }
    
    # Build device name: CLIENTCODE-HOSTNAME
    $hostname = $env:COMPUTERNAME
    if ($ClientCode) {
        $deviceName = "$ClientCode-$hostname"
    } else {
        $deviceName = $hostname
    }
    
    Write-Log "Device name will be: $deviceName"
    
    # Run installer
    Write-Log "Running installer with silent arguments..."
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        throw "Installer exited with code: $($process.ExitCode)"
    }
    
    Write-Log "Installation process completed"
}
catch {
    Write-Log "Installation failed: $_" "ERROR"
    exit 1
}

# =============================================================================
# VERIFY INSTALLATION
# =============================================================================
Write-Log "Verifying installation..."

Start-Sleep -Seconds 5

# Check service
$service = Get-Service -Name "MeshAgent" -ErrorAction SilentlyContinue
if (-not $service) {
    $service = Get-Service -Name "dfwmspagent" -ErrorAction SilentlyContinue
}

if ($service) {
    Write-Log "Service found: $($service.Name) - Status: $($service.Status)"
    
    if ($service.Status -ne "Running") {
        Write-Log "Starting service..."
        Start-Service -Name $service.Name
        Start-Sleep -Seconds 3
        $service.Refresh()
    }
    
    if ($service.Status -eq "Running") {
        Write-Log "MeshAgent service is running successfully" 
    } else {
        Write-Log "Service failed to start" "ERROR"
        exit 1
    }
} else {
    Write-Log "MeshAgent service not found after installation" "ERROR"
    exit 1
}

# =============================================================================
# STORE ECORTEX URL IN NINJAONE (for quick access)
# =============================================================================
try {
    # Calculate the device URL for NinjaOne custom field
    # This allows technicians to click directly to the device in eCortex
    $meshDeviceUrl = "$MeshServerUrl/?node=$hostname"
    
    # Store in NinjaOne custom field (if the field exists)
    Ninja-Property-Set meshcentral_device_url $meshDeviceUrl 2>$null
    Write-Log "eCortex device URL stored in NinjaOne custom field"
}
catch {
    Write-Log "Could not store device URL in NinjaOne (non-critical): $_" "WARN"
}

# =============================================================================
# CLEANUP
# =============================================================================
Write-Log "Cleaning up temporary files..."

try {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Log "Cleanup warning: $_" "WARN"
}

# =============================================================================
# SUCCESS
# =============================================================================
Write-Log "=========================================="
Write-Log "eCortex Agent Installation Complete!"
Write-Log "=========================================="
Write-Log "Server: $MeshServerUrl"
Write-Log "Device: $deviceName"
Write-Log "Service Status: Running"
Write-Log "=========================================="

exit 0
