
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [System.IO.Path]
    $Exclude
)

$exclusions = @( `
        $Exclude); `
    $existingExclusions = [Collections.Generic.HashSet[String]](Get-MpPreference).ExclusionProcess; `
    if ($existingExclusions -eq $null) { $existingExclusions = New-Object Collections.Generic.HashSet[String] }; `
    $exclusionsToAdd = [Linq.Enumerable]::ToArray([Linq.Enumerable]::Where($exclusions, [Func[object, bool]] { param($ex)!$existingExclusions.Contains($ex) })); `
    if ($exclusionsToAdd.Length -gt 0) { Add-MpPreference -ExclusionProcess $exclusionsToAdd }