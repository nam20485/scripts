#New-SelfSignedCertificate -DnsName "MyCodeSigningCertificate" -CertStoreLocation Cert:\CurrentUser\Root\ -Type Codesigning
#Set-AuthenticodeSignature -FilePath D:\script.ps1 -Certificate (Get-ChildItem -Path Cert:\CurrentUser\Root\ -CodeSigningCert)

# Generate a self-signed Authenticode certificate in the local computer's personal certificate store.
#$authenticode = New-SelfSignedCertificate -Subject "ATA Authenticode" -CertStoreLocation Cert:\LocalMachine\My -Type CodeSigningCert

$authenticode = New-SelfSignedCertificate -DnsName "MyCodeSigningCertificate" -CertStoreLocation Cert:\LocalMachine\My -Type CodeSigningCert 
Write-Host "Self-signed Authenticode certificate created."

# Add the self-signed Authenticode certificate to the computer's root certificate store.
## Create an object to represent the LocalMachine\Root certificate store.
$rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root","LocalMachine")
## Open the root certificate store for reading and writing.
 $rootStore.Open("ReadWrite")
## Add the certificate stored in the $authenticode variable.
 $rootStore.Add($authenticode)
## Close the root certificate store.
 $rootStore.Close()
 Write-Host "Self-signed Authenticode certificate added to Root store."
 
# Add the self-signed Authenticode certificate to the computer's trusted publishers certificate store.
## Create an object to represent the LocalMachine\TrustedPublisher certificate store.
 $publisherStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("TrustedPublisher","LocalMachine")
## Open the TrustedPublisher certificate store for reading and writing.
 $publisherStore.Open("ReadWrite")
## Add the certificate stored in the $authenticode variable.
 $publisherStore.Add($authenticode)
## Close the TrustedPublisher certificate store.
$publisherStore.Close()

Write-Host "Self-signed Authenticode certificate added to Trusted Publishers."

Set-AuthenticodeSignature -FilePath ./init-networking.ps1 -Certificate $authenticode -TimestampServer "http://tsa.starfieldtech.com"