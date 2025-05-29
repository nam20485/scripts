New-NetSwitchTeam -Name "SwitchTeam01" -TeamMembers "Ethernet adapter vEthernet (External Realtek1)","Ethernet adapter vEthernet (External Realtek2)"

# Format the output into two columns with alignment and add colors for better readability
foreach ($adapter in Get-NetAdapter) {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Adapter Details" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan

    $properties = @{
        "Adapter Name" = $adapter.Name
        "Status" = $adapter.Status
        "Link Speed" = $adapter.LinkSpeed
        "Driver Version" = $adapter.DriverVersion
        "Driver Date" = $adapter.DriverDate
        "MAC Address" = $adapter.MacAddress
        "Interface Description" = $adapter.InterfaceDescription
        "Interface Index" = $adapter.InterfaceIndex
        "Interface GUID" = $adapter.InterfaceGuid
        "Interface Type" = $adapter.InterfaceType
        "Media Type" = $adapter.MediaType
        "AutoSense" = $adapter.AutoSense
        "Availability" = $adapter.Availability
        "Caption" = $adapter.Caption
        "ConfigManagerErrorCode" = $adapter.ConfigManagerErrorCode
        "ConfigManagerUserConfig" = $adapter.ConfigManagerUserConfig
        "CreationClassName" = $adapter.CreationClassName
        "Description" = $adapter.Description
        "DeviceID" = $adapter.DeviceID
        "ErrorCleared" = $adapter.ErrorCleared
        "ErrorDescription" = $adapter.ErrorDescription
        "InstallDate" = $adapter.InstallDate
        "LastErrorCode" = $adapter.LastErrorCode
        "MaxSpeed" = $adapter.MaxSpeed
        "NetworkAddresses" = $adapter.NetworkAddresses
        "PermanentAddress" = $adapter.PermanentAddress
        "PNPDeviceID" = $adapter.PNPDeviceID
        "PowerManagementCapabilities" = $adapter.PowerManagementCapabilities
        "PowerManagementSupported" = $adapter.PowerManagementSupported
        "Speed" = $adapter.Speed
        "StatusInfo" = $adapter.StatusInfo
        "SystemCreationClassName" = $adapter.SystemCreationClassName
        "SystemName" = $adapter.SystemName
    }

    # Add null checks for each property to avoid errors during execution
    foreach ($key in $properties.Keys) {
        $value = $properties[$key]
        if ($null -ne $value) {
            Write-Host ("{0,-30}: {1}" -f $key, $value) -ForegroundColor Yellow
        } else {
            Write-Host ("{0,-30}: [Not Available]" -f $key) -ForegroundColor DarkGray
        }
    }

    Write-Host "=====================================" -ForegroundColor Cyan
}