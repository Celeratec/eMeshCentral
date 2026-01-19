<#
.SYNOPSIS
    eCortex Agent Uninstallation Script for NinjaOne
    
.DESCRIPTION
    Silent removal of eCortex Agent from Windows endpoints.
    Used for offboarding clients or cleanup.
    
.NOTES
    Author: Cortalis
    Version: 1.0.0
    Deployment: NinjaOne Script
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "eCortex Agent Uninstallation Script Starting"
Write-Log "Hostname: $env:COMPUTERNAME"

# =============================================================================
# FIND AND STOP SERVICE
# =============================================================================
Write-Log "Checking for MeshAgent services..."

$serviceNames = @("MeshAgent", "dfwmspagent", "meshagent")
$foundService = $null

foreach ($name in $serviceNames) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service) {
        $foundService = $service
        Write-Log "Found service: $name (Status: $($service.Status))"
        
        if ($service.Status -eq "Running") {
            Write-Log "Stopping service..."
            Stop-Service -Name $name -Force
            Start-Sleep -Seconds 2
        }
        
        # Remove the service
        Write-Log "Removing service..."
        sc.exe delete $name | Out-Null
        Start-Sleep -Seconds 1
    }
}

# =============================================================================
# KILL ANY REMAINING PROCESSES
# =============================================================================
Write-Log "Checking for running processes..."

$processNames = @("MeshAgent", "meshagent")
foreach ($name in $processNames) {
    $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Log "Stopping process: $name (PID: $($proc.Id))"
        Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

# =============================================================================
# RUN BUILT-IN UNINSTALLER IF EXISTS
# =============================================================================
Write-Log "Looking for built-in uninstaller..."

$installPaths = @(
    "${env:ProgramFiles}\Mesh Agent",
    "${env:ProgramFiles(x86)}\Mesh Agent",
    "${env:ProgramFiles}\Open Source\MeshAgent",
    "C:\Program Files\Mesh Agent"
)

foreach ($path in $installPaths) {
    $uninstaller = Join-Path $path "MeshAgent.exe"
    if (Test-Path $uninstaller) {
        Write-Log "Running built-in uninstaller at: $uninstaller"
        try {
            Start-Process -FilePath $uninstaller -ArgumentList "-uninstall" -Wait -NoNewWindow
            Start-Sleep -Seconds 2
        } catch {
            Write-Log "Uninstaller failed: $_" "WARN"
        }
    }
}

# =============================================================================
# REMOVE INSTALLATION DIRECTORIES
# =============================================================================
Write-Log "Removing installation directories..."

foreach ($path in $installPaths) {
    if (Test-Path $path) {
        Write-Log "Removing: $path"
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Log "Removed successfully"
        } catch {
            Write-Log "Could not remove (may require reboot): $_" "WARN"
        }
    }
}

# Also check ProgramData
$dataPath = "${env:ProgramData}\Mesh Agent"
if (Test-Path $dataPath) {
    Write-Log "Removing data directory: $dataPath"
    Remove-Item -Path $dataPath -Recurse -Force -ErrorAction SilentlyContinue
}

# =============================================================================
# CLEAN UP REGISTRY (if needed)
# =============================================================================
Write-Log "Cleaning registry entries..."

$regPaths = @(
    "HKLM:\SOFTWARE\Open Source\MeshAgent",
    "HKLM:\SOFTWARE\MeshAgent",
    "HKLM:\SOFTWARE\WOW6432Node\Open Source\MeshAgent"
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        Write-Log "Removing registry key: $regPath"
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# UPDATE NINJAONE
# =============================================================================
try {
    Ninja-Property-Set meshcentral_agent_status "Uninstalled" 2>$null
    Ninja-Property-Set meshcentral_device_url "" 2>$null
    Write-Log "NinjaOne custom fields updated"
} catch {
    # Non-critical
}

# =============================================================================
# VERIFY REMOVAL
# =============================================================================
Write-Log "Verifying removal..."

$remainingService = Get-Service -Name "MeshAgent" -ErrorAction SilentlyContinue
$remainingProcess = Get-Process -Name "MeshAgent" -ErrorAction SilentlyContinue

if ($remainingService -or $remainingProcess) {
    Write-Log "WARNING: Some components may remain. A reboot may be required." "WARN"
} else {
    Write-Log "MeshAgent has been completely removed"
}

# =============================================================================
# SUCCESS
# =============================================================================
Write-Log "=========================================="
Write-Log "eCortex Agent Uninstallation Complete"
Write-Log "=========================================="

exit 0
