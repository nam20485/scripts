# This script lists available shells on the system and allows the user to set the OpenSSH server's default shell in the Windows registry.

# Get available shells from the system
function Get-AvailableShells {
    $shells = @()

    # Add common shells if they exist
    if (Test-Path "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe") {
        $shells += "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    }
    if (Test-Path "C:\\Windows\\System32\\cmd.exe") {
        $shells += "C:\\Windows\\System32\\cmd.exe"
    }
    if (Test-Path "C:\\Program Files\\Git\\bin\\bash.exe") {
        $shells += "C:\\Program Files\\Git\\bin\\bash.exe"
    }
    if (Test-Path "C:\\Windows\\System32\\wsl.exe") {
        $shells += "C:\\Windows\\System32\\wsl.exe"
    }

    return $shells
}

# Set the default shell for OpenSSH server
function Set-DefaultShell {
    param (
        [string]$ShellPath
    )

    $registryPath = "HKLM:\\SOFTWARE\\OpenSSH"
    $registryKey = "DefaultShell"

    try {
        # Backup existing value if it exists
        if (Test-Path "$registryPath") {
            $existingValue = (Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue).$registryKey
            if ($existingValue) {
                $backupPath = "$registryPath\\DefaultShellBackup"
                Set-ItemProperty -Path $registryPath -Name "DefaultShellBackup" -Value $existingValue -Force
                Write-Host "Existing default shell backed up: $existingValue" -ForegroundColor Yellow

                # Write backup to a .reg file
                $regFilePath = "DefaultShellBackup.reg"
                $regContent = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH]
"DefaultShellBackup"="$existingValue"
"@
                $regContent | Out-File -FilePath $regFilePath -Encoding ASCII -Force
                Write-Host "Backup written to $regFilePath" -ForegroundColor Yellow
            }
        }

        # Set the new default shell
        Set-ItemProperty -Path $registryPath -Name $registryKey -Value $ShellPath -Force
        Write-Host "Default shell for OpenSSH server set to: $ShellPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to set default shell: $_"
    }
}

# Main execution
$shells = Get-AvailableShells

# Get the current default shell
$registryPath = "HKLM:\\SOFTWARE\\OpenSSH"
$registryKey = "DefaultShell"
$currentShell = $null
if (Test-Path "$registryPath") {
    $currentShell = (Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue).$registryKey
}

if ($shells.Count -eq 0) {
    Write-Host "No available shells found on the system." -ForegroundColor Red
    exit 1
}

Write-Host "Current OpenSSH default shell: $currentShell" -ForegroundColor Yellow
Write-Host "Available shells:" -ForegroundColor Cyan

for ($i = 0; $i -lt $shells.Count; $i++) {
    Write-Host "[$i] $($shells[$i])"
}

Write-Host "[Press Enter without typing a number to keep the current default shell]" -ForegroundColor Cyan

$selection = Read-Host "Enter the number of the shell you want to set as the default"

if ($selection -eq "") {
    Write-Host "No changes made to the current default shell." -ForegroundColor Green
} elseif ($selection -match "^\d+$" -and $selection -ge 0 -and $selection -lt $shells.Count) {
    $selectedShell = $shells[$selection]
    Set-DefaultShell -ShellPath $selectedShell
} else {
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    exit 1
}
