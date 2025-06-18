 # Download the Docker Compose file
Write-Host "Downloading Docker Compose file..." -ForegroundColor Cyan

try {   
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
    $uri = "https://raw.githubusercontent.com/louislam/uptime-kuma/refs/heads/1.23.X/docker/docker-compose.yml"
    $UrlWithCacheBuster = "${uri}?timestamp=$(Get-Date -UFormat %s)"  # Append timestamp as a cache buster
    Write-Host "uri = [${UrlWithCacheBuster}]"
    $response = Invoke-WebRequest -UseBasicParsing -Uri $UrlWithCacheBuster `
    -WebSession $session `
    -Headers @{
        "authority"="raw.githubusercontent.com"
        "method"="GET"
        "path"="/louislam/uptime-kuma/refs/heads/1.23.X/docker/docker-compose.yml"
        "scheme"="https"
        "accept"="*/*"
        "accept-encoding"="gzip, deflate, br, zstd"
        "accept-language"="en-US,en;q=0.9"
        "dnt"="1"
        "if-none-match"="W/`"4811e912cce039e0cb01af829b4cd45138a14b4ec2cd7f0dbdcdd334e6767065`""
        "origin"="https://github.com"
        "priority"="u=1, i"
        "referer"="https://github.com/louislam/uptime-kuma/blob/1.23.X/docker/docker-compose.yml"
        "sec-ch-ua"="`"Not)A;Brand`";v=`"8`", `"Chromium`";v=`"138`", `"Google Chrome`";v=`"138`""
        "sec-ch-ua-mobile"="?0"
        "sec-ch-ua-platform"="`"Windows`""
        "sec-fetch-dest"="empty"
        "sec-fetch-mode"="cors"
        "sec-fetch-site"="cross-site"
    }

    if ($response.StatusCode -eq 200) {
        # Save the content to a file
        $response.Content | Out-File -FilePath "docker-compose.yml" -Encoding utf8
        Write-Host "Docker Compose file downloaded successfully." -ForegroundColor Green
    } else {
        throw "Failed to download file. Status code: $($response.StatusCode)"
    }
} catch {
    Write-Error "Failed to download Docker Compose file: $($_.Exception.Message)"
}