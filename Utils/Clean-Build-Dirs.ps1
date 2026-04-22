<#
.SYNOPSIS
    Recursively finds and removes build artifact directories.
.DESCRIPTION
    Searches for 'bin', 'obj', 'vcpkg_installed', and 'out/build' directories.
    Converts all paths to forward slashes and prompts the user for deletion
    with options for (y)es, (n)o, (a)ll, or (q)uit.
#>

param(
    [Parameter(Position=0)]
    [string]$SearchPath = "."
)

Write-Host "Scanning '$SearchPath' for build artifacts (bin, obj, vcpkg_installed, out/build)..." -ForegroundColor Cyan

# 1. Search the tree and collect the target directory paths
$foundDirs = Get-ChildItem -Path $SearchPath -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
    $dirName = $_.Name.ToLower()

    # Match standard dirs
    if ($dirName -match '^(bin|obj|vcpkg_installed)$') {
        return $true
    }

    # Match 'out/build' (where current dir is 'build' and parent is 'out')
    if ($dirName -eq 'build' -and $null -ne $_.Parent -and $_.Parent.Name.ToLower() -eq 'out') {
        return $true
    }

    return $false
} | Select-Object -ExpandProperty FullName

if (-not $foundDirs) {
    Write-Host "No target build directories found." -ForegroundColor Green
    return
}

# 2. Normalize paths to use forward slashes (cross-platform requirement)
$normalizedPaths = $foundDirs | ForEach-Object { $_.Replace('\', '/') }

# 3. List all the found paths
Write-Host "`nFound $($normalizedPaths.Count) target directories:" -ForegroundColor Yellow
foreach ($path in $normalizedPaths) {
    Write-Host "  $path"
}
Write-Host ""

# 4. Process deletion with interactive prompt
$deleteAll = $false

foreach ($dir in $normalizedPaths) {
    # If a parent directory was already deleted, the child won't exist anymore. Skip it.
    if (-not (Test-Path -Path $dir)) {
        continue
    }

    if ($deleteAll) {
        Write-Host "Deleting: $dir" -ForegroundColor DarkGray
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        continue
    }

    $validResponse = $false
    while (-not $validResponse) {
        $response = Read-Host "Delete this path? $dir (y)es/(n)o/(a)ll/(q)uit"

        switch ($response.Trim().ToLower()) {
            'y' {
                try {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                    Write-Host "  Deleted." -ForegroundColor Green
                } catch {
                    Write-Host "  Failed to delete: $_" -ForegroundColor Red
                }
                $validResponse = $true
            }
            'n' {
                Write-Host "  Skipped." -ForegroundColor DarkGray
                $validResponse = $true
            }
            'a' {
                $deleteAll = $true
                try {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                    Write-Host "  Deleted. (Will automatically delete remaining paths)" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed to delete: $_" -ForegroundColor Red
                }
                $validResponse = $true
            }
            'q' {
                Write-Host "Operation aborted by user." -ForegroundColor Yellow
                return
            }
            default {
                Write-Host "  Invalid choice. Please enter y, n, a, or q." -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nCleanup finished successfully!" -ForegroundColor Cyan
