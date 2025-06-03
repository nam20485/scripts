Function GenerateStrongPassword ([Parameter(Mandatory=$true)][int]$PasswordLength)
{
    Add-Type -AssemblyName System.Web
    $PassComplexCheck = $false
    do {
        $newPassword = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, 1)
        If ( ($newPassword -cmatch "[A-Z\p{Lu}\s]") `
        -and ($newPassword -cmatch "[a-z\p{Ll}\s]") `
        -and ($newPassword -match "[\d]") `
        -and ($newPassword -match "[^\w]")
        )
        {
        $PassComplexCheck=$True
        }
    } While ($PassComplexCheck -eq $false)
    return $newPassword
}

# get password length from user
$PassLen = Read-Host "Enter the password length"

$newPass = GenerateStrongPassword -PasswordLength $PassLen

Write-Host "New Password: "$newPass" -ForegroundColor Green"12
# copy new password to users' clipboard
Set-Clipboard -Value $newPass
Write-Host "New Password has been copied to your clipboard." -ForegroundColor Green