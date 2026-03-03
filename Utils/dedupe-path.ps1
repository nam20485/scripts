param(
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly
)

# 1. Configuration
$registryPath = 'HKCU:\Environment'
$actualPath = (Get-ItemProperty -Path $registryPath -Name Path).Path
$targetName = 'Path'
$backupName = "Path_Backup_$(Get-Date -Format 'yyyyMMdd_HHmm')"

# 2. Targeted Purge List (The 10 "Bad" entries from your test)
$Blacklist = @(
    'oculus-runtime',              # Dead: Oculus Support
    'Perforce',                    # Dead: Perforce link
    'AnthropicClaude\app-0.13.64', # Dead: Specific versioned node_modules
    'AnthropicClaude\node_modules',# Dead: General Anthropic node path
    'Local\node_modules',          # Dead: Generic local node path
    'AppData\node_modules',        # Dead: Generic AppData node path
    'Users\node_modules',          # Dead: Root-level node junk
    'C:\node_modules',             # Dead: Root C: node junk
    'Docker\Docker\resou',         # Malformed: Truncated entry
    'ThisFolderDoesNotExist'       # Sandbox: Test entry
)

# 3. Handle Test Logic
if ($TestOnly) {
    Write-Host '🧪 [TEST MODE] Running validation on a Sandbox key...' -ForegroundColor Cyan
    $targetName = 'Path_Sandbox_Test'
    # Re-creating the test environment
    $testValue = $actualPath + ';C:\ThisFolderDoesNotExist;C:\Windows\System32' 
    New-ItemProperty -Path $registryPath -Name $targetName -Value $testValue -PropertyType String -Force
}

# 4. Processing
Write-Host "Processing $targetName..." -ForegroundColor White
$rawPath = (Get-ItemProperty -Path $registryPath -Name $targetName).$targetName
$pathArray = $rawPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }

$validPaths = $pathArray | Select-Object -Unique | Where-Object {
    $currentDir = $_.Trim()
    
    # Check against Blacklist first
    $isBlacklisted = $false
    foreach ($pattern in $Blacklist) {
        if ($currentDir -like "*$pattern*") { $isBlacklisted = $true; break }
    }

    if ($isBlacklisted) {
        Write-Host "   [!] Blacklist skip: $currentDir" -ForegroundColor DarkYellow
        return $false
    }

    # Validate existence
    if (Test-Path -Path $currentDir) {
        return $true
    }
    else {
        Write-Host "   [-] Removing dead: $currentDir" -ForegroundColor Yellow
        return $false
    }
}

$cleanPath = $validPaths -join ';'

# 5. Finalizing
if ($TestOnly) {
    Set-ItemProperty -Path $registryPath -Name $targetName -Value $cleanPath
    Write-Host "`n✅ Test Complete. Results saved to: $targetName" -ForegroundColor Green
    Write-Host "Original: $($rawPath.Length) chars | Cleaned: $($cleanPath.Length) chars"
}
else {
    # Real Run
    New-ItemProperty -Path $registryPath -Name $backupName -Value $actualPath -PropertyType String -Force
    Set-ItemProperty -Path $registryPath -Name Path -Value $cleanPath
    Write-Host "`n✅ LIVE UPDATE COMPLETE." -ForegroundColor Green
    Write-Host "Backup saved as: $backupName"
    Write-Host "Old Length: $($actualPath.Length) | New Length: $($cleanPath.Length)"
}