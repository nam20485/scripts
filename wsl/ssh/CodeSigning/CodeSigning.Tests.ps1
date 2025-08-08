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
# MIIFrQYJKoZIhvcNAQcCoIIFnjCCBZoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3YyRfRTESUHDbcY2WZ4TuT9c
# n0qgggM/MIIDOzCCAiOgAwIBAgIQUX124VbHSJJMbDI6xReFHTANBgkqhkiG9w0B
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
# hvcNAQkEMRYEFCOlLygmtydTCuMTgd90iTRYGe6JMA0GCSqGSIb3DQEBAQUABIIB
# AE0VUdPiWf2ur+KxMm3ROYMiChGGZHwtj8/xj545EFIzJsdmulo52LgpZL7oE8+E
# +N9R+EA9U+a0Dkhj49GDg5kBhoxy3Uo6s1uLsrMZp40iNlMzOs0uMxcV9agWX5ti
# LGI37TZvopEFj2ljIrY1Nnnu0uKwdBUHyngz9kLdqYc1EmXCfIJZuYdu8PDMckqN
# KUeykBKbEJqrlNmghYDchPhjy1sacjwnAKuZ9BLh8kKaqP6cesDUpjsZpm9xRns/
# 65ClmOMmi+3dIL4YWPDtQXlH2XufrT2xY7FrE64JVSjvVVuwL5TgR9RQ5x3vtlUW
# Vhv+la4u4zXm4fl+S+D2QAs=
# SIG # End signature block
