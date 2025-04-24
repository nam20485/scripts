# By default, the ssh-agent service is disabled. Configure it to start automatically.
# Run the following command as an administrator.
Get-Service ssh-agent | Set-Service -StartupType Automatic

# Start the service.
Start-Service ssh-agent

# The following command should return a status of Running.
Get-Service ssh-agent

# Load your key files into ssh-agent.
ssh-add $env:USERPROFILE\.ssh\id_ed25519