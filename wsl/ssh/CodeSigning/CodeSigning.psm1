#requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates a new self-signed code signing certificate.
.DESCRIPTION
    This function creates a new self-signed code signing certificate in the local machine's
    personal store. It also adds the certificate to the Root and Trusted Publishers stores
    to make it trusted on the local machine for script execution.
    This function requires administrative privileges.
.PARAMETER DnsName
    The DNS name for the certificate subject. This is a mandatory parameter.
.PARAMETER FriendlyName
    An optional friendly name for the certificate. If not provided, the DnsName is used.
.PARAMETER Force
    If specified, removes any existing certificates with the same DnsName before creating the new one.
.EXAMPLE
    New-SelfSignedCodeSigningCertificate -DnsName "MyDevCert"
    This command creates a new code signing certificate with the subject and friendly name "MyDevCert".
.EXAMPLE
    New-SelfSignedCodeSigningCertificate -DnsName "MyDevCert" -Force
    This command removes any existing certificates named "MyDevCert" and then creates a new one.
.OUTPUTS
    System.Security.Cryptography.X509Certificates.X509Certificate2
    Returns the created certificate object on success.
 .NOTES
    Author: Gemini Code Assist
    This function will fail if not run in an elevated PowerShell session.
#>
function New-SelfSignedCodeSigningCertificate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DnsName,

        [string]$FriendlyName = $DnsName,

        [switch]$Force
    )

    # New-SelfSignedCertificate creates a subject of "CN=<DnsName>"
    $subjectName = "CN=$DnsName"
    $existingCerts = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $subjectName }

    if ($existingCerts) {
        if ($Force) {
            if ($PSCmdlet.ShouldProcess("certificates with subject '$subjectName'", "Remove existing")) {
                Write-Verbose "Removing existing certificate(s) with subject '$subjectName' from all stores due to -Force parameter."
                foreach ($existingCert in $existingCerts) {
                    $thumbprint = $existingCert.Thumbprint
                    # Use -ErrorAction SilentlyContinue because the cert might not be in all stores
                    Get-ChildItem "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
                    Get-ChildItem "Cert:\LocalMachine\Root\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
                    Get-ChildItem "Cert:\LocalMachine\TrustedPublisher\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
                }
            }
        } else {
            Write-Host "A certificate with subject '$subjectName' already exists." -ForegroundColor Yellow
            $response = Read-Host "Do you want to use the existing certificate? [Y]es / [N]o (To overwrite, re-run with -Force)"

            if ($response -match '^y') {
                Write-Verbose "User chose to use the existing certificate."
                return $existingCerts[0]
            } else {
                Write-Warning "Operation aborted."
                return
            }
        }
    }

    $cert = $null
    try {
        if ($PSCmdlet.ShouldProcess("certificate with subject '$subjectName'", "Create and trust new")) {
            # Generate a self-signed Authenticode certificate in the local computer's personal certificate store.
            $cert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:\LocalMachine\My -Type CodeSigningCert -FriendlyName $FriendlyName -ErrorAction Stop
            Write-Verbose "Self-signed Authenticode certificate created in Cert:\LocalMachine\My."

            # Add the self-signed Authenticode certificate to the computer's root certificate store to make it trusted.
            $rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("Root", "LocalMachine")
            $rootStore.Open("ReadWrite")
            $rootStore.Add($cert)
            $rootStore.Close()
            Write-Verbose "Self-signed Authenticode certificate added to Root store."

            # Add the self-signed Authenticode certificate to the computer's trusted publishers certificate store.
            $publisherStore = [System.Security.Cryptography.X509Certificates.X509Store]::new("TrustedPublisher", "LocalMachine")
            $publisherStore.Open("ReadWrite")
            $publisherStore.Add($cert)
            $publisherStore.Close()
            Write-Verbose "Self-signed Authenticode certificate added to Trusted Publishers store."
        }
    }
    catch {
        Write-Error "Failed to create or trust the certificate. Cleaning up. Error: $_"
        # If the cert was created, $cert will not be null. Attempt a full cleanup.
        if ($cert) {
            $thumbprint = $cert.Thumbprint
            Write-Verbose "Attempting cleanup of certificate with thumbprint $thumbprint."
            Get-ChildItem "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
            Get-ChildItem "Cert:\LocalMachine\Root\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
            Get-ChildItem "Cert:\LocalMachine\TrustedPublisher\$thumbprint" -ErrorAction SilentlyContinue | Remove-Item -DeleteKey -Force
        }
        return
    }

    Write-Verbose "Successfully created and trusted self-signed code signing certificate '$DnsName'."

    # Only return the cert if it was actually created (i.e., not in a -WhatIf run)
    if ($cert) {
        return $cert
    }
}

<#
.SYNOPSIS
    Applies an Authenticode signature to one or more files.
.DESCRIPTION
    This function signs specified PowerShell scripts or module files using a provided
    certificate. It supports wildcards in paths and can process multiple files.
.PARAMETER Path
    The path to the file(s) to sign. Wildcards are permitted. This parameter is mandatory.
.PARAMETER Certificate
    The certificate to use for signing. This must be a valid X509Certificate2 object
    with code signing capabilities. This parameter is mandatory.
.PARAMETER TimestampServer
    The URL of the timestamp server to use. Defaults to 'http://timestamp.sectigo.com'.
.EXAMPLE
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
    Invoke-CodeSigning -Path "C:\Scripts\MyScript.ps1" -Certificate $cert
    This command signs a single script using the first available code signing certificate.
.EXAMPLE
    $cert = New-SelfSignedCodeSigningCertificate -DnsName "MyProjectCert"
    Get-ChildItem "C:\MyModule\*.ps*" | Invoke-CodeSigning -Certificate $cert
    This command creates a new certificate and then signs all .ps1, .psm1, and .psd1 files
    in the C:\MyModule directory.
.OUTPUTS
    System.Management.Automation.Signature
    Returns the signature object for each successfully signed file.
.NOTES
    Author: Gemini Code Assist
#>
function Invoke-CodeSigning {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Path,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [string]$TimestampServer = "http://timestamp.sectigo.com"
    )

    process {
        # Resolve path to handle wildcards and ensure files exist
        $resolvedPaths = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

        foreach ($file in $resolvedPaths) {
            if ($PSCmdlet.ShouldProcess($file.Path, "Apply Authenticode Signature")) {
                Set-AuthenticodeSignature -FilePath $file.Path -Certificate $Certificate -TimestampServer $TimestampServer -Force
                Get-AuthenticodeSignature -FilePath $file.Path
            }
        }
    }
}
# SIG # Begin signature block
# MIIFrQYJKoZIhvcNAQcCoIIFnjCCBZoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpjNmDk0qt6QrWTG1fJju4W2R
# KomgggM/MIIDOzCCAiOgAwIBAgIQUX124VbHSJJMbDI6xReFHTANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhNeUNvZGVTaWduaW5nQ2VydGlmaWNhdGUwHhcNMjUw
# NzAxMDMxMTA5WhcNMjYwNzAxMDMzMTA5WjAjMSEwHwYDVQQDDBhNeUNvZGVTaWdu
# aW5nQ2VydGlmaWNhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDB
# IM/O7NRbOmee8/oKU+3gAQxGTXKoW7NV4qeZf+mcd0IOI/c82/QBsl/qvzzGnBO6
# zs0L1TU9HZCx3Hd5Ddb37HJTGHKJSxnaHqoxTuB24fIXsyMhDPjyudtywDZ9VXDk
# xZwbxTdEjW7/B6dEjk0V0jHbURd58UDS/gmDJoAhQBSAl01MZg10nr3xWoVCFdGb
# 8I71baOGgJ9STxaUSHsSOH2gbgFPB6mev0UitimDGv/ur0TmNLypIYF3ynSVOjyh
# +eABWD9MHl2DmpBAMq28R/IRnVdeWq78npoE2w7K0onUKJgIiAFrTqlGmAUEF0tS
# l6fUTj40KlexzZeeF9VtAgMBAAGjazBpMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAjBgNVHREEHDAaghhNeUNvZGVTaWduaW5nQ2VydGlmaWNh
# dGUwHQYDVR0OBBYEFOVPTHwUE4Y25yoPxjAGGCRecWElMA0GCSqGSIb3DQEBCwUA
# A4IBAQCqEyQ9tSFOZ+qUMuz4P9q1u/vC8yLoDp6Qadw4cOE531tgXKJAL1D0ccu7
# AB2qUH6wsVGqgeOZbd4TccDlruw0f4I6A66y17PwgllYmX0vseYCPs4j4IlX9sWa
# l66CzfQ9JI4KfKiQkSudt/g+EvfyzxVIxPN+vLP+GsOmCwf5evkVz+eU2Es3xtcI
# onxfPTHEsgl0yVuPlu6MQ1EdG5fzvHJj3X07BwAbj+S8UQ7rlZ40Szbx4X6OBaJl
# pRa2+B/iKzpcB7LoU3aQWbpiUKUERQ8cKhCpeKZTi69+H3Eyy8HY7SNgGz9mMd1K
# VzWoIH1aH0mEQdWSd3xQE4Rw4cUuMYIB2DCCAdQCAQEwNzAjMSEwHwYDVQQDDBhN
# eUNvZGVTaWduaW5nQ2VydGlmaWNhdGUCEFF9duFWx0iSTGwyOsUXhR0wCQYFKw4D
# AhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZI
# hvcNAQkEMRYEFKXKrU+e7lM5OobJcbcbUmVH5Z3kMA0GCSqGSIb3DQEBAQUABIIB
# AGKcxIrCUfl/qBggjkOOdXtzekuqW75BxUaFoYp7qPvhbRey7cuNTeJ70fWrbWyJ
# 3/Lu7hdwe18MnKf/AmYtZkNHxR3oUg95BppZiz1fNPvIbaDkDOciBBXLLiBJDeG2
# IBKdTvDzFcNxXz6S645v0MKEj0tfL8UIKmDPWGPaJnQBd7nfRHaXz0CyvaL2cNUa
# srSyNSYBnYh+w7vIR0cJ7YgtKgyiO8KePzBkL14WbMB07LSQhpXWn6u0Zh6KUYc5
# 0+XRL3uI0oS/izwuRDalMBr3GUIpShkecZxb0NsmQFj3n+ueqh/ctZpMtXRbNHoa
# pbz2+TpvRNoJOiCe0tc6uok=
# SIG # End signature block
