# https://superuser.com/a/1528657/901835

# $registryQuery = cmd /c "reg query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions /f name /v name /s | findstr /c:'Name' | Sort"
# $registryQuery | ForEach-Object {
#     $line = $_
#     Write-Output $line
# }
# Pause

###
$FD = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions'
(Get-ItemProperty (Get-ChildItem $FD).PSPath).Name

###
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | out-null
Get-ChildItem 'HKCR:\CLSID' | Where-Object { $_.GetSubkeyNames() -contains 'ShellFolder' } | Select-Object PSChildName, @{N = 'Default'; E = { (Get-ItemProperty $_.PSPath).'(Default)' } }

###
$Shell = New-Object -ComObject shell.application
$DT = $Shell.Namespace(0)

Function Unfold ($oFolder) {
    $oFolder.Items() | Where-Object { ($_.IsFolder -eq $True) -and ($_.Name -notLike 'Fonts') } | ForEach-Object {
        UnFold $_.GetFolder
    }
    $_.GetFolder.Items() | Select-Object Name, Path
}

$DT.Items() | Where-Object { ($_.IsFolder -eq $True) -and
    ($_.Name -match 'Control Panel') } | ForEach-Object {
    Unfold $_.GetFolder
} | Select-Object name, path -unique | Sort-Object Path | Out-Gridview