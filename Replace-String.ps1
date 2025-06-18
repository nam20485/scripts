[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    
    [Parameter(Mandatory = $true)]
    [string]$SearchPattern,
    
    [Parameter(Mandatory = $true)]
    [string]$ReplaceWith,
    
    [Parameter(Mandatory = $false)]
    [string]$FileFilter = "*.*",
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeDirectories = @(".git", ".vs", "node_modules", "bin", "obj"),
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFiles = @("*.exe", "*.dll", "*.bin", "*.zip", "*.tar", "*.gz"),
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$CaseSensitive
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Should-ExcludeDirectory {
    param([string]$DirectoryPath)
    
    $dirName = Split-Path $DirectoryPath -Leaf
    return $ExcludeDirectories -contains $dirName
}

function Should-ExcludeFile {
    param([string]$FilePath)
    
    foreach ($pattern in $ExcludeFiles) {
        if ($FilePath -like $pattern) {
            return $true
        }
    }
    return $false
}

# Validate directory exists
if (-not (Test-Path $Directory -PathType Container)) {
    Write-Error "Directory '$Directory' does not exist."
    exit 1
}

$Directory = Resolve-Path $Directory

Write-ColorOutput "Starting recursive replace operation..." "Green"
Write-ColorOutput "Directory: $Directory" "Cyan"
Write-ColorOutput "Search Pattern: '$SearchPattern'" "Yellow"
Write-ColorOutput "Replace With: '$ReplaceWith'" "Yellow"
Write-ColorOutput "File Filter: $FileFilter" "Cyan"

if ($WhatIf) {
    Write-ColorOutput "WHAT-IF MODE: No files will be modified" "Magenta"
}

$totalFiles = 0
$modifiedFiles = 0
$totalReplacements = 0

# Get all files recursively
$files = Get-ChildItem -Path $Directory -Recurse -File -Filter $FileFilter | Where-Object {
    -not (Should-ExcludeDirectory $_.DirectoryName) -and
    -not (Should-ExcludeFile $_.FullName)
}

Write-ColorOutput "Found $($files.Count) files to process..." "Green"

$all = $false
foreach ($file in $files) {
    $totalFiles++
    
    try {
        # Read file content
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        
        if ($null -eq $content) {
            continue
        }
        
        # Perform replacement
        $newContent = if ($CaseSensitive) {
            $content -creplace [regex]::Escape($SearchPattern), $ReplaceWith
        } else {
            $content -ireplace [regex]::Escape($SearchPattern), $ReplaceWith
        }
        
        # Check if content changed
        if ($content -ne $newContent) {
            # Count replacements in this file
            $replacements = if ($CaseSensitive) {
                ([regex]::Matches($content, [regex]::Escape($SearchPattern))).Count
            } else {
                ([regex]::Matches($content, [regex]::Escape($SearchPattern), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            }
            
            
            $totalReplacements += $replacements
            $modifiedFiles++
            
            Write-ColorOutput "  [$modifiedFiles] $($file.FullName) - $replacements replacement(s)" "Green"
            
            if (-not $WhatIf) {
                if ($all -or $Force) {
                    Set-Content -Path $file.FullName -Value $newContent -NoNewline -ErrorAction Stop
                    Write-ColorOutput "    File updated successfully" "Green"
                } elseif ($readin = (Read-Host "Modify file? (y/N/a)") -match '^[Yy]') {
                     Set-Content -Path $file.FullName -Value $newContent -NoNewline -ErrorAction Stop
                    Write-ColorOutput "    File updated successfully" "Green"
                } elseif ($readin -match '^[Aa]') {
                    $all = $true
                }
                else {
                    Write-ColorOutput "    Skipped by user" "Yellow"
                    $modifiedFiles--
                    $totalReplacements -= $replacements
                }
            }
        }
    }
    catch {
        Write-ColorOutput "  ERROR processing $($file.FullName): $($_.Exception.Message)" "Red"
    }
    
    # Progress indicator
    if ($totalFiles % 100 -eq 0) {
        Write-ColorOutput "Processed $totalFiles files..." "Gray"
    }
}

Write-ColorOutput "`nOperation completed!" "Green"
Write-ColorOutput "Files processed: $totalFiles" "Cyan"
Write-ColorOutput "Files modified: $modifiedFiles" "Cyan"
Write-ColorOutput "Total replacements: $totalReplacements" "Cyan"

if ($WhatIf) {
    Write-ColorOutput "`nRun without -WhatIf to actually modify files" "Magenta"
}