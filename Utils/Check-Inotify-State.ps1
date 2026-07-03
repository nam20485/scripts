#!/usr/bin/env pwsh

param(
    [switch]$Kill,
    [switch]$State
)

# Default to -State if neither switch is provided
if (-not $Kill -and -not $State) {
    $State = $true
}

# Process patterns to search for
$processPatterns = @(
    "gemini-cli-extensions",
    "mcp-server-memory",
    "chrome-devtools-mcp",
    "toolbox-sdk",
    "data-agent-kit",
    "notebook-tools"
)

function Get-InotifyState {
    Write-Host "=== INOTIFY STATE ===" -ForegroundColor Cyan
    Write-Host ""

    # Read kernel limits
    $maxInstancesPath = "/proc/sys/fs/inotify/maxuserinstances"
    $maxWatchesPath   = "/proc/sys/fs/inotify/maxuserwatches"
    $nrInstancesPath  = "/proc/sys/fs/inotify/nr_instances"

    $maxInstances = if (Test-Path $maxInstancesPath) { [int](Get-Content $maxInstancesPath -Raw) } else { $null }
    $maxWatches   = if (Test-Path $maxWatchesPath)   { [int](Get-Content $maxWatchesPath -Raw) }   else { $null }
    $nrInstances  = if (Test-Path $nrInstancesPath)  { [int](Get-Content $nrInstancesPath -Raw) }  else { $null }

    Write-Host "Kernel Limits:" -ForegroundColor Yellow
    Write-Host "  maxuserinstances : $($maxInstances ?? 'unknown')"
    Write-Host "  maxuserwatches   : $($maxWatches ?? 'unknown')"
    Write-Host ""

    # Try kde-inotify-survey first (gives accurate per-process breakdown)
    $surveyOutput = $null
    try {
        $surveyOutput = kde-inotify-survey 2>$null | Out-String
    } catch {
        $surveyOutput = $null
    }

    if ($surveyOutput) {
        try {
            $survey = $surveyOutput | ConvertFrom-Json
            $totals = $survey.totals
            Write-Host "Current Usage (from kde-inotify-survey):" -ForegroundColor Yellow
            Write-Host "  Instances : $($totals.instances) / $($totals.maxInstances) ($($totals.instancePercent)%)"
            Write-Host "  Watches   : $($totals.watches) / $($totals.maxWatches) ($($totals.watchPercent)%)"
            Write-Host ""

            # Color-code severity
            $instanceColor = if ($totals.instancePercent -gt 100) { "Red" }
                             elseif ($totals.instancePercent -gt 75) { "Yellow" }
                             else { "Green" }
            $watchColor    = if ($totals.watchPercent -gt 100) { "Red" }
                             elseif ($totals.watchPercent -gt 75) { "Yellow" }
                             else { "Green" }

            Write-Host "Status:" -ForegroundColor Yellow
            Write-Host "  Instances : " -NoNewline
            Write-Host "$($totals.instancePercent)% of limit" -ForegroundColor $instanceColor
            Write-Host "  Watches   : " -NoNewline
            Write-Host "$($totals.watchPercent)% of limit" -ForegroundColor $watchColor
            Write-Host ""

            # Top 5 offenders
            Write-Host "Top 5 Inotify Consumers:" -ForegroundColor Yellow
            $survey.processes |
                Sort-Object { $_.instances } -Descending |
                Select-Object -First 5 |
                ForEach-Object {
                    $name = ($_.cmdline -split '\u0000')[0] | Split-Path -Leaf
                    Write-Host "  $($_.instances.ToString().PadLeft(4)) instances | $($_.watches.ToString().PadLeft(7)) watches | $name"
                }
            Write-Host ""
        } catch {
            Write-Host "  (Failed to parse kde-inotify-survey output)" -ForegroundColor DarkYellow
        }
    } else {
        # Fallback: manual count via /proc
        Write-Host "Current Usage (fallback):" -ForegroundColor Yellow
        Write-Host "  nr_instances (kernel-reported) : $($nrInstances ?? 'unknown')"
        Write-Host ""

        if ($maxInstances -and $nrInstances) {
            $pct = [math]::Round(($nrInstances / $maxInstances) * 100, 1)
            $color = if ($pct -gt 100) { "Red" } elseif ($pct -gt 75) { "Yellow" } else { "Green" }
            Write-Host "  Instance usage : $pct% of limit" -ForegroundColor $color
        }
        Write-Host ""
    }
}

function Get-TargetProcesses {
    $results = @()
    foreach ($pattern in $processPatterns) {
        $procs = Get-Process | Where-Object { $_.ProcessName -like "$pattern" }
        foreach ($p in $procs) {
            $results += [PSCustomObject]@{
                Pattern = $pattern
                Name    = $p.ProcessName
                Id      = $p.Id
                Process = $p
            }
        }
    }
    return $results
}

function Invoke-KillFlow {
    Write-Host "Searching for matching processes..." -ForegroundColor Cyan
    Write-Host ""

    $targets = Get-TargetProcesses
    $killedCount = 0

    if ($targets.Count -eq 0) {
        Write-Host "  No matching processes found." -ForegroundColor Green
    } else {
        foreach ($t in $targets) {
            Write-Host "$($t.Name) (PID: $($t.Id)) [matched: $($t.Pattern)] is running, killing..." -ForegroundColor Yellow
            try {
                Stop-Process -Id $t.Id -Force
                Write-Host "  ✓ Successfully killed $($t.Name)" -ForegroundColor Green
                $killedCount++
            } catch {
                Write-Host "  ✗ Failed to kill $($t.Name): $_" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "Summary: Killed $killedCount process(es)" -ForegroundColor Cyan
}

# --- Main ---
if ($State) {
    Get-InotifyState
}

if ($Kill) {
    if ($State) { Write-Host ""; Write-Host "--- KILL PHASE ---" -ForegroundColor Cyan; Write-Host "" }
    Invoke-KillFlow
    if ($State) {
        Write-Host ""
        Write-Host "--- POST-KILL STATE ---" -ForegroundColor Cyan
        Write-Host ""
        Get-InotifyState
    }
}

# Usage
#
# Show current state only (default if no args)
# pwsh ./Check-Inotify-State.ps1
# pwsh ./Check-Inotify-State.ps1 -State
#
# Kill matching processes only
# pwsh ./Check-Inotify-State.ps1 -Kill
#
# Kill then show post-kill state (most useful)
# pwsh ./Check-Inotify-State.ps1 -Kill -State
#
# What's new
#
# -State reads /proc/sys/fs/inotify/maxuserinstances, maxuserwatches, and nr_instances, then parses kde-inotify-survey JSON for a full breakdown including the top 5 offenders and color-coded severity (green/yellow/red).
# -Kill runs the original kill flow.
# -Kill -State shows state → kills → shows state again, so you can instantly see if the remediation worked.
# No args defaults to -State (safe — never kills anything accidentally).
# Added notebook-tools to the kill list since we confirmed it's the biggest offender.
