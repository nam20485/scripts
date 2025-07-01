@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'CodeSigning.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'c1a9b8d7-e6f5-4c3b-9a8d-7f6e5d4c3b2a'

    # Author of this module
    Author = 'Gemini Code Assist'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'A module to create a self-signed code signing certificate and trust it on the local machine.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'New-SelfSignedCodeSigningCertificate',
        'Invoke-CodeSigning'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('CodeSigning', 'Certificate', 'Security', 'SelfSigned')

            # A URL to the license for this module.
            # LicenseUri = ''

        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
# SIG # Begin signature block
# MIIFrQYJKoZIhvcNAQcCoIIFnjCCBZoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEwePReeSaDbOK0nHOSEiaXt7
# l0ygggM/MIIDOzCCAiOgAwIBAgIQUX124VbHSJJMbDI6xReFHTANBgkqhkiG9w0B
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
# hvcNAQkEMRYEFOG6qQQsT6FHCIWXBO269ZDJS4xvMA0GCSqGSIb3DQEBAQUABIIB
# AEGbiTA7DvyeyEK7Oc7qiQM3WwDSlC81ejs8d4BRIHe9lZH1wEYPTWSm1FedpXdF
# ajt3tIROJh3kw3JDO1Voxa68opAu21TwZYCtPUFZbiJJH1dcGNCbmUdrkx8axFp/
# +/mZgbSik8Kyz4eUMXkS05l/Q00u+ub/FtlgBqyt40IZvydC9+jtD5ZqmGzXTpfD
# 4HBM5SIGXkJmyYv5w4yAc4s+UcsXeXHNXlUxURYYEypDFvo6FH6vDdJfjyeJZ+Kd
# gPOAdYcm+9jb5khOaReO5EzsPc6OLjGWU5HVVAr3vXDy3eHdVDfB4bXZJ6bqzvBB
# IojDhx3D3uzJ5y6qZrg6Yaw=
# SIG # End signature block
