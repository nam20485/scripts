function Get-OpenSshServerDefaultShell {
    $defaultShell = Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell
    return $defaultShell
}

function Set-OpenSshServerDefaultShell {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', PositionalBinding = $false)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ShellPath
    )

    if (-not (Test-Path $ShellPath)) {
        Write-Output "The path you entered does not exist. Please check the path and try again."        
    }
    else {
        $updatePath = Read-Host "Update the default shell to $ShellPath? (Y/N)"
        if ($updatePath -ne "Y" -and $updatePath -ne "y") {
            Write-Output "Operation cancelled by user."                        
        }
        else {
            # export existing registry key to a file for backup
            function Backup-RegistryKey {
                param (                    
                    [string, Mandatory]$RegistryPath                  
                )               
                if (Test-Path $regPath) {
                    $backupFile = "./OpenSshServerDefaultShellBackup.reg"
                    Export-RegistryKey -Path $RegistryPath -Destination $backupFile -Force
                    Write-Output "Backup of existing registry key created at $Path"
                } else {
                    Write-Output "Registry path $regPath does not exist. No backup created."
                }
            }

            New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $ShellPath -PropertyType String -Force
            return $true
        }
    }    

    return $false
}

# Have user select a new default shell from a list of options or enter their own.
$defaultShellOptions = @(
    "I want to enter my own shell path"
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    "C:\Windows\System32\cmd.exe",
    "C:\Windows\System32\WindowsPowerShell\v1.0\pwsh.exe",
    "C:\Windows\System32\bash.exe"
)

$shellIndex = 1;
foreach ($option in $defaultShellOptions) {
    Write-Host "${shellIndex}: $option"   
    $shellIndex++
}

$shellUpdated = $false

do {
$shellSelection = Read-Host "Enter selection for new default shell, 0 to enter your own path, or leave blank to keep current default shell"

if ($shellSelection -eq "0") {
    $customShellPath = Read-Host "Enter your own shell path"
    $shellUpdated = Set-OpenSshServerDefaultShell -ShellPath $customShellPath
}
elseif ($shellSelection -eq "") {
    Write-Output "Keeping current default shell."
    $shellUpdated = $true
}
elseif ($shellSelection -gt 1 -and $shellSelection -lt $defaultShellOptions.Count) {
    $selectedShell = $defaultShellOptions[$shellSelection]
    $shellUpdated = Set-OpenSshServerDefaultShell -ShellPath $selectedShell        
}
else {
        Write-Output "Invalid selection. Please select a valid option."
    }
} while ($shellUpdated -eq $false)

if ($shellUpdated) {
    Write-Output "Default shell updated successfully."
} else {
    Write-Output "Failed to update default shell (or no changes made)."
}
