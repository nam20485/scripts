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
        } catch {
            $resolved = $expanded
        }
        # Remove malformed entries (e.g. incomplete paths)
        if ($resolved -match '^[A-Za-z]:\\' -and -not ($canonicalShells -contains $resolved)) {
            $canonicalShells += $resolved
        }
    }
    return $canonicalShells
}