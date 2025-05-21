# This script lists available shells on the system and allows the user to set the OpenSSH server's default shell in the Windows registry.

# Import the module containing shell path functions
#Import-Module -Name "./Get-AvailableShellPaths.psm1"

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
                        }
                        catch {
                            $resolved = $exe
                        }
                        # Only add if it is a valid absolute path to an executable
                        if ($resolved -match '^[A-Za-z]:\\.+\\[^\\]+\\?[^\\]*\\?[^\\]*\\?[^\\]*$' -and (Test-Path $resolved -PathType Leaf) -and -not ($shellPaths | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $resolved })) {
                            $shellPaths += $resolved
                        }
                    }
                }
            }
            catch {
                Write-Host "Failed to parse $($settingsPath): $($_)"
            }
        }
    }

    # Remove empty or whitespace-only entries
    return $shellPaths | Where-Object { $_ -and $_.Trim() -ne "" }
}


# Combines the output of Get-AvailableShellPaths and Get-WindowsTerminalProfileShellPaths
function Get-AllShellPaths {
    <#
    .SYNOPSIS
        Returns a combined list of shell paths from system and Windows Terminal profiles.

    .DESCRIPTION
        Calls Get-AvailableShellPaths and Get-WindowsTerminalProfileShellPaths, merges their results, and removes duplicates.

    .EXAMPLE
        $allShells = Get-AllShellPaths
        $allShells | ForEach-Object { Write-Host $_ }
    #>
    $systemShells = Get-AvailableShellPaths
    $wtShells = Get-WindowsTerminalProfileShellPaths
    $allShells = $systemShells + $wtShells

    # Canonicalize paths, remove malformed entries, and deduplicate
    $canonicalShells = @()
    foreach ($shell in $allShells) {
        if (-not $shell -or $shell.Trim() -eq "") { continue }
        # Expand environment variables and remove quotes
        $expanded = [Environment]::ExpandEnvironmentVariables($shell.Trim('"'))
        # Try to resolve to a full path if possible
        try {
            $resolved = (Resolve-Path $expanded -ErrorAction Stop).Path
        }
        catch {
            $resolved = $expanded
        }
        # Remove malformed entries (e.g. incomplete paths)
        if ($resolved -match '^[A-Za-z]:\\' -and -not ($canonicalShells -contains $resolved)) {
            $canonicalShells += $resolved
        }
    }
    return $canonicalShells
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
        if (Test-Path "$registryPath") {
            $existingValue = (Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue).$registryKey
            if ($existingValue) {
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
        Write-Host "Default shell set to: $ShellPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to set default shell: $_" -ForegroundColor Red
    }
}

# Main execution

# Use the Get-AllShellPaths function to retrieve all shell paths
$shells = Get-AllShellPaths

# Get the current default shell
$registryPath = "HKLM:\\SOFTWARE\\OpenSSH"
$registryKey = "DefaultShell"
$currentShell = $null
if (Test-Path "$registryPath") {
    $currentShell = (Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue).$registryKey
}

if ($shells.Count -eq 0) {
    Write-Host "No available shells found on the system." -Foregrou0ndColor Red
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
