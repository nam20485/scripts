# This script creates a self-signed code signing certificate and uses it to sign the CodeSigning module.
# This needs to be run as Administrator.

#requires -RunAsAdministrator

# 1. Import the module and create the certificate using its function
$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "CodeSigning\CodeSigning.psd1"
Import-Module -Name $moduleManifestPath -Force

$certDnsName = "MyCodeSigningCertificate"
Write-Host "Creating/updating self-signed certificate '$certDnsName' using the CodeSigning module..."

# Use the module's function to create the certificate.
# The -Force switch ensures any old cert with the same name is removed first, making the script re-runnable.
$cert = New-SelfSignedCodeSigningCertificate -DnsName $certDnsName -Force

if (-not $cert) {
    Write-Error "Failed to create the self-signed certificate using the module. Aborting."
    return
}

Write-Host "Certificate created successfully."
Write-Host "Thumbprint: $($cert.Thumbprint)"

# 2. Sign the module files
$filesToSign = Join-Path -Path $PSScriptRoot -ChildPath "CodeSigning\*.ps*"

Write-Host "Signing module files..."
$signatures = Invoke-CodeSigning -Path $filesToSign -Certificate $cert
if ($signatures) {
    Write-Host "Successfully signed the following files:"
    $signatures | Format-Table -AutoSize
}

Write-Host "Module signing process complete."