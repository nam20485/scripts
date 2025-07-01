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
# MIIb2AYJKoZIhvcNAQcCoIIbyTCCG8UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1UCGZCSc9yKAZzXmDNPeUOuh
# 2xagghZDMIIDOzCCAiOgAwIBAgIQTUN+l1b4Yb5HB7A+VVnVXjANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhNeUNvZGVTaWduaW5nQ2VydGlmaWNhdGUwHhcNMjUw
# NzAxMDEzNTI1WhcNMjYwNzAxMDE1NTI1WjAjMSEwHwYDVQQDDBhNeUNvZGVTaWdu
# aW5nQ2VydGlmaWNhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDs
# Yb6NkTwMtaKg7MW8tuhcoHMfl8Yu1ych216bhvyHkm9I9f8+9pkeWZvBEcsvsm2C
# qSQbU8O8BD8ulC452VXBiarO19JfhTvkN+WiuvsLN58CTPE+0QlJGztRd8YWLj0N
# 9Kn04nYbbj1PtlfWNfJ+pVI9Z9y0+ws3UbQrGdbeEwKRTYmC+eQhAXJp2LNZGKd4
# 5kPN7RQkMUNtcDfCS748Hh7b0TssimqSc2nye1KgQQK8bhNhUlzjTHiQ3vEUArhB
# /+TQDMHH1uhrcJKrc38292ktIhmQPp5cJYB495aqb12iebzI573WMII9h0Jeeexc
# jU8RTtNzhzrCNeGN75L9AgMBAAGjazBpMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAjBgNVHREEHDAaghhNeUNvZGVTaWduaW5nQ2VydGlmaWNh
# dGUwHQYDVR0OBBYEFJXtnO5TItoaoofJuYnOFwRB/yD1MA0GCSqGSIb3DQEBCwUA
# A4IBAQCQNjDizGMRgHXDQNq7ClR+FyKhE84DpHic7SwnJgRMeIoVx0eUL13FM1w0
# s8qLRMcMM9iRt5VCZEG9CGkLnmgreni5gPBVqVBIExdpusMoeuHytHuA6lEcFY4p
# krD1K5TmAhX0B6e8L7SaTX84IDv37hgNjyEhw3WCiMpo1ncI1x2qbLEPLVcPzVFm
# 6UZVA5GO9FwcSYrWHlrvlp89SgiwuFvqncQZbrw/oIFn1EsNhUY1QU6sATYf85/k
# OCFZjkErFSrolitRA0rXMCtu9vDTaWxdjRJcJOwcDVaLfowAQikYAqRwU/CRpKlW
# emX4jteS/Ac+fVm93utDCVPu2JMRMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c
# 9MfjPzANBgkqhkiG9w0BAQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIFJvb3QgUjQ2MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMj
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3
# DQEBAQUAA4IBjwAwggGKAoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yav
# jA6Bg+OiIjPm/N/t3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6W
# zeJDB9qkQVa46xiYEpc81KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9d
# jnjkTdAA83abEOHQ4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw
# 5+4v1nssWeN1y4+RlaOywwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM
# 8ZpHadmVjbi3Pl8hJiTWw9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCul
# Vq8ZpysiSYNi79tw5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtO
# cgw+vHJcJ8HnJCrcUWhdFczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWm
# biAVPbgkqykSkzyYVr15OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3
# at0//QET/xahbIICL9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIy
# mzAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAK
# BggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7
# aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5n
# Um9vdFI0Ni5jcmwwfAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8v
# Y3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2
# LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggIBABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdlto
# X4hDskBMZx5NY5L6SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAX
# yIIaUf5JVKjccev3w16mNIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp
# 8MbOocI9Zn78xvm9XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjE
# nBnxuUB1fm6bPAV+Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf
# 6vATJP4DfPtKzSBPkKlOtyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm
# 6N2s2ZHCHVhlUgHaC4ACMRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjV
# ZFpO4ZIVR33LwXyPDbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbnt
# inmpOqh/QPAnhDgexKG9GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM
# 6noD2XQPrFwpm3GcuqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygct
# o78XCSPfFWveUOSZ5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIG
# YjCCBMqgAwIBAgIRAKQpO24e3denNAiHrXpOtyQwDQYJKoZIhvcNAQEMBQAwVTEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMj
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYwHhcNMjUwMzI3MDAw
# MDAwWhcNMzYwMzIxMjM1OTU5WjByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2Vz
# dCBZb3Jrc2hpcmUxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMn
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBTaWduZXIgUjM2MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA04SV9G6kU3jyPRBLeBIHPNyUgVNnYayf
# sGOyYEXrn3+SkDYTLs1crcw/ol2swE1TzB2aR/5JIjKNf75QBha2Ddj+4NEPKDxH
# Ed4dEn7RTWMcTIfm492TW22I8LfH+A7Ehz0/safc6BbsNBzjHTt7FngNfhfJoYOr
# kugSaT8F0IzUh6VUwoHdYDpiln9dh0n0m545d5A5tJD92iFAIbKHQWGbCQNYplqp
# AFasHBn77OqW37P9BhOASdmjp3IijYiFdcA0WQIe60vzvrk0HG+iVcwVZjz+t5Oc
# XGTcxqOAzk1frDNZ1aw8nFhGEvG0ktJQknnJZE3D40GofV7O8WzgaAnZmoUn4PCp
# vH36vD4XaAF2CjiPsJWiY/j2xLsJuqx3JtuI4akH0MmGzlBUylhXvdNVXcjAuIEc
# EQKtOBR9lU4wXQpISrbOT8ux+96GzBq8TdbhoFcmYaOBZKlwPP7pOp5Mzx/UMhyB
# A93PQhiCdPfIVOCINsUY4U23p4KJ3F1HqP3H6Slw3lHACnLilGETXRg5X/Fp8G8q
# lG5Y+M49ZEGUp2bneRLZoyHTyynHvFISpefhBCV0KdRZHPcuSL5OAGWnBjAlRtHv
# sMBrI3AAA0Tu1oGvPa/4yeeiAyu+9y3SLC98gDVbySnXnkujjhIh+oaatsk/oyf5
# R2vcxHahajMCAwEAAaOCAY4wggGKMB8GA1UdIwQYMBaAFF9Y7UwxeqJhQo1SgLqz
# YZcZojKbMB0GA1UdDgQWBBSIYYyhKjdkgShgoZsx0Iz9LALOTzAOBgNVHQ8BAf8E
# BAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBKBgNV
# HSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3Nl
# Y3RpZ28uY29tL0NQUzAIBgZngQwBBAIwSgYDVR0fBEMwQTA/oD2gO4Y5aHR0cDov
# L2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nQ0FSMzYu
# Y3JsMHoGCCsGAQUFBwEBBG4wbDBFBggrBgEFBQcwAoY5aHR0cDovL2NydC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nQ0FSMzYuY3J0MCMGCCsG
# AQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOC
# AYEAAoE+pIZyUSH5ZakuPVKK4eWbzEsTRJOEjbIu6r7vmzXXLpJx4FyGmcqnFZoa
# 1dzx3JrUCrdG5b//LfAxOGy9Ph9JtrYChJaVHrusDh9NgYwiGDOhyyJ2zRy3+kdq
# hwtUlLCdNjFjakTSE+hkC9F5ty1uxOoQ2ZkfI5WM4WXA3ZHcNHB4V42zi7Jk3ktE
# nkSdViVxM6rduXW0jmmiu71ZpBFZDh7Kdens+PQXPgMqvzodgQJEkxaION5XRCoB
# xAwWwiMm2thPDuZTzWp/gUFzi7izCmEt4pE3Kf0MOt3ccgwn4Kl2FIcQaV55nkjv
# 1gODcHcD9+ZVjYZoyKTVWb4VqMQy/j8Q3aaYd/jOQ66Fhk3NWbg2tYl5jhQCuIsE
# 55Vg4N0DUbEWvXJxtxQQaVR5xzhEI+BjJKzh3TQ026JxHhr2fuJ0mV68AluFr9qs
# hgwS5SpN5FFtaSEnAwqZv3IS+mlG50rK7W3qXbWwi4hmpylUfygtYLEdLQukNEX1
# jiOKMIIGgjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwF
# ADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcT
# C0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAs
# BgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcN
# MjEwMzIyMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYG
# A1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBU
# aW1lIFN0YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAiJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizI
# CFNeINCSJS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ
# 2aHHsPHggGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2G
# AXsePHi+/JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WA
# BKf+Gnoi4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/F
# DDrOJ3rWqauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop0
# 6m7NUNHdlTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE
# 9vtiTMzz/o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj
# 3NgevsAsvxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoq
# zEIbW3q0b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7
# jk27MAe145GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYw
# ggESMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2
# d2rdP/0BE/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUw
# AwEB/zATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYD
# VR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVz
# dFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAl
# BggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0B
# AQwFAAOCAgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39rAARa
# AdAxUeiX1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsD
# LRhsyeIiJsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxV
# f7nkNtUjPfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJ
# yz9gvEOcF1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwDiGin
# CwKPyFO7ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp
# 4pmAWjR+Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/U
# YOy8k60mKcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SB
# IkiRzfPfS9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14su
# VFBmbzrt5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HH
# FHeRPRYrMBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8xggT/MIIE
# +wIBATA3MCMxITAfBgNVBAMMGE15Q29kZVNpZ25pbmdDZXJ0aWZpY2F0ZQIQTUN+
# l1b4Yb5HB7A+VVnVXjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3PKbKHvIxzq/naOIkZRZ3C+p
# gRMwDQYJKoZIhvcNAQEBBQAEggEAtLPVcBXN7eZi+5Zr7OrQMsnERDE/obhdDLi/
# yp3UzV7AZm98wkuJy6teg8wekGTEHrh1L7z6MBYrHjBwWMTO25AcXYlMOpQIu8e1
# 2SWuOI2tg5J5+h3OG0ulXiGMx8f6zmk8SObs+/IlfMo6g7D5cuDerz8YBeR9p1Pv
# rMB3ibbZjkgkBZ9Wh9PUPn15C/ZSK5BYONpJvRUHBCC1IZLdbgVQdhuihflT8e3g
# GDB0uEk86Fk/BBAMqUkZNq+nAN70f8df23Ins4hOygDJWTX/i4Qq5I2C0Ve69NFP
# dLwFTYPZXLqtKhQYxP2CjVAbyDRHvdsK+w6SdFmwHaZh5c100aGCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDcw
# MTAxNDUyOVowPwYJKoZIhvcNAQkEMTIEMGspPa0Vl8w5qLnh/AM6ifjlVLi0TaeQ
# Sw3mPSDdrI3QWcL1yJZhzF6jO6twSzWs2DANBgkqhkiG9w0BAQEFAASCAgBLUrJa
# OgoinLZrvmuYWOHx/+jlUgXqiHdReJV384nx0SqqqEgTLsAqW3hT1hxiIZrGlTH8
# ABcwAROUPVGtipQTqhXGhACv1E2GLRLqe6qIjHi4LVppoivGAM3iFlg49/8F22af
# xO6M74thCakKi9JLDnPnxslGB/qWQ21xjxcB/AFzBw7LgRwHcdw3NZF/1LTiPEur
# HZc/3mZVb16iqATVpHvftl7mvy9KHoh+hcNpSvAxyppkyx6BifYcnGLNA568t+Sr
# WmoIwzRzAhURihTqwM+WZrCVdo7N2TKbca2tn/nF6lw9VJ9bqeD3lpG32u9TIlVM
# JvdP78w78oHWHqky7j34Ic9bf6XJ306mGMi6lUkxfpxevBIZa2JtDYYgpkyNmb02
# YMPAN0Yiu8fHhn7Nwf4F6Z4okCosQYQd4GUPteRMrmPJoaSk6rFulWuGdDlhGSjK
# WpLE6ea78weKrPk00PJj2OOBxhqwsflWnJM7uEP9zXyR7ny3JepXNY5ldjIkgbTm
# 97AlqRuVh7Oc9fdFAVZ/OOjTgpGu0VZU2fZIDaHz5LqmIanRdegdjGhss2D3e3Hx
# d1xiYKAVQ6CohKfdT0rXBX1pB4jm3/zXADaNdrn/OWwNOWuPvZ/bdPRZBuATSDwk
# z9gxKZkDZSxRgtMdHKOnDOCjrEXV14HzNFZJxQ==
# SIG # End signature block
