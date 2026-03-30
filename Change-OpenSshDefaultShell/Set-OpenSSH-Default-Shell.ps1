# This script lists available shells on the system and allows the user to set the OpenSSH server's default shell in the Windows registry.

# Import the module containing shell path functions
try
{
    $modulePath = Join-Path $PSScriptRoot 'OpenSshDefaultShellUtils.psm1'
    Import-Module -Name $modulePath -ErrorAction Stop
}
catch
{
    Write-Error "Failed to import the OpenSshDefaultShellUtils module. Ensure OpenSshDefaultShellUtils.psm1 is in the same directory as this script. Error: $($_.Exception.Message)"
    exit 1
}

# Main execution

# Use the Get-AllShellPaths function to retrieve all shell paths
$shells = Get-AllShellPaths

# Debug: Output the raw value of $shells for troubleshooting
Write-Host "[DEBUG] Raw shells array: $($shells -join ', ')" -ForegroundColor DarkGray

if (-not $shells -or @($shells).Count -eq 0)
{
    Write-Host "No available shells found on the system." -ForegroundColor Red
    exit 1
}

# Get the currently-configured shell
$currentShell = Get-CurrentDefaultShell

Write-Host "Current OpenSSH default shell: $currentShell" -ForegroundColor Yellow
Write-Host "Available shells:" -ForegroundColor Cyan

for ($i = 0; $i -lt $shells.Count; $i++)
{
    Write-Host "[$i] $($shells[$i])"
}

Write-Host "[Press Enter without typing a number to keep the current default shell]" -ForegroundColor Cyan

$selection = Read-Host "Enter the number of the shell you want to set as the default"

if ($selection -eq "")
{
    Write-Host "No changes made to the current default shell." -ForegroundColor Green
}
elseif ($selection -match "^\d+$" -and $selection -ge 0 -and $selection -lt $shells.Count)
{
    $selectedShell = $shells[$selection]
    Set-DefaultShell -ShellPath $selectedShell
}
else
{
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    exit 1
}
