<#
.SYNOPSIS
    eCortex Agent Status Validation Script for NinjaOne
    
.DESCRIPTION
    Validates eCortex Agent installation status and connectivity.
    Outputs status to NinjaOne console and updates custom fields.
    
    Use this script for:
    - Monitoring agent health
    - Troubleshooting connectivity issues
    - Compliance reporting
    
.NOTES
    Author: Cortalis
    Version: 1.0.0
    Deployment: NinjaOne Monitoring Policy
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# =============================================================================
# STATUS OBJECT
# =============================================================================
$status = @{
    Installed = $false
    ServiceRunning = $false
    ServiceName = $null
    ProcessRunning = $false
    InstallPath = $null
    ServerUrl = $null
    LastConnected = $null
    Version = $null
    Healthy = $false
}

Write-Host "=========================================="
Write-Host "eCortex Agent Status Check"
Write-Host "=========================================="
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=========================================="

# =============================================================================
# CHECK SERVICE
# =============================================================================
Write-Host ""
Write-Host "Checking MeshAgent service..."

$serviceNames = @("MeshAgent", "ecortexagent", "meshagent")
$service = $null

foreach ($name in $serviceNames) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        $service = $svc
        $status.ServiceName = $name
        break
    }
}

if ($service) {
    $status.Installed = $true
    $status.ServiceRunning = ($service.Status -eq "Running")
    Write-Host "  Service Found: $($service.Name)"
    Write-Host "  Status: $($service.Status)"
    Write-Host "  Start Type: $($service.StartType)"
} else {
    Write-Host "  Service: NOT FOUND"
}

# =============================================================================
# CHECK PROCESS
# =============================================================================
Write-Host ""
Write-Host "Checking MeshAgent process..."

$processes = @("MeshAgent", "meshagent")
$process = $null

foreach ($name in $processes) {
    $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($proc) {
        $process = $proc
        break
    }
}

if ($process) {
    $status.ProcessRunning = $true
    Write-Host "  Process: Running"
    Write-Host "  PID: $($process.Id)"
    Write-Host "  Memory: $([math]::Round($process.WorkingSet64 / 1MB, 2)) MB"
    Write-Host "  Start Time: $($process.StartTime)"
} else {
    Write-Host "  Process: NOT RUNNING"
}

# =============================================================================
# CHECK INSTALLATION
# =============================================================================
Write-Host ""
Write-Host "Checking installation..."

$installPaths = @(
    "${env:ProgramFiles}\Mesh Agent",
    "${env:ProgramFiles(x86)}\Mesh Agent",
    "${env:ProgramFiles}\Open Source\MeshAgent",
    "C:\Program Files\Mesh Agent"
)

foreach ($path in $installPaths) {
    if (Test-Path $path) {
        $status.InstallPath = $path
        
        # Check for executable
        $exePath = Join-Path $path "MeshAgent.exe"
        if (Test-Path $exePath) {
            $fileInfo = Get-Item $exePath
            $status.Version = $fileInfo.VersionInfo.FileVersion
            Write-Host "  Install Path: $path"
            Write-Host "  Executable: Found"
            Write-Host "  Version: $($status.Version)"
            Write-Host "  File Date: $($fileInfo.LastWriteTime)"
        }
        break
    }
}

if (-not $status.InstallPath) {
    Write-Host "  Install Path: NOT FOUND"
}

# =============================================================================
# CHECK CONFIGURATION
# =============================================================================
Write-Host ""
Write-Host "Checking configuration..."

if ($status.InstallPath) {
    $configPaths = @(
        (Join-Path $status.InstallPath "meshagent.msh"),
        (Join-Path $status.InstallPath "meshagent.db")
    )
    
    foreach ($configPath in $configPaths) {
        if (Test-Path $configPath) {
            Write-Host "  Config File: $configPath (exists)"
            
            # Try to extract server URL from MSH file
            if ($configPath -like "*.msh") {
                try {
                    $content = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
                    if ($content -match 'MeshServer=([^\r\n]+)') {
                        $status.ServerUrl = $Matches[1]
                        Write-Host "  Server URL: $($status.ServerUrl)"
                    }
                } catch {
                    # Ignore parsing errors
                }
            }
        }
    }
}

# =============================================================================
# NETWORK CONNECTIVITY TEST
# =============================================================================
Write-Host ""
Write-Host "Checking network connectivity..."

if ($status.ServerUrl) {
    try {
        $uri = [System.Uri]$status.ServerUrl
        $testResult = Test-NetConnection -ComputerName $uri.Host -Port $uri.Port -WarningAction SilentlyContinue
        
        if ($testResult.TcpTestSucceeded) {
            Write-Host "  Server Reachable: YES"
            Write-Host "  Latency: $($testResult.PingReplyDetails.RoundtripTime) ms"
        } else {
            Write-Host "  Server Reachable: NO"
        }
    } catch {
        Write-Host "  Server Test: Could not test connectivity"
    }
} else {
    Write-Host "  Server Test: No server URL configured"
}

# =============================================================================
# OVERALL HEALTH ASSESSMENT
# =============================================================================
Write-Host ""
Write-Host "=========================================="
Write-Host "Health Assessment"
Write-Host "=========================================="

$status.Healthy = $status.Installed -and $status.ServiceRunning -and $status.ProcessRunning

if ($status.Healthy) {
    Write-Host "Overall Status: HEALTHY" -ForegroundColor Green
    $healthStatus = "Healthy"
} elseif ($status.Installed) {
    Write-Host "Overall Status: DEGRADED" -ForegroundColor Yellow
    $healthStatus = "Degraded"
    
    if (-not $status.ServiceRunning) {
        Write-Host "  Issue: Service not running" -ForegroundColor Yellow
    }
    if (-not $status.ProcessRunning) {
        Write-Host "  Issue: Process not running" -ForegroundColor Yellow
    }
} else {
    Write-Host "Overall Status: NOT INSTALLED" -ForegroundColor Red
    $healthStatus = "Not Installed"
}

# =============================================================================
# UPDATE NINJAONE CUSTOM FIELDS
# =============================================================================
try {
    # Update status field
    Ninja-Property-Set meshcentral_agent_status $healthStatus 2>$null
    
    # Update version field
    if ($status.Version) {
        Ninja-Property-Set meshcentral_agent_version $status.Version 2>$null
    }
    
    # Update last check time
    Ninja-Property-Set meshcentral_last_check (Get-Date -Format "yyyy-MM-dd HH:mm:ss") 2>$null
    
    Write-Host ""
    Write-Host "NinjaOne custom fields updated"
} catch {
    # Non-critical, don't fail script
}

# =============================================================================
# EXIT CODE
# =============================================================================
Write-Host ""
Write-Host "=========================================="

if ($status.Healthy) {
    exit 0
} elseif ($status.Installed) {
    exit 1  # Degraded
} else {
    exit 2  # Not installed
}
