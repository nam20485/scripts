# parameter block
param(
    [Parameter(Mandatory = $true)]
    [string]$scriptPath
)

# https://learn.microsoft.com/en-us/powershell/azure/quickstart-migrate-azurerm-to-az-automatically?view=azps-13.5.0#requirements
Update-Module -Name AzureRM

Install-Module -Name Az.Tools.Migration

# Generate an upgrade plan for all the scripts and module files in the specified folder and save it to a variable.
New-AzUpgradeModulePlan -FromAzureRmVersion 6.13.1 -ToAzVersion latest -DirectoryPath $scriptPath -OutVariable Plan

$azureRmExists = Get-Module -Name AzureRM -ListAvailable

$manualSteps = @()

# Filter plan results to only warnings and errors
$manualSteps = $Plan | Where-Object PlanResult -ne ReadyToUpgrade | Format-List

# Execute the automatic upgrade plan and save the results to a variable.
Invoke-AzUpgradeModulePlan -Plan $Plan -FileEditMode SaveChangesToNewFiles -OutVariable Results

# Filter results to show only errors
$Results | Where-Object UpgradeResult -ne UpgradeCompleted | Format-List

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Install-Module -Name Az -Repository PSGallery -Force

Update-Module -Name Az -Force

Connect-AzAccount



