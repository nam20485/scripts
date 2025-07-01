# Requires Pester v5+
# This test script must be run in an elevated (Administrator) PowerShell session.

# Get the path to the module to be tested
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'CodeSigning.psd1'

# Check for Administrator privileges before running tests
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Warning "Pester tests for CodeSigning module must be run as an Administrator. Skipping tests."
    return
}

BeforeAll {
    # Import the module we are testing
    Import-Module -Name $modulePath -Force

    # Create a temporary directory for test files
    $script:testDir = Join-Path -Path $PSScriptRoot -ChildPath 'TestTemp'
    New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
    # Create dummy files to sign
    Set-Content -Path (Join-Path $script:testDir 'test1.ps1') -Value '# Test File 1'
    Set-Content -Path (Join-Path $script:testDir 'test2.ps1') -Value '# Test File 2'
    Set-Content -Path (Join-Path $script:testDir 'test.txt') -Value '# Not a script'
}

Describe 'New-SelfSignedCodeSigningCertificate' {
    # Use a unique name for test certificates to avoid conflicts
    $testCertDnsName = 'Pester-Test-Cert'
    $testCertSubject = "CN=$testCertDnsName"

    # This block runs after each test to ensure cleanup
    AfterEach {
        # Clean up any certificates created during the test run
        $stores = @('My', 'Root', 'TrustedPublisher')
        foreach ($store in $stores) {
            Get-ChildItem "Cert:\LocalMachine\$store" | Where-Object { $_.Subject -eq $testCertSubject } | Remove-Item -DeleteKey -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Basic Creation' {
        It 'should create a new certificate in the My, Root, and TrustedPublisher stores' {
            # Execute the function
            $cert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName

            # Assertions
            $cert | Should -Not -BeNull
            $cert.Subject | Should -Be $testCertSubject

            # Verify the certificate exists in all three required stores
            Get-ChildItem "Cert:\LocalMachine\My\$($cert.Thumbprint)" -ErrorAction SilentlyContinue | Should -Not -BeNull
            Get-ChildItem "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -ErrorAction SilentlyContinue | Should -Not -BeNull
            Get-ChildItem "Cert:\LocalMachine\TrustedPublisher\$($cert.Thumbprint)" -ErrorAction SilentlyContinue | Should -Not -BeNull
        }

        It 'should return a valid certificate object' {
            $cert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName
            $cert | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Certificate2])
        }
    }

    Context 'When a certificate already exists' {
        It 'should overwrite an existing certificate if -Force is used' {
            # Create an initial certificate
            $firstCert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName
            $firstThumbprint = $firstCert.Thumbprint

            # Re-run with -Force
            $secondCert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName -Force
            $secondThumbprint = $secondCert.Thumbprint

            # The new thumbprint should be different from the old one, and the old one should be gone
            $secondThumbprint | Should -Not -Be $firstThumbprint
            Get-ChildItem "Cert:\LocalMachine\My\$firstThumbprint" -ErrorAction SilentlyContinue | Should -BeNull
        }

        It 'should prompt and use the existing certificate if user enters Y' {
            $existingCert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName
            Mock Read-Host { return 'y' }

            $resultCert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName

            $resultCert.Thumbprint | Should -Be $existingCert.Thumbprint
            Assert-MockCalled Read-Host -Times 1
        }

        It 'should prompt and abort if user enters N' {
            New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName | Out-Null
            Mock Read-Host { return 'n' }

            $resultCert = New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName

            $resultCert | Should -BeNull
            Assert-MockCalled Read-Host -Times 1
        }
    }

    Context 'With -WhatIf parameter' {
        It 'should not create any certificates when -WhatIf is used' {
            New-SelfSignedCodeSigningCertificate -DnsName $testCertDnsName -WhatIf | Should -BeNull
            Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $testCertSubject } | Should -BeNull
        }
    }
}

Describe 'Invoke-CodeSigning' {
    $testCert = $null
    BeforeAll {
        # Create a single certificate to use for all signing tests
        $testCert = New-SelfSignedCodeSigningCertificate -DnsName 'Pester-Signing-Test-Cert' -Force
    }

    AfterAll {
        # Clean up the certificate created for this describe block
        if ($testCert) {
            $subjectName = "CN=Pester-Signing-Test-Cert"
            $stores = @('My', 'Root', 'TrustedPublisher')
            foreach ($store in $stores) {
                Get-ChildItem "Cert:\LocalMachine\$store" | Where-Object { $_.Subject -eq $subjectName } | Remove-Item -DeleteKey -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'should sign a single file' {
        $testFile = Join-Path $script:testDir 'test1.ps1'
        Invoke-CodeSigning -Path $testFile -Certificate $testCert
        $signature = Get-AuthenticodeSignature -FilePath $testFile
        $signature.Status | Should -Be 'Valid'
        $signature.SignerCertificate.Thumbprint | Should -Be $testCert.Thumbprint
    }

    It 'should sign multiple files using wildcards' {
        $testFiles = Join-Path $script:testDir '*.ps1'
        Invoke-CodeSigning -Path $testFiles -Certificate $testCert

        $signature1 = Get-AuthenticodeSignature -FilePath (Join-Path $script:testDir 'test1.ps1')
        $signature1.Status | Should -Be 'Valid'

        $signature2 = Get-AuthenticodeSignature -FilePath (Join-Path $script:testDir 'test2.ps1')
        $signature2.Status | Should -Be 'Valid'
    }

    It 'should not perform signing when -WhatIf is used' {
        $whatIfTestFile = Join-Path $script:testDir 'whatif_test.ps1'
        Set-Content -Path $whatIfTestFile -Value '# WhatIf Test'
        Invoke-CodeSigning -Path $whatIfTestFile -Certificate $testCert -WhatIf | Should -BeNullOrEmpty
        $signature = Get-AuthenticodeSignature -FilePath $whatIfTestFile
        $signature.Status | Should -Be 'NotSigned'
    }
}

AfterAll {
    # Clean up the temp directory and files
    if (Test-Path $script:testDir) {
        Remove-Item -Path $script:testDir -Recurse -Force
    }
}
# SIG # Begin signature block
# MIIb2AYJKoZIhvcNAQcCoIIbyTCCG8UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3YyRfRTESUHDbcY2WZ4TuT9c
# n0qgghZDMIIDOzCCAiOgAwIBAgIQTUN+l1b4Yb5HB7A+VVnVXjANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUI6UvKCa3J1MK4xOB33SJNFgZ
# 7okwDQYJKoZIhvcNAQEBBQAEggEA0J2lgdPxImXKhmTtE9pTxZ4YOnjTM/Q7Mbqu
# tgeOrUGatnsMYZ0ShSyG7k4ObQ6p2h8zhQvpdWKN1ABO9OwRxXb9k4BS31GzVtg3
# JB06Bv4B+brz58aUlghLzIfxBeEegTBXklywNpV5X66PrgbPh2h7iUNL15EAexe5
# uGK0QEXUtGKQ/Mx6nkvagAvMheNo26Rd3ZMCjs5/ixFDoLFDhCZZXH6JSVuOEqcK
# Wq3lApULJ1TJNy8+AVajX1pcOyT4txIBVv63JeK4SJFXDNxIFoZPDiCkUkKDhRrf
# rgs8x8iGtVe3bWeF2YeQqt4RWkN/K0Sa3JJx3ckZAP0Jgs3RX6GCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDcw
# MTAxNDUzMlowPwYJKoZIhvcNAQkEMTIEMOWSrd/l31M0qsgcdhPax6s/rPeSdtC7
# wj9miIhz7Karru0El9RVkqvcFyfWs1G0GzANBgkqhkiG9w0BAQEFAASCAgBXEz/c
# 0BOgV80axzTU4mPTQQzuKWnxf8CegjKr7FMR2cv8aJVrDi9QUvx9Jown+1spuSZp
# +ua+MZ37A8DqPUEV99zeVPdgu27d8AbXFI2UVT7vAes6JQw/s7PPxky8j2dHZ6sO
# cu/E7xgVOQxXSWMj5A5ZXVFbNAfjt5k8JvjwGHOW+XEjWBy6aPDP2tpX3GgKtoW6
# Ut3YhrsyK1u36WIR9uJJDrzcoki6meoATnTvfGfR2LmVk8vwfT4JS3+XslNV3TSH
# R9+uzHgtHYgH3qKiGrEX1vv1HA2aqdqSpgLoqT5WpvXkaH0jj8r/8qAvfY9m/xsS
# ujAG6sgcoeSgBLKuBEgDs1fog5Pdr9OaXT+oxW8QaaWY1M57wMeRBtNY08Z4YkD4
# CPr7Q8qg4iiCZh2a8hG2QL3TOnwFHNf6hupMusENYSbbUN1Tgk4TRZFYHQ6KBQnz
# YvGfCiuyZuQtaRXVs18SuWCotSJmGxUv0KOBkF5UulrPTw1zA6n6RIqgjiwgQ0yb
# jSM4vh0vLUU4o2Xdk9F1Q9KklC6NZp/DeX9nCPAv1BGbfKQ+FJwWUiX6x80uo0wZ
# R4ueqAp08GWIqLo3DPcaspy6SzuNsIbt/3fQRjYdYI43kYXR2O+ZRS3416j4tM+b
# wTT7QvhMO9ZSpvSC5uR2+GirNLBUl+hsPS2rvg==
# SIG # End signature block
