Import-Module Utils

Start-As-Admin

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

$installDefaultUbuntu = Read-Host "Install default distro (Ubuntu 24.04)?"
wsl --install

$installMoreDistros = $false
while ($installMoreDistros -eq )
$installMoreDistros = Read-Host "Install another distro?"

if (%install)


wsl --update