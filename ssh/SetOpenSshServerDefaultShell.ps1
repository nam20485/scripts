$currentShell = Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell
Write-Output "Current Default Shell: $currentShell"

# export the current default shell to a reg file for backup purposes
$regFilePath = "C:\OpenSshServerDefaultShellBackup.reg"
$regFileContent = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH]
"@DefaultShell"="$currentShell"
"@
Set-Content -Path $regFilePath -Value $regFileContent -Force


# Have user select a new default shell from a list of options or enter their own.
$defaultShellOptions = @(
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    "C:\Windows\System32\cmd.exe",
    "C:\Windows\System32\WindowsPowerShell\v1.0\pwsh.exe",
    "C:\Windows\System32\bash.exe",
    "<I want to enter my own shell path>",
    "<Nevermind, thank you but I changed my mind and want to keep the current default shell>"
)

$shellIndex = 1;
Write-Host "Select a new default shell:"
foreach ($option in $defaultShellOptions) {
    Write-Host "${shellIndex}: $option"
    $shellIndex++
}

$shellSelection = Read-Host "Enter selection for new default shell, 0 to enter your own path, or leave blank to keep current default shell"

if ($shellSelection -eq "0") {
    $customShellPath = Read-Host "Enter your own shell path"
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $customShellPath -PropertyType String -Force
} elseif ($shellSelection -eq "") {
    Write-Output "Keeping current default shell."
} else {
    $selectedShell = $defaultShellOptions[$shellSelection]
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $selectedShell -PropertyType String -Force
}

