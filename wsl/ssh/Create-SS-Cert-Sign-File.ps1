<#
.SYNOPSIS
    Creates or retrieves a self-signed code signing certificate and uses it to sign specified files.
.DESCRIPTION
    This script orchestrates the process of code signing. It ensures a code-signing
    certificate exists (creating one if needed, or prompting to use an existing one)
    and then applies an Authenticode signature to the file(s) you specify.

    This script must be run from an elevated (Administrator) PowerShell session.
.PARAMETER Path
    An array of paths to the files to be signed. Wildcards are supported. This is a mandatory parameter.
.PARAMETER CertificateDnsName
    The DNS name for the code signing certificate to be used or created. Defaults to 'MyCodeSigningCertificate'.
.PARAMETER Force
    If specified, forces the creation of a new certificate, overwriting any existing
    certificate with the same name without prompting.
.EXAMPLE
    .\Invoke-Signature.ps1 -Path "C:\MyScripts\*.ps1"
    This command will sign all PowerShell scripts in the C:\MyScripts directory, using the default
    certificate name 'MyCodeSigningCertificate'.

.EXAMPLE
    .\Invoke-Signature.ps1 -Path ".\MyModule.psm1", ".\MyModule.psd1" -CertificateDnsName "MyModuleCert" -Force
    This command signs the specified module files using a certificate named 'MyModuleCert', overwriting
    any existing certificate with that name.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path,

    [string]$CertificateDnsName = "MyCodeSigningCertificate",

    [switch]$Force
)

#requires -RunAsAdministrator

# 1. Import the module and create/get the certificate using its function
$moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "CodeSigning\CodeSigning.psd1"
if (-not (Test-Path $moduleManifestPath)) {
    Write-Error "Could not find the CodeSigning module at '$moduleManifestPath'. Please ensure the module is in a 'CodeSigning' subdirectory relative to this script."
    return
}
Import-Module -Name $moduleManifestPath -Force

Write-Host "Ensuring certificate '$CertificateDnsName' exists..."
$cert = New-SelfSignedCodeSigningCertificate -DnsName $CertificateDnsName -Force:$Force
if (-not $cert) {
    Write-Error "Could not create or retrieve the certificate '$CertificateDnsName'. Aborting."
    return
}

Write-Host "Using certificate '$($cert.Subject)' with Thumbprint: $($cert.Thumbprint)"

# 2. Sign the specified files
Write-Host "Signing specified files..."
$signatures = Invoke-CodeSigning -Path $Path -Certificate $cert
if ($signatures) {
    Write-Host "Successfully signed the following files:" -ForegroundColor Green
    $signatures | Format-Table -AutoSize
}
else {
    Write-Warning "No files were signed. Please check the path(s) provided: $($Path -join ', ')"
}

Write-Host "Signing process complete."
# SIG # Begin signature block
# MIIb2AYJKoZIhvcNAQcCoIIbyTCCG8UCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUb1YsIEaFy+wFO1pVMjkIDGir
# TNqgghZDMIIDOzCCAiOgAwIBAgIQFfqoprj6t5VPYCCUl3qRqjANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhNeUNvZGVTaWduaW5nQ2VydGlmaWNhdGUwHhcNMjUw
# NDEzMDk1NzEyWhcNMjYwNDEzMTAxNzEyWjAjMSEwHwYDVQQDDBhNeUNvZGVTaWdu
# aW5nQ2VydGlmaWNhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDc
# XIL4i+gqd+A1K8VGOU7sSYuZ8NSRGtQhUxpfJjmVvVpUL1qC23zk5lSdFbM8Zmx8
# esXCfft0IC5WGIyN/udrUG/aGcvrVgpyZz15cUHgqhNjxFF9qVi6HYskG2Wkx9iE
# JgFdUbPJYfBE3y9qNOGB3QVbWIbvNfizbmJhG5lEfSgVfI/KaaYvvaV5inUgxhpo
# 6en6ZdnFPYb3rg5OngL1WaLGzvBLb1ynFFqC17ttEAEMc37u7kkJO+JzAE/E1DqM
# /di7+GuCZYTUE7NX8tDQ93qlUS1y+QOQhAActsbziQEELPJDaItZjfeMlKecEENw
# PWYlnwoXZODpjeuDh1otAgMBAAGjazBpMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAjBgNVHREEHDAaghhNeUNvZGVTaWduaW5nQ2VydGlmaWNh
# dGUwHQYDVR0OBBYEFMkkzovcRfDQIKEmhv++1TCUnPzGMA0GCSqGSIb3DQEBCwUA
# A4IBAQAM29cFSoLdc4AAiAiyEvFY2o2AlBp2RL20IgRwdHRnWkpcJrRDxHtUOFJP
# 5aaxnwhAsbfZ3lfAlYcLayYC/CJH0aoFR/NFLxjqx83J3xvCt7TIA5REY5+y3ydR
# zD+CVVbjIxxZ1e/VsyvKxqWZ0bJc5FkwNnPUky1xCM7Y0ed53F258NMnmv+vS3EU
# hg++L8H1ijdBYLPET6lMph2mRRo5V8p3ha5QMxOF7cs/mzxi8TYo1Bi1Pwf0wVGV
# YBvg9dKAzT6DJObeFbmwgyt1QZCnUPJBxHprT1AGOLJhABpQNeAFEhDOUix08RW9
# GdJm9Dn5/JBW3VFFMLP661kkUenoMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c
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
# +wIBATA3MCMxITAfBgNVBAMMGE15Q29kZVNpZ25pbmdDZXJ0aWZpY2F0ZQIQFfqo
# prj6t5VPYCCUl3qRqjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU/i2EeTGsgACSE5cSKiCHGWf9
# m4MwDQYJKoZIhvcNAQEBBQAEggEAAJ/hHzwpi6XTcldUdJBsfr3CVI3f2/HP7+1F
# I7XEs0ApYgNMsXLyq5OvQSAun9qy3eGIAhwCN1PzmLKc6pKmiWutdfLiZBd1J9Oh
# YSgEW54nw/Ex5u/12kAdSmq6b5/VdLz3uvY5Y32J7KwA7MbujmGgJajpvf4o9Svr
# j0Uuo+0paWqSqMMtkhOURONHMEgNLTiHW302QlWZDX/KQ65vBD2CZDA+80rPAbEp
# bD5mr5V+iO8HbmeMNbMTB/4hl3B/9R0roWHTORssDBzo4qNeglI8nzqNfFdrSlgq
# JLuQGv7CiQ2xgmmr4Ny9VbTm/o7bzhBTCx946K3U/RvhFGb4YqGCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MDcw
# MTAxNDc1OVowPwYJKoZIhvcNAQkEMTIEMGijerKeknnMm/RsIjEB6AtoVb32I5kz
# yWEOb9coE+8sCkHLuE45g+hiWYzofcSaoDANBgkqhkiG9w0BAQEFAASCAgA204tW
# 4LfN705+ie8xyicCRUvNMS4TZIdPIAY/fUyppxGeEpSHxo5hCbQA9fWrGX82l6aJ
# IAfmnYslkpCB1Pfy4Oi+QSTks5rBnMIepa1BqmFsC2lOi/4ruwUFVKV8mFs6ONFf
# Jl2ZxISc54QXUMQ0mk/Kq/WYDBGzzMoGafC2ceYhYICXb7z7uViM25K6iHLz8rPq
# 6WBipWDJ/9ZOZYmJ0v93oX05Kw+aTWeSTRJSg59LysWvozn35kUUrwMnIrgRHcO8
# Dld3ereveSGRO9nq6hOlOHdsvj5K0F9sRH0LjQPbJfpvFNBm0++YBnpqprb0XZNX
# 2U4M2Klb7MUXp31zbrHh1IQVdtCwza3F3XjNRsnFqmNSIkBAMO7Yda4iB2OGG1pN
# eEV5dpw5fiEGYjmrASvbhAGKkUe5cEK5UhEiEB84gk8yIFKZfRZzxs1wSGckz7wU
# Wdd1LdourgTDtn6vwYZtZVs+SIhWnxcbM2NjHkbsG5+jS79V9cDt4zT4LEQzTwpZ
# QV4xmxpLBxELahh9XoIn8lwvcY54ycWpk8FQJHj0uTnITLRmEBctYBpsker8HcCv
# 6R4/4WDSMgbBgPFMOM6AVHnveTITpEQwRGWrIenSx946wJD4Yy0l1OH4v5djfXrH
# BB0SjUMUkQ662Wr7bwikRw0oyPui11xNjd2/xg==
# SIG # End signature block
