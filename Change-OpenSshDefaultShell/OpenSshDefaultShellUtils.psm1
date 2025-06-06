function Get-AvailableShellPaths {
   
    $shellNames = @(
        "powershell.exe",
        "pwsh.exe",
        "cmd.exe",
        "bash.exe",
        "wsl.exe"
    )

    $searchPaths = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64",
        "$env:ProgramFiles\PowerShell\7",
        "$env:ProgramFiles\Git\bin",
        "$env:ProgramFiles\Git\usr\bin"
    )

    $foundShells = @()

    foreach ($shell in $shellNames) {
        # Search in PATH
        $shellPath = (Get-Command $shell -ErrorAction SilentlyContinue)?.Source
        if ($shellPath -and -not ($foundShells -contains $shellPath)) {
            $foundShells += $shellPath
        }

        # Search in common directories
        foreach ($dir in $searchPaths) {
            $fullPath = Join-Path $dir $shell
            if ((Test-Path $fullPath -PathType Leaf) -and -not ($foundShells -contains $fullPath)) {
                $foundShells += $fullPath
            }
        }
    }

    return $foundShells
}


# Returns a list of shell paths found in Windows Terminal profiles
function Get-WindowsTerminalProfileShellPaths {
    <#
    .SYNOPSIS
        Returns a list of shell paths found in Windows Terminal profiles.

    .DESCRIPTION
        Reads the Windows Terminal settings.json file and extracts the commandline or source fields from each profile.

    .EXAMPLE
        $wtShells = Get-WindowsTerminalProfileShellPaths
        $wtShells | ForEach-Object { Write-Host $_ }
    #>

    $settingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )

    $shellPaths = @()

    foreach ($settingsPath in $settingsPaths) {
        if (Test-Path $settingsPath) {
            try {
                $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
                $profiles = $json.profiles.list
                foreach ($wtProfile in $profiles) {
                    if ($wtProfile.commandline) {
                        $cmd = $wtProfile.commandline
                        # Remove surrounding quotes and expand environment variables
                        $cmd = $cmd -replace '^[\"]|[\"]$', ''
                        $cmd = [Environment]::ExpandEnvironmentVariables($cmd)
                        $exe = $cmd -split '\s+' | Select-Object -First 1
                        $exe = $exe.Trim('"')
                        # Canonicalize and filter malformed entries
                        try {
                            $resolved = (Resolve-Path $exe -ErrorAction Stop).Path
                        } catch {
                            $resolved = $exe
                        }
                        # Only add if it is a valid absolute path to an executable
                        if ($resolved -match '^[A-Za-z]:\\.+\\[^\\]+\\?[^\\]*\\?[^\\]*\\?[^\\]*$' -and (Test-Path $resolved -PathType Leaf) -and -not ($shellPaths | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $resolved })) {
                            $shellPaths += $resolved
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to parse $($settingsPath): $($_.Exception.Message)"
            }
        }
    }

    # Remove empty or whitespace-only entries
    return $shellPaths | Where-Object { $_ -and $_.Trim() -ne "" }
}


# Combines the output of Get-AvailableShellPaths and Get-WindowsTerminalProfileShellPaths
function Get-AllShellPaths {
    $systemShells = Get-AvailableShellPaths
    $wtShells = Get-WindowsTerminalProfileShellPaths
    $allShells = $systemShells + $wtShells | Sort-Object -Unique

    return $allShells
}

function Backup-CurrenDefaultShell {
    # Parameter help description
    param (
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath,
        [Parameter(Mandatory = $true)]
        [string]$RegistryKey
    )

    if (Test-Path "$RegistryPath") {
        $existingValue = (Get-ItemProperty -Path $RegistryPath -Name $RegistryKey -ErrorAction SilentlyContinue).$registryKey
        if ($existingValue) {
            # backup in a new key next to the existing one
            Set-ItemProperty -Path $RegistryPath -Name "DefaultShellBackup" -Value $existingValue -Force
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
}

# Set the default shell for OpenSSH server
function Set-DefaultShell {
    param (
        [string]$ShellPath
    )

    $registryPath = "HKLM:\SOFTWARE\OpenSSH"
    $registryKey = "DefaultShell"

    try {
        # Backup existing value if it exists
        Backup-CurrenDefaultShell -RegistryPath $registryPath -RegistryKey $registryKey

        # Set the new default shell
        Set-ItemProperty -Path $registryPath -Name $registryKey -Value $ShellPath -Force
        Write-Host "Default shell set to: $ShellPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to set default shell: $_" -ForegroundColor Red
    }
}
Export-ModuleMember -Function Get-AvailableShellPaths, Get-WindowsTerminalProfileShellPaths, Get-AllShellPaths