Import-Module Utils

Start-As-Admin

Write-Host "Installed Distros: "
wsl --list --all

$distros = wsl --list --all | Select-String -Pattern "^[a-zA-Z]"
$confirmed = 'n'
foreach ($distro in $distros) {   
    $distroName = $distro.ToString().Split(" ")[0]    
    if ("Aa".NotContains($confirmed)) {
        $confirmed = Read-Host -Prompt "Uninstall (unregister) $distroName? (y)es/(n)o/(a)ll"
    }
    elseif ("yYAa".Contains($confirmed)) {
        Write-Host "Unregistering $distroName..."
        wsl --unregister $distroName
        Write-Host "$distroName unregistered."
    }   
    elseif ("Nn".Contains($confirmed)) {
        Write-Host "OK- Leaving $distroName installed."
    } 
}    

Write-Host "All WSL distributions have been unregistered."
$confirmed = Read-Host -Prompt "Uninstall WSL Features? (y/n)"
elseif ("yY".Contains($confirmed)) {
        Write-Host "Uninstalling WSL Features..."
        dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /all /norestart
        Write-Host "WSL Features removed"
    }

if ("Nn".NotContains($confirmed)) {
    $confirmed = Read-Host "WSL removed. Reboot now (recommended) (y/n)?"
    if ("Yy".Contains($confirmed))  {
        Restart-Computer
    }
}