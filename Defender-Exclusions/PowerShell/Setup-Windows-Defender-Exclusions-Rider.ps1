[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $RiderHome="C:\Program Files\JetBrains\JetBrains Rider 231.8109.136"
)

function Update-WindowsDefenderForRider {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $RiderHome
    )

    $directories = @()
    $directories += Get-ChildItem -Directory -Recurse $RiderHome\bin
    $directories += "$($RiderHome)\bin"
    $directories += Get-ChildItem -Directory -Recurse $RiderHome\lib\ReSharperHost
    $directories += "$($RiderHome)\lib\ReSharperHost"
    $directories += Get-ChildItem -Directory -Recurse $RiderHome\tools

    $directories | ForEach-Object {
        Write-Output "$_"
        #Add-MpPreference -ExclusionProcess "$($_)\*.dll"
        #Add-MpPreference -ExclusionProcess "$($_)\*.dll"
        #Add-MpPreference -ExclusionProcess "$($_)\*.exe"
    }
}

Update-WindowsDefenderForRider -RiderHome $RiderHome

#C:\Program Files\JetBrains\JetBrains Rider 231.8109.136\bin