<#
.SYNOPSIS
    Utility functions for GPG key management, Git configuration, and GitHub GPG API integration.
.DESCRIPTION
    This module provides reusable functions for generating GPG keys, exporting public keys, configuring git, and adding GPG keys to GitHub. Designed for use in scripts and interactive sessions.
#>

function Read-GpgUserDetails {
    param(
        [string]$Email,
        [string]$Name,
        [string]$Comment
    )
    if (-not $Email) { $Email = Read-Host "Enter your email for the GPG key" }
    if (-not $Name) { $Name = Read-Host "Enter your name for the GPG key" }
    if ($null -eq $Comment) { $Comment = Read-Host "Enter a comment for the GPG key (optional)" }
    return @{ Email = $Email; Name = $Name; Comment = $Comment }
}

function Get-GpgKeyInfo {
    param(
        [string]$Email
    )
    $existingKeyInfo = gpg --list-secret-keys --with-colons $Email | Select-String '^sec:' | Select-Object -First 1
    if (-not $existingKeyInfo) { return $null }
    $existingKeyLine = $existingKeyInfo.ToString().Split(':')
    $existingKey = $existingKeyLine[4]
    $uidInfo = gpg --list-secret-keys --with-colons $Email | Select-String '^uid:' | Select-Object -First 1
    $existingName = $null; $existingComment = $null
    if ($uidInfo) {
        $uidFields = $uidInfo.ToString().Split(':')
        $uidString = $uidFields[9]
        if ($uidString -match '^(.*?) ?\((.*?)\)? <.*?>$') {
            $existingName = $matches[1].Trim()
            $existingComment = $matches[2].Trim()
        } elseif ($uidString -match '^(.*?) <.*?>$') {
            $existingName = $matches[1].Trim()
            $existingComment = ""
        }
    }
    # Check if revoked or expired
    $secLine = gpg --list-secret-keys --with-colons $Email | Select-String '^sec:' | Select-Object -First 1
    $usable = $true
    if ($secLine) {
        $fields = $secLine.ToString().Split(':')
        $keyStatus = $fields[1]
        if ($keyStatus -match 'r' -or $keyStatus -match 'e') { $usable = $false }
    }
    return @{ Key = $existingKey; Name = $existingName; Comment = $existingComment; Usable = $usable }
}

function New-GpgBatchFile {
    param(
        [string]$Name,
        [string]$Email,
        [string]$Comment,
        [string]$Password
    )
    $gpgBatchLines = @(
        "Key-Type: default",
        "Key-Length: 4096",
        "Subkey-Type: default",
        "Name-Real: $Name"
    )
    if ($Comment -and $Comment.Trim() -ne "") {
        $gpgBatchLines += "Name-Comment: $Comment"
    }
    $gpgBatchLines += @(
        "Name-Email: $Email",
        "Expire-Date: 1y"
    )
    if ($Password -eq "") {
        $gpgBatchLines += "%no-protection"
    }
    $gpgBatch = $gpgBatchLines -join "`n"
    $gpgBatchFile = "$env:TEMP\gpg-batch.txt"
    $gpgBatch | Set-Content -Path $gpgBatchFile -Encoding ascii
    return $gpgBatchFile
}

function New-GpgKey {
    param(
        [string]$Name,
        [string]$Email,
        [string]$Comment,
        [string]$Password
    )
    $gpgBatchFile = New-GpgBatchFile -Name $Name -Email $Email -Comment $Comment -Password $Password
    Write-Host "Generating GPG key..."
    if ($Password -eq "") {
        gpg --batch --generate-key $gpgBatchFile
    } else {
        gpg --batch --pinentry-mode loopback --passphrase $Password --generate-key $gpgBatchFile
    }
    # Get the new key's fingerprint (the most recent secret key for this email)
    $fingerprint = gpg --list-secret-keys --with-colons $Email | Select-String '^fpr:' | Select-Object -Last 1 | ForEach-Object { $_.ToString().Split(':')[9] }
    return $fingerprint
}

function Export-GpgPublicKey {
    param(
        [string]$Fingerprint
    )
    return (gpg --armor --export $Fingerprint) -join "`n"
}

function Add-GitHubGpgKey {
    param(
        [string]$PublicKey,
        [string]$GitHubToken
    )
    $apiUrl = "https://api.github.com/user/gpg_keys"
    $responseCode = $null
    $responseMessage = $null
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ Authorization = "token $GitHubToken" } -Method Post -Body (@{ armored_public_key = $PublicKey } | ConvertTo-Json)
        return @{ Success = $true; Code = 201; Message = "Created" }
    } catch {
        if ($_.Exception.Response) {
            $responseCode = $_.Exception.Response.StatusCode.value__
            $responseMessage = $_.Exception.Response.StatusDescription
            if ($responseCode -eq 422) {
                return @{ Success = $false; Code = 422; Message = "Key already exists" }
            }
            return @{ Success = $false; Code = $responseCode; Message = $responseMessage }
        } else {
            return @{ Success = $false; Code = 0; Message = $_.Exception.Message }
        }
    }
}

function Set-GitSigningConfig {
    param(
        [string]$Fingerprint
    )
    $configureGitSigningKey = $true
    $existingGitSigningKey = git config --global user.signingkey
    if ($existingGitSigningKey) {
        if ($existingGitSigningKey -eq $Fingerprint) {
            Write-Host "The GPG key is already configured for signing in git." -ForegroundColor Yellow
            $configureGitSigningKey = $false
        }
    }
    $configureGitGpgSign = $true
    $existingGitGpgSign = git config --global commit.gpgsign
    if ($existingGitGpgSign) {
        if ($existingGitGpgSign -eq "true") {
            Write-Host "Git is already configured to sign commits." -ForegroundColor Yellow
            $configureGitGpgSign = $false
        }
    }
    if ($configureGitSigningKey) {
        git config --global user.signingkey $Fingerprint
        Write-Host "Git is now configured to use this GPG key for signing: $Fingerprint"
    }
    if ($configureGitGpgSign) {
        git config --global commit.gpgsign true
        Write-Host "Git is now configured to sign commits by default."
    }
    Write-Host "Git GPG signing configuration successful" -ForegroundColor Green
}

function Get-GitHubToken {
    param(
        [string]$Token
    )
    if ($Token) { return $Token }
    if ($env:GITHUB_GPG_KEY_TOKEN) {
        $secureToken = ConvertTo-SecureString $env:GITHUB_GPG_KEY_TOKEN -AsPlainText -Force
        return [System.Net.NetworkCredential]::new("", $secureToken).Password
    }
    return Read-Host "Enter your GitHub Personal Access Token (with admin:gpg_key scope)"
}

Export-ModuleMember -Function Read-GpgUserDetails,Get-GpgKeyInfo,New-GpgBatchFile,New-GpgKey,Export-GpgPublicKey,Add-GitHubGpgKey,Set-GitSigningConfig,Get-GitHubToken
