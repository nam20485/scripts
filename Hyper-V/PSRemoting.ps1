Function Add-TrustedHost() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName
    )

    # $serverToAdd = Read-Host -Prompt "Enter the name of the new server to add to TrustedHosts"
    # if (-not $serverToAdd) {
    #     Write-Host "No server name provided. Exiting."
    #     exit
    # }

    # Get the current TrustedHosts list
    $currentTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value

    # Check if the list is empty or if the server is already in the list
    if ([string]::IsNullOrWhiteSpace($currentTrustedHosts)) {
        # If the list is empty, just set the new server
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $serverToAdd -Force
        Write-Host "'$serverToAdd' added to TrustedHosts. The list was previously empty."
    }
    elseif ($currentTrustedHosts -eq '*') {
        # If all hosts are already trusted, no action needed
        Write-Host "All hosts ('*') are already trusted. No changes made."
    }
    elseif (($currentTrustedHosts -split ',\s*' | ForEach-Object { $_.Trim() }) -notcontains $serverToAdd) {
        # If the server is not already in the list, append it
        $newTrustedHosts = $currentTrustedHosts + ',' + $serverToAdd
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newTrustedHosts -Force
        Write-Host "'$serverToAdd' appended to TrustedHosts. New list: $newTrustedHosts"
    }
    else {
        # If the server is already in the list
        Write-Host "'$serverToAdd' is already in the TrustedHosts list: $currentTrustedHosts"
    }

    # To view the updated list
    Get-Item WSMan:\localhost\Client\TrustedHosts
}

$server = Read-Host -Prompt "Enter the name of the new server to add to TrustedHosts"
if (-not $server) {
    Write-Host "No server name provided. Exiting."
    exit
}

Add-TrustedHost -ServerName $server

# $curValue = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
# if ($curValue -notlike "*$newServer*") {
#     $curValue += ",$newServer"
#     Write-Host "Adding $newServer to TrustedHosts, new value will be: $curValue"
#     # Ensure the TrustedHosts setting is set to allow multiple entries
#     Set-Item WSMan:\localhost\Client\TrustedHosts $curValue -Force
#     Write-Host "Added $newServer to TrustedHosts."
# } else {
#     Write-Host "$newServer is already in TrustedHosts."     
# }

# # current value
# $curValue = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
# Write-Host "Current TrustedHosts value: $curValue"  

