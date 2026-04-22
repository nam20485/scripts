<#
.SYNOPSIS
    Recursively finds and removes build artifact directories.
.DESCRIPTION
    Searches for 'bin', 'obj', 'vcpkg_installed', and 'out/build' directories.
    Converts all paths to forward slashes and prompts the user for deletion
    with options for (y)es, (n)o, (a)ll, or (q)uit.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SearchPath
)

Write-Host "Scanning '$SearchPath' for build artifacts (bin, obj, vcpkg_installed, out/build)..." -ForegroundColor Cyan

$totalTimer = [System.Diagnostics.Stopwatch]::StartNew()
$searchTimer = [System.Diagnostics.Stopwatch]::StartNew()

# 1. Custom Breadth-First Search to find targets (and actively avoid scanning inside them)
$normalizedPaths = @()
$searchQueue = New-Object System.Collections.Queue

try
{
    $initialDir = Get-Item -LiteralPath $SearchPath -ErrorAction Stop
    $searchQueue.Enqueue($initialDir)
} catch
{
    Write-Host "Invalid search path: $SearchPath" -ForegroundColor Red
    return
}

while ($searchQueue.Count -gt 0)
{
    $currentDir = $searchQueue.Dequeue()

    # Get immediate child directories only
    $subDirs = Get-ChildItem -LiteralPath $currentDir.FullName -Directory -Force -ErrorAction SilentlyContinue

    foreach ($dir in $subDirs)
    {
        $dirName = $dir.Name.ToLower()
        $isTarget = $false

        # Match standard dirs
        if ($dirName -match '^(bin|obj|vcpkg_installed)$')
        {
            $isTarget = $true
        }
        # Match 'out/build'
        elseif ($dirName -eq 'build' -and $currentDir.Name.ToLower() -eq 'out')
        {
            $isTarget = $true
        }

        if ($isTarget)
        {
            # Add to list with normalized slashes
            $normalizedPaths += $dir.FullName.Replace('\', '/')
            # CRITICAL: We intentionally do NOT enqueue this directory.
            # This prevents finding nested targets like 'bin/obj' and vastly speeds up the script.
        } else
        {
            # Not a target, queue it up to search its contents
            $searchQueue.Enqueue($dir)
        }
    }
}

$searchTimer.Stop()

if ($normalizedPaths.Count -eq 0)
{
    Write-Host "No target build directories found. (Search took $('{0:N3}' -f $searchTimer.Elapsed.TotalSeconds) s)" -ForegroundColor Green
    $totalTimer.Stop()
    return
}

# 2. List all the found paths
Write-Host "`nFound $($normalizedPaths.Count) target directories in $('{0:N3}' -f $searchTimer.Elapsed.TotalSeconds) s:" -ForegroundColor Yellow
foreach ($path in $normalizedPaths)
{
    Write-Host "  $path"
}
Write-Host ""

# 4. Process deletion with interactive prompt
$deleteAll = $false
$deleteAllTimer = $null

foreach ($dir in $normalizedPaths)
{
    # If a parent directory was already deleted, the child won't exist anymore. Skip it.
    if (-not (Test-Path -Path $dir))
    {
        continue
    }

    if ($deleteAll)
    {
        Write-Host "Deleting: $dir" -ForegroundColor DarkGray
        try
        {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
        } catch
        {
            Write-Host "  Failed to delete: $_" -ForegroundColor Red
        }
        continue
    }

    $validResponse = $false
    while (-not $validResponse)
    {
        Write-Host "Delete this path? $dir (y)es/(n)o/(a)ll/(q)uit: " -NoNewline

        # Read a single key press without requiring Enter
        $response = [System.Console]::ReadKey($true).KeyChar.ToString().ToLower()
        Write-Host $response # Echo the pressed key

        switch ($response)
        {
            'y'
            {
                $delTimer = [System.Diagnostics.Stopwatch]::StartNew()
                try
                {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                    $delTimer.Stop()
                    Write-Host "  Deleted in $('{0:N3}' -f $delTimer.Elapsed.TotalSeconds) s." -ForegroundColor Green
                } catch
                {
                    $delTimer.Stop()
                    Write-Host "  Failed to delete: $_" -ForegroundColor Red
                }
                $validResponse = $true
            }
            'n'
            {
                Write-Host "  Skipped." -ForegroundColor DarkGray
                $validResponse = $true
            }
            'a'
            {
                $deleteAll = $true
                $deleteAllTimer = [System.Diagnostics.Stopwatch]::StartNew()
                try
                {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                    Write-Host "  Deleted. (Will automatically delete remaining paths)" -ForegroundColor Green
                } catch
                {
                    Write-Host "  Failed to delete: $_" -ForegroundColor Red
                }
                $validResponse = $true
            }
            'q'
            {
                Write-Host "Operation aborted by user." -ForegroundColor Yellow
                $totalTimer.Stop()
                Write-Host "Total execution time: $('{0:N3}' -f $totalTimer.Elapsed.TotalSeconds) s." -ForegroundColor DarkGray
                return
            }
            default
            {
                Write-Host "  Invalid choice. Please press y, n, a, or q." -ForegroundColor Red
            }
        }
    }
}

if ($deleteAll -and $null -ne $deleteAllTimer)
{
    $deleteAllTimer.Stop()
    Write-Host "`nBulk deletion completed in $('{0:N3}' -f $deleteAllTimer.Elapsed.TotalSeconds) s." -ForegroundColor Green
}

$totalTimer.Stop()
Write-Host "`nCleanup finished successfully! Total time: $('{0:N3}' -f $totalTimer.Elapsed.TotalSeconds) s." -ForegroundColor Cyan
