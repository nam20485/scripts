# This script checks the status of all git repositories recursively from a specified location.

param (
    [string]$StartPath = (Get-Location).Path
)

function Get-GitStatus {
    param (
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        $status = git status --porcelain
        $branchInfo = git status -b --porcelain | Select-String -Pattern "##"

        $branchDetails = $branchInfo -split ' ' | Select-Object -Skip 1
        $branchName = $branchDetails[0]
        $remoteStatus = if ($branchDetails.Length -gt 1) { $branchDetails[1] } else { "Up-to-date" }

        return [PSCustomObject]@{
            Path = $RepoPath
            Branch = $branchName
            RemoteStatus = $remoteStatus
            LocalChanges = if ($status) { $true } else { $false }
        }
    } catch {
        Write-Error "Failed to get git status for ${RepoPath}: $_"
    } finally {
        Pop-Location
    }
}

# Renaming the function to use an approved verb
function Get-GitRepos-Status {
    param (
        [string]$Path
    )

    $repos = Get-ChildItem -Path $Path -Recurse -Directory | Where-Object {
        Test-Path -Path (Join-Path $_.FullName ".git")
    }

    $summary = @()

    foreach ($repo in $repos) {
        $repoStatus = Get-GitStatus -RepoPath $repo.FullName
        if ($repoStatus) {
            $summary += $repoStatus
        }
    }

    return $summary
}

# Main execution
$results = Get-GitRepos-Status -Path $StartPath

Write-Host "Summary of Git Repositories:" -ForegroundColor Green
$results | ForEach-Object {
    Write-Host "Path: $($_.Path)" -ForegroundColor Cyan
    Write-Host "Branch: $($_.Branch)" -ForegroundColor Yellow
    Write-Host "Remote Status: $($_.RemoteStatus)" -ForegroundColor Magenta
    Write-Host "Local Changes: $($_.LocalChanges)" -ForegroundColor Red
    Write-Host "-----------------------------"
}

#Export-ModuleMember -Function 'Get-GitRepos'
# This script checks the status of all git repositories recursively from a specified location.

param (
    [string]$StartPath = (Get-Location).Path
)

function Get-GitStatus {
    param (
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        $status = git status --porcelain
        $branchInfo = git status -b --porcelain | Select-String -Pattern "##"

        $branchDetails = $branchInfo -split ' ' | Select-Object -Skip 1
        $branchName = $branchDetails
        $remoteStatus = if ($branchDetails.Length -gt 1) { $branchDetails[1] } else { "Up-to-date" }

        return [PSCustomObject]@{
            Path = $RepoPath
            Branch = $branchName
            RemoteStatus = $remoteStatus
            LocalChanges = if ($status) { $true } else { $false }
        }
    } catch {
        Write-Error "Failed to get git status for ${RepoPath}: $_"
    } finally {
        Pop-Location
    }
}

# Renaming the function to use an approved verb
function Get-GitRepos-Status {
    param (
        [string]$Path
    )

    $repos = Get-ChildItem -Path $Path -Recurse -Directory | Where-Object {
        Test-Path -Path (Join-Path $_.FullName ".git")
    }

    $summary = @()

    foreach ($repo in $repos) {
        $repoStatus = Get-GitStatus -RepoPath $repo.FullName
        if ($repoStatus) {
            $summary += $repoStatus
        }
    }

    return $summary
}

# Main execution
$results = Get-GitRepos-Status -Path $StartPath

Write-Host "Summary of Git Repositories:" -ForegroundColor Green
$results | ForEach-Object {
    Write-Host "Path: $($_.Path)" -ForegroundColor Cyan
    Write-Host "Branch: $($_.Branch)" -ForegroundColor Yellow
    Write-Host "Remote Status: $($_.RemoteStatus)" -ForegroundColor Magenta
    Write-Host "Local Changes: $($_.LocalChanges)" -ForegroundColor Red
    Write-Host "-----------------------------"
}

#Export-ModuleMember -Function 'Get-GitRepos'