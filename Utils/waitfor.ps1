<#
.SYNOPSIS
    Pings a host until it responds, then executes a command. Runs on Windows, Linux, and macOS.
.DESCRIPTION
    This PowerShell Core script continuously tests the connection to a specified host.
    Once the host is reachable, it executes an arbitrary command string provided by the user.
.PARAMETER HostName
    The hostname or IP address of the machine to wait for.
.PARAMETER Command
    The command to execute once the host is online. This string should be enclosed in quotes.
.EXAMPLE
    ./waitfor.ps1 -HostName my-remote-server -Command "ssh user@my-remote-server"
.EXAMPLE
    ./waitfor.ps1 -HostName 192.168.1.100 -Command "echo 'Server is back online!'"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [string]$Command
)

Write-Host "Waiting for host $HostName to respond..."

# --- Main Loop ---
# Loop indefinitely until Test-Connection succeeds.
# -Quiet returns a simple boolean ($true or $false), which is perfect for the loop condition.
# -Count 1 sends a single ping request.
# ErrorAction SilentlyContinue suppresses connection error messages for a cleaner output.
try {
    while (-not (Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
}
catch {
    Write-Error "An error occurred while waiting for the host: $_"
    exit 1
}

# Add a newline for cleaner output after the dots.
Write-Host ""
Write-Host "Host $HostName is up!"
Write-Host "Executing command: $Command"

# --- Execute Command ---
# Use Invoke-Expression (IEX) to execute the command string.
# This is similar to 'eval' in bash.
try {
    Invoke-Expression -Command $Command
}
catch {
    Write-Error "An error occurred while executing the command: $_"
}
