<#
.SYNOPSIS
    Hard restarts WSL, waits for it to fully stop, then waits for Linux to become ready before launching a command.
.EXAMPLE
    ./refresh-wsl.ps1 -Command "zed ."
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$Command = "echo 'WSL is back and ready!'"
)

Write-Host '--- Initiating WSL Hard Reset ---' -ForegroundColor Cyan

# 1. Kill the WSL VM and all distributions
wsl --shutdown
Write-Host 'Shutdown signal sent. Waiting for vmmem process to release RAM...' -ForegroundColor Yellow

# 2. Wait for WSL to be fully "Down" (The reverse ping)
while ((wsl --list --running) -notmatch 'There are no running distributions') {
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host "`n[SUCCESS] WSL is fully stopped." -ForegroundColor Green

# 3. Trigger Startup & "Ping" for Readiness
Write-Host 'Booting Linux and waiting for systemd/network...' -NoNewline
# We run a simple true command to trigger the boot
Start-Job -ScriptBlock { wsl --exec true } | Out-Null

# 4. The "Ready Ping" Loop
# This checks if the Linux environment is actually responsive to commands
$isReady = $false
while (-not $isReady) {
    try {
        # Check if we can execute a simple bash command
        $status = wsl --exec bash -c "echo 'ready'" -ErrorAction SilentlyContinue
        if ($status -eq 'ready') { $isReady = $true }
    }
    catch {
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 1
    }
}

Write-Host "`n[ONLINE] Linux subsystem is responsive!" -ForegroundColor Green

# 5. Execute your final command (Zed, VS Code, etc.)
Write-Host "Executing: $Command" -ForegroundColor Cyan
try {
    Invoke-Expression -Command $Command
}
catch {
    Write-Error "Failed to execute command: $_"
}