Import-Module Utils

Start-As-Admin

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

$installDefaultUbuntu = Read-Host "Install default distro (Ubuntu 24.04)?"
if ($installDefaultUbuntu -eq $true) {
    wsl --install
}

wsl --list --online
$installMoreDistros = $false
while ($installMoreDistros -eq $false) {
    $installMoreDistros = Read-Host "Install another distro?"
}

if ($install) {
    wsl --install
}

wsl --update

# restart computer
$restart = Read-Host "Restart computer?"
if ($restart -eq $true) {
    Restart-Computer
}