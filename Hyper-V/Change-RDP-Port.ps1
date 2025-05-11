param (
    [int]$port = $(Read-Host "Please enter the new RDP port number")
)

# Set the registry value for the port
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Terminal*Server\WinStations\RDP-TCP\ -Name PortNumber -Value $port

#Diable existing remote desktop rules
Set-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)" -Enabled False
Set-NetFirewallRule -DisplayName "Remote Desktop - User Mode (UDP-In)" -Enabled False

#Create custom remote desktop rules
New-NetFirewallRule -DisplayName "Remote Desktop Custom - TCP-In" -Action Allow -Description "Inbound rule for the Remote Desktop service to allow RDP traffic over TCP." -Direction Inbound -Enabled True -Group "Custom Rules" -LocalAddress Any -LocalPort $port -Protocol TCP -RemotePort Any
New-NetFirewallRule -DisplayName "Remote Desktop Custom - UDP-In" -Action Allow -Description "Inbound rule for the Remote Desktop service to allow RDP traffic over UDP." -Direction Inbound -Enabled True -Group "Custom Rules" -LocalAddress Any -LocalPort $port -Protocol UDP -RemotePort Any

# Restart the service to finalize the changes
# Use -Force as it has dependant services
Restart-Service -Name TermService -Force 

Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")