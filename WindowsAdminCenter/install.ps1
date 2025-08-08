
function Start-As-Admin {
    # Check if the script is running with elevated privileges
    $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isElevated) {
        # Relaunch the script with elevated privileges
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
        exit
    }
}

# create function to test if service is running
function Test-Service-Is-Running {
    param (
        [string]$ServiceName,
        [bool]$Start
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Host "${ServiceName} service not found."
        return $false
    }
    elseif ($Start -and $service.Status -ne 'Running') {
        Write-Host "Starting $ServiceName service..."
        Start-Service -Name $ServiceName
        return $service.Status -ne 'Running'
    }
    else {
        return $false
    }
}

$serviceName = 'WindowsAdminCenter'

if (-not (Test-Service-Is-Running -ServiceName $serviceName -Start $true)) {
    Write-Host "$serviceName service is not running."

    Start-As-Admin

    $path = '.\WindowsAdminCenter.exe'    

    # if not downloaded
    if (-not (Test-Path $path)) {
        Write-Host 'Downloading Windows Admin Center...'
        $parameters = @{
            Source      = 'https://aka.ms/WACdownload'
            Destination = $path
        }
        Start-BitsTransfer @parameters
    }
    else {
        Write-Host 'Windows Admin Center already downloaded.'
    }

    Write-Host 'Installing Windows Admin Center...'
    Start-Process -FilePath $path -ArgumentList '/VERYSILENT' -Wait

    Write-Host 'Windows Admin Center installed successfully.'

    if (-not (Test-Service-Is-Running -ServiceName $serviceName -Start $true)) {
        Write-Host "$serviceName service is not running. Starting service..."
        Start-Service -Name $serviceName -ErrorAction Stop
    }
}
else {
    Write-Host "$serviceName service is already running."
}
