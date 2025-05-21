
function Get-Hostname {
    param (
        [string]$DistributionName
    )

    if (-not $DistributionName) {
        wsl.exe --list --installed | ForEach-Object {
            if ($_ -match "^\s*(\S+)\s+.*") {
                $installedDistributions += $matches[1]
            }
        }
        $DistributionName = Read-Host -Prompt "Please provide a WSL distribution name."
        return
    }

    # Get the IP address of the specified WSL distribution
    $ipAddress = wsl -d $DistributionName hostname -i
    $alias = wsl -d $DistributionName hostname -a
    $fqdn = wsl -d $DistributionName hostname -f
    $otherIpAddress = wsl -d $DistributionName hostname -I

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get IP address for distribution: $DistributionName"
        return
    }

    Write-Host "IP Address of ${DistributionName}: $ipAddress"
    Write-Host "Alias of ${DistributionName}: $alias"
    Write-Host "FQDN of ${DistributionName}: $fqdn"
    Write-Host "Other IP Address of ${DistributionName}: $otherIpAddress"    
}

Get-Hostname -DistributionName "Ubuntu-24.04"