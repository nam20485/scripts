#get string pattern to match as a parameter
param (
    [Parameter(Mandatory = $true)]
    [string]$Pattern

    # #add parameter to bypass confirmation for each repo
    # [switch]$Force
)

# Validate pattern and escape regex special characters
if (-not $Pattern -or $Pattern.Trim() -eq '') {
    Write-Host 'Error: Pattern cannot be empty or whitespace.'
    return
}
$escapedPattern = [regex]::Escape($Pattern)

# Get list of repos matching $Pattern with error handling
try {
    $repos = gh repo list --limit 1000 | Where-Object { $_ -match $escapedPattern }
}
catch {
    Write-Host "Error: Failed to retrieve repository list. $_"
    return
}

# Warn if result count hits the 1000 cap
if ($repos.Count -eq 1000) {
    Write-Host 'Warning: More than 1000 repositories match the pattern. Only the first 1000 are shown.'
}

# Short-circuit if no repositories match the pattern
if (-not $repos) {
    Write-Host "No repositories found matching pattern '$Pattern'. Nothing to delete."
    return
}

# List matching repos
Write-Host "Found the following repositories matching pattern '$Pattern':"
$repos | ForEach-Object { Write-Host $_ }

# List each and confirm deletion, options are yes, no, all, or quit
# if input is not recognized, ask again for same repo
:RepoLoop foreach ($repo in $repos) {
    $repoName = $repo.Split(' ')[0]
    while ($true) {
        $confirmation = Read-Host "Do you want to delete the repository '$repoName'? (yes/no/all/quit)"
        switch ($confirmation.ToLower()) {
            'yes' {
                try {
                    gh repo delete $repoName --confirm
                }
                catch {
                    Write-Host "Error: Failed to delete repository '$repoName'. $_"
                }
                continue RepoLoop
            }
            'no' {
                Write-Host "Skipping deletion of '$repoName'."
                continue RepoLoop
            }
            'all' {
                foreach ($remainingRepo in $repos | Where-Object { $_ -ne $repo }) {
                    $remainingRepoName = $remainingRepo.Split(' ')[0]
                    try {
                        gh repo delete $remainingRepoName --confirm
                    }
                    catch {
                        Write-Host "Error: Failed to delete repository '$remainingRepoName'. $_"
                    }
                }
                break RepoLoop
            }
            'quit' {
                Write-Host 'Exiting script.'
                break RepoLoop
            }
            default {
                Write-Host 'Invalid input. Please enter yes, no, all, or quit.'
            }
        }
    }
}