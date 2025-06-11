

<##
.SYNOPSIS
    Setup-GPG-GitHub.ps1 - Generate a GPG key, configure git, and add the public key to GitHub.
.DESCRIPTION
    This script generates a new GPG key (optionally with a password), configures git to use it for commit signing, and adds the public key to your GitHub profile via the API. It handles existing keys, user prompts, error handling, and can be used interactively or with parameters for automation.
.PARAMETER Email
    The email address for the GPG key.
.PARAMETER Name
    The real name for the GPG key.
.PARAMETER Comment
    An optional comment for the GPG key.
.PARAMETER Password
    An optional password for the GPG key.
.PARAMETER GitHubToken
    A GitHub Personal Access Token with admin:gpg_key scope.
##>

param(
    [string]$Email,
    [string]$Name,
    [string]$Comment = "",
    [SecureString]$Password,
    [string]$GitHubToken = ""
)

# Import the GpgGitHubUtils module
#Import-Module "$PSScriptRoot\Utils\GpgGitHubUtils.psm1"
Import-Module ".\GpgGitHubUtils.psm1"

#
# Main script logic
#

# Get user input for new key
$details = Read-GpgUserDetails -Email $Email -Name $Name -Comment $Comment
$Email = $details.Email; $Name = $details.Name; $Comment = $details.Comment

# Get information about (any) existing GPG keys
$keyInfo = Get-GpgKeyInfo -Email $Email
$generateNew = $true
if ($keyInfo -and $keyInfo.Key) {     
    $identical = ($keyInfo.Name -eq $Name -and $keyInfo.Comment -eq $Comment)
    if ($identical) {
        if (-not $keyInfo.Usable) {
            Write-Host "Identical key exists (same email, name, and comment) but the key is revoked or expired and cannot be used." -ForegroundColor Yellow
        }
        else {
            Write-Host "An identical GPG key (same email, name, and comment) already exists: $($keyInfo.Key)" -ForegroundColor Yellow
            $overwrite = Read-Host "Do you really want to overwrite it? (Y)es/(N)o/(Q)uit"
            if ($overwrite -match '^(Q|q)') {
                Write-Host "Quitting..." -ForegroundColor Yellow
                exit 1
            }
            elseif ($overwrite -notmatch '^(Y|y)') {
                $generateNew = $false
            }
        }
    }
    else {
        Write-Host "A GPG key for $Email already exists: $($keyInfo.Key) (Name: $($keyInfo.Name), Comment: $($keyInfo.Comment))" -ForegroundColor Yellow
        if (-not $keyInfo.Usable) {
            Write-Host "But the key is revoked or expired and cannot be used." -ForegroundColor Yellow
        }
        else {            
            $useExisting = Read-Host "Do you want to use the existing key? (Y)es/(N)o/(Q)uit"
            if ($useExisting -match '^(Q|q)') {
                Write-Host "Quitting..." -ForegroundColor Yellow
                exit 1
            }
            elseif ($useExisting -match '^(Y|y)') {
                $generateNew = $false
            }
        }
    }    
}

$fingerprint = $null
if ($generateNew) {
    Write-Host "Generating a new GPG key..."
    if (-not $Password) {
        $Password = Read-Host -AsSecureString "Enter a password for the new GPG key (leave blank for no password)"
    }
    $fingerprint = New-GpgKey -Name $Name -Email $Email -Comment $Comment -Password $Password
    if (-not $fingerprint) {
        Write-Host "Failed to generate a new GPG key." -ForegroundColor Red
        exit 1
    }
}
elseif ($keyInfo -and $keyInfo.Key) {
    $fingerprint = gpg --list-secret-keys --with-colons $Email | Select-String '^fpr:' | Select-Object -First 1 | ForEach-Object { $_.ToString().Split(':')[9] }
    Write-Host "Using existing GPG key: $fingerprint" -ForegroundColor Green
}

if (-not $fingerprint) {
    Write-Host "Failed to find a GPG key fingerprint (new or existing)." -ForegroundColor Red
    exit 1
}

Write-Host "GPG key fingerprint using: $fingerprint"

$GitHubToken = Get-GitHubToken -Token $GitHubToken
$pubkey = Export-GpgPublicKey -Fingerprint $fingerprint

$githubResult = Add-GitHubGpgKey -PublicKey $pubkey -GitHubToken $GitHubToken
if ($githubResult.Success -and ($githubResult.Code -eq 200 -or $githubResult.Code -eq 201)) {
    Write-Host "GPG key successfully added to your GitHub account!" -ForegroundColor Green
}
elseif ($githubResult.Code -eq 422) {
    Write-Host "GPG key already exists on GitHub!" -ForegroundColor Yellow
}
else {
    Write-Host "Failed to add GPG key to GitHub!" -ForegroundColor Red
    Write-Host "Status: $($githubResult.Code)" -ForegroundColor Red
    Write-Host "Message: $($githubResult.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "GitHub GPG key configuration successful..." -ForegroundColor Green
Set-GitSigningConfig -Fingerprint $fingerprint
Write-Host "Finished. Your commits should be signed and verified on GitHub now." -ForegroundColor Green
