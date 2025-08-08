# $moduleFiles = Get-ChildItem -Include @('*.psm1', '*.psd1') -Recurse -Path `
# ('C:\Users\nmill\AppData\Local\Temp\is-7EGP0.tmp' `
#         + '\{app}\PowerShellModules')
# $tempPath = [System.IO.Path]::GetTempFileName()
# foreach ($moduleFile in $moduleFiles) {
#     $signature = Get-AuthenticodeSignature -FilePath $moduleFile.FullName
#     if ($signature.Status -ne 'Valid') { continue }
#     $signer = $signature.SignerCertificate
#     $chain = New-Object -TypeName `
#         'System.Security.Cryptography.X509Certificates.X509Chain'
#     $chain.Build($signer)
#     $signerCA = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate
#     $signerCA | Export-Certificate -FilePath $tempPath -Type CERT
#     Import-Certificate -FilePath $tempPath -CertStoreLocation `
#         'Cert:\LocalMachine\Root'
#     $signer | Export-Certificate -FilePath $tempPath -Type CERT
#     Import-Certificate -FilePath $tempPath -CertStoreLocation `
#         'Cert:\LocalMachine\TrustedPublisher'
# }
# Remove-Item -Path $tempPath -Force