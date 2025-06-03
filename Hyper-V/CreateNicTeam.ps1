# from https://mcsaguru.com/enable-nic-teaming-windows-11-powershell-tutorial/

# Example condition: Check if no network adapters are found
$adapters = Get-NetAdapterAdvancedProperty -Name "*TeamingMode*"

if (-not $adapters) {
    Write-Host "No network adapters found with the specified property. Exiting script."
    return
}

# Continue with the rest of the script
$adapters | Select-Object -Property DisplayName, DisplayValue