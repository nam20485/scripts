<#
.SYNOPSIS
    Sets up port forwarding and firewall rules for SSH access to WSL2.

.PARAMETER Cleanup
    Removes the port forwarding and firewall rules.

.EXAMPLE
    .\setup-networking.ps1
    Sets up port forwarding and firewall rules.

    .\setup-networking.ps1 -Cleanup
    Removes the port forwarding and firewall rules.
#>

param (
    [switch]$Cleanup
)

Import-Module $PSScriptRoot\..\..\Utils\Utils.psm1

$ListenAddr = "0.0.0.0"
$ListenPort = 2222
$fwRuleName = 'Allow WSL SSH Forwarded Port'

if ($Cleanup) {
    netsh interface portproxy delete v4tov4 listenaddress=$ListenAddr listenport=$ListenPort
    Remove-NetFirewallRule -DisplayName $fwRuleName
    Write-Host "Port forwarding and firewall rules removed."
    exit
}

Function Test-WslSsh-Is-Running {
    # Check if SSH is running, if not, start it
    $sshRunning = wsl ps -ef | Select-String -Pattern "sshd"
    if (-not $sshRunning) {
        # Check if SSH is installed, if not, install into WSL
        $sshInstalled = wsl dpkg -l | Select-String -Pattern "openssh-server"
        if (-not $sshInstalled) {
            Write-Host "OpenSSH server install not detected. Installing OpenSSH server in WSL..."
            wsl sudo apt-get update --no-install-recommends
            wsl sudo apt-get install -y openssh-server
            Write-Host "OpenSSH server installation completed."
        } else {
            Write-Host "OpenSSH server is installed in WSL."
        }

        Write-Host "Starting SSH server in WSL..."
        wsl sudo service ssh start
    } else {
        Write-Host "SSH server is running in WSL."
    }
}

# # If elevation needed, start new process
#Start-As-Admin

# # Check if WSL is running, if not, start it
Test-WslSsh-Is-Running

# Check if the IP Helper service is running, if not, start interface
# (this is the service that implements portproxy command)
if (-not (Test-Service-Is-Running -ServiceName 'iphlpsvc' -Start $true)) {
    Write-Host "Failed to start IP Helper service. Please check your system configuration."
    exit 1
}

try {
    netsh interface portproxy delete v4tov4 listenaddress=$ListenAddr listenport=$ListenPort
    Write-Host "Deleted any existing port forwarding rule."
} catch {
    Write-Host "Failed to delete port forwarding rule: $_"'iphlpsvc'
}

try {
    netsh interface portproxy add v4tov4 listenaddress=$ListenAddr listenport=$ListenPort connectaddress=$WslAddr connectport=$WslPort
    Write-Host "Added new port forwarding rule."
    netsh interface portproxy show v4tov4 listenaddress=$ListenAddr listenport=$ListenPort
} catch {
    Write-Host "Failed to add port forwarding rule: $_"
}

# check if rule already exists
$existingRule = Get-NetFirewallRule -DisplayName $fwRuleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "Firewall rule already exists. Deleting it..."
    Remove-NetFirewallRule -DisplayName $fwRuleName
} 

Write-Host "Added new firewall rule..."
New-NetFirewallRule -DisplayName $fwRuleName -Direction Inbound -Protocol TCP -LocalPort $ListenPort -Action Allow -Profile Public,Private -Enabled True -Description "Allow SSH access to WSL2 on port $ListenPort"
#netsh advfirewall firewall add rule name="Open Port $ListenPort for WSL2" dir=in action=allow protocol=TCP localport=$ListenPort

#$HostName = (wsl hostname -s)
$HostName = (hostname)
$HostIpAddr = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -eq "vEthernet (WSL)" }).IPAddress
$HostIpAddr = $HostIpAddr | Select-Object -First 1

Write-Host "WSL2 SSH & Port Forwarding is set up. You can connect to WSL2 SSH using either of the following commands:" -ForegroundColor Green
Write-Host "ssh -p $ListenPort <user>@$HostName" -ForegroundColor White
Write-Host "ssh -p $ListenPort <user>@$HostIpAddr" -ForegroundColor White
Write-Host "ssh -p $WslPort <user>@$WslAddr (internal)" -ForegroundColor White 
Write-Host "You can use the same command to connect to WSL2 from a remote computer. Just replace $ListenAddr with the public IP address of the host machine."

# To remove port forwarding rule: netsh interface portproxy delete v4tov4 listenaddress=$ListenAddr listenport=$ListenPort
# To remove firewall rule: Remove-NetFirewallRule -DisplayName $fwRuleName



# SIG # Begin signature block
# MIIb0gYJKoZIhvcNAQcCoIIbwzCCG78CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPal6wEXcdMBHZQRyPtlAKRF6
# hZagghY+MIIDOzCCAiOgAwIBAgIQEPx8OAWru4dKWWq0sRKiezANBgkqhkiG9w0B
# AQsFADAjMSEwHwYDVQQDDBhNeUNvZGVTaWduaW5nQ2VydGlmaWNhdGUwHhcNMjUw
# NDEzMDk1NDQ0WhcNMjYwNDEzMTAxNDQ0WjAjMSEwHwYDVQQDDBhNeUNvZGVTaWdu
# aW5nQ2VydGlmaWNhdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDI
# S80ozxWesC313QaeL5EA0ItXU9N1x9Og88hU3HGfpHEJuH/9aVywb84089bIfHLK
# Udx0XCiAfjGzM374tdZfwsGAi1hYt7PqAIhzKMUIcH65OBn1BDlMExVzVtt/vjCf
# /82m/unl9yXvCNYQYoBNkZXVg5eXCWpYR+Q+vlv9+/q3On4pjTwZm6yIlLWHn4Ej
# CkNbea3jCLwNjovN1pEuIJbF/HxrPa0oPh7tpHEe1iuLi/Ocr2AdMVIQQDJ7h1zS
# PkkPG3NvnFBHm7539o7IcgUjrHjgl9zKdUGQRvhOZETFxb2rUsI0JfYWBbFKHCgd
# gpCh0JbzKelPyLBBK+rRAgMBAAGjazBpMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAjBgNVHREEHDAaghhNeUNvZGVTaWduaW5nQ2VydGlmaWNh
# dGUwHQYDVR0OBBYEFITPMqHooDeasAIDUrrbQrxvm6wDMA0GCSqGSIb3DQEBCwUA
# A4IBAQBKXp6HgoqxPL0iAm1IvIxt3SSM+KsfKQKjxqxt8sZLR+m7CxNIvRsFL2u1
# e+129HXhoQ9iH09E7QI4rzN54sEtDKiijuvV5i5zdIbDB4rcDIASm3iV/5tmV/Zz
# e3ZZmLr1bbedpEYa21+j9rjPQaYE4xHs+hXJfrYoEOezHhnxcLg0UCIk/ArMUeZp
# gEyKemzIcXMy/XQ+tDA618z7z2vzKWpcQH+6Ig2riW00FH2+P+uJe+A2WrLFFOtj
# ZFh+xBsJqrf/h7W+0HRLlq+gXnVOswjWpaV7fpw7Q+75fHQQzHjGS6KU8ygKDB86
# E5dZptPMchi0vV2HhLkXoFlc2dhrMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c
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
# XTCCBMWgAwIBAgIQOlJqLITOVeYdZfzMEtjpiTANBgkqhkiG9w0BAQwFADBVMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNT
# ZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNDAxMTUwMDAw
# MDBaFw0zNTA0MTQyMzU5NTlaMG4xCzAJBgNVBAYTAkdCMRMwEQYDVQQIEwpNYW5j
# aGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3Rp
# Z28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNTCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBAI3RZ/TBSJu9/ThJOk1hgZvD2NxFpWEENo0GnuOY
# loD11BlbmKCGtcY0xiMrsN7LlEgcyoshtP3P2J/vneZhuiMmspY7hk/Q3l0FPZPB
# llo9vwT6GpoNnxXLZz7HU2ITBsTNOs9fhbdAWr/Mm8MNtYov32osvjYYlDNfefnB
# ajrQqSV8Wf5ZvbaY5lZhKqQJUaXxpi4TXZKohLgxU7g9RrFd477j7jxilCU2ptz+
# d1OCzNFAsXgyPEM+NEMPUz2q+ktNlxMZXPF9WLIhOhE3E8/oNSJkNTqhcBGsbDI/
# 1qCU9fBhuSojZ0u5/1+IjMG6AINyI6XLxM8OAGQmaMB8gs2IZxUTOD7jTFR2HE1x
# oL7qvSO4+JHtvNceHu//dGeVm5Pdkay3Et+YTt9EwAXBsd0PPmC0cuqNJNcOI0Xn
# wjE+2+Zk8bauVz5ir7YHz7mlj5Bmf7W8SJ8jQwO2IDoHHFC46ePg+eoNors0QrC0
# PWnOgDeMkW6gmLBtq3CEOSDU8iNicwNsNb7ABz0W1E3qlSw7jTmNoGCKCgVkLD2F
# aMs2qAVVOjuUxvmtWMn1pIFVUvZ1yrPIVbYt1aTld2nrmh544Auh3tgggy/WluoL
# XlHtAJgvFwrVsKXj8ekFt0TmaPL0lHvQEe5jHbufhc05lvCtdwbfBl/2ARSTuy1s
# 8CgFAgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBRfWO1MMXqiYUKNUoC6s2GXGaIy
# mzAdBgNVHQ4EFgQUaO+kMklptlI4HepDOSz0FGqeDIUwDgYDVR0PAQH/BAQDAgbA
# MAwGA1UdEwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAow
# CDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0
# LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1Bggr
# BgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5j
# b20wDQYJKoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht
# 2PFDxKKFOct/awAEWgHQMVHo l9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g
# 98M/yzRyqUOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiW
# l8eFARK3PmLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7e
# XomvMm0/GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xB
# rq9fLrfe8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384
# OKm0r568Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQ
# kpo+ffv5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL
# 1Y2x/955S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF
# 1u6Ci3TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J3
# 11uahxCweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4P
# KWVT0/MYIE/jCCBPoCAQEwNzAjMSEwHwYDVQQDDBhNeUNvZGVTaWduaW5nQ2VydGl
# maWNhdGUCEBD8fDgFq7uH SllqtLESonswCQYFKw4DAhoFAKB4MBgGCisGAQQBgjc
# CAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwY
# BBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFALTNDThH5M2
# n7oYZtROW+DrFO3PMA0GCSqGSIb3DQEBAQUABIIBAGCKK4va8Mry0NLsHF7kVE01
# vaNNAflJe1gKQffN11Ov0ehvln57b1QgS2yJ7BH9vhwsa2P+K0zs//5pgBuVNSsj
# +yh7uSZ37nGfdsveo01jDTcgL/plPH5xvVrbHLn/RuSJdhuQ/oZ+6m3kbY77TpHb
# +iSF7cDx3TQ2UZTMHsf+AD7xihWxG4DMJ5frpzK/ADfyNBSvjxFovUdeJbg5C/vPb
# 3Kw+zfN0VA+e8AEo7b32CPiJMsIpc4fWxvzi8m2FVOdWX8r84aYF7ikRjYCv7O+Oh
# n3cHdsYW2zrOQFxM59/3RSGs4HWnsV1HWm0iCdsuQJzbXVUZTiaLqNjeKl3KChgg
# MiMIIDHgYJKoZIhvcNAQkGMYIDDzCCAwsCAQEwaTBVMQswCQYDVQQGEwJHQjEYMB
# YGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBU
# aW1lIFN0YW1waW5nIENBIFIzNgIQOlJqLITOVeYdZfzMEtjpiTANBglghkgBZQME
# AgIFAKB5MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTI1MDQxMzEwNTUzMVowPwYJKoZIhvcNAQkEMTIEMJ67ExMv0sRZpYlqdna18SiL
# GmJ6jXtSQ+UElnap6jtWHcMHKcdmk9clLsQuDkveXDANBgkqhkiG9w0BAQEFAASCA
# gA+2HJLuWN0dtdQorcBWw8NQuXk7Zf6fVw51XUNlcKIaieCgJbxhjqnpUznLJMmp5
# 7Le300JOEn/cZ5lTp/NqHitFOfSlBYJBH/UWQvypZY1SaiKyyZtu1G9VTX0omzFn
# 4tXMp4ZzCO1oPbxSpp4RI73j97qcxzQZYqp8rteS8+6zkQ7W16RttxjFwSmzXSc2
# Hywexyjjxro75UjJfTzBKCqfefe+XFmlV9ngT+89c99Gs1HNC/mDrimBO9SqF7wSZ
# 7N0Xc9yIPVz4FLzVQDn1q/vPmlatqWKF5q4qBPizGJd3Mt7ysPkNaLXHe+VSzgr7v
# EdrySz4UkuEXv6A61M32517neHBBkDybQa2wHdJBxd90heQIR7Tiqyp7GMvH5GVvP
# p5UTDh9dP3TmR6qxcbmXebivA4+fH50sPOfBxrC6S1MX2dBVRbGMy8IhpZMgXYaD
# TyDLvZG1yhcJSpYAsAf018HfWTLXjhmJIWIxoW6/6kwScyCFsvaB3jXMVuCM0DNxF
# iN2fR6wMITurGCY2n4AbpgnXj+KMfB1H2oE9JPHoHKdjzjPC3K7SLhunsua9kYl+L
# 78DflwCflBEZvaSTomPyMyU8Vv9+abHt/sZa3LlcURHL/EjULpB5ZpqjCIKAADTUS
# BRnxW0Y7gEsNbTtjwcFbkGYMIIfiltpzzEaFgQ==
# SIG # End signature block
