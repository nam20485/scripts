$pageTextToHighlight = "Since%20Windows%2010%20build%2014971, command%20shell%20for%20File%20Explorer"
$url = "https://en.wikipedia.org/wiki/PowerShell"

$fullUrl = "$url#:~:text=$pageTextToHighlight"
# Open the URL in the default web browser
Start-Process $fullUrl

#https://en.wikipedia.org/wiki/PowerShell#:~:text=Since%20Windows%2010%20build%2014971, command%20shell%20for%20File%20Explorer.