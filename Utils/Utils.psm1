Function Start-As-Admin {
    # Check if the script is running with elevated privileges
    $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isElevated) {
        # Relaunch the script with elevated privileges
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
        exit
    }
} 

Function Test-Service-Is-Running {
    param (
        [string]$ServiceName,
        [bool]$Start
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Host "${ServiceName} service not found. "
        return $false
    } elseif ($Start -and $service.Status -ne 'Running') {
        Write-Host "Starting $ServiceName service..."
        Start-Service -Name service
        return $service.Status -ne 'Running'
    } else {
        return $false
    }
}

