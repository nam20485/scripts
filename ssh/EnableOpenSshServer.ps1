# Set the sshd service to be started automatically.
Get-Service -Name sshd | Set-Service -StartupType Automatic

# Start the sshd service.
Start-Service sshd