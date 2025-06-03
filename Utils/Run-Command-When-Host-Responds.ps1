#! /bin/pwsh

# This script waits for a specific host to respond to a ping request
# and then runs a command passed as an argument.
# Usage: Run-Command-When-Host-Responds.ps1 "<command>"
# Example: Run-Command-When-Host-Responds.ps1 "Get-Process"

#set command to first argument
$command = $args[0]

$address = "PRECISION5820"

do {
    $pingResult = Test-Connection -ComputerName $address -Count 1 -ErrorAction SilentlyContinue
    if (-not $pingResult) {
        Start-Sleep -Seconds 5
    }
} while (-not $pingResult)

Write-Host "Host is up. Running command..."

# run command
Invoke-Expression $command
# or you can use Start-Process if you want to run a program instead of a command
# Start-Process -FilePath "C:\Path\To\YourProgram.exe" -ArgumentList $command

