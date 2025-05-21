## Tapo Camera Stream URL Generator

$cameraIpAddr = '192.168.1.8'
$username = 'nam20485tapo2'
$pw = 'PC$1$fCua2Z83bL'

$rstpPort = 554

$highQualityRstpSteam = "rtsp://${username}:${pw}@${cameraIpAddr}:$rstpPort/stream1"
$lowQualityRstpStream = "rtsp://${username}:${pw}@${cameraIpAddr}:$rstpPort/stream2"

$onvifPort = 2020
$onvifUrl = "http://${cameraIpAddr}:${onvifPort}/onvif/device_service"

Write-Host "Tapo 2 Camera Stream URLs: "
Write-Host "High Quality Stream: $highQualityRstpSteam"
Write-Host "Low Quality Stream: $lowQualityRstpStream"
Write-Host "ONVIF URL: $onvifUrl"

Read-Host -Prompt "Copy High Quality Stream URL to clipboard? (y/n)" | ForEach-Object {
    if ($_ -eq 'y') {
        $highQualityRstpSteam | Set-Clipboard
        Write-Host "High Quality Stream URL copied to clipboard."
    } else {
        Write-Host "High Quality Stream URL not copied."
    }
}  
