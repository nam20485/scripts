#set command to first argument
$command = $args[0]

$address = "PRECISION5820"

do {
    $pingResult = Test-Connection -ComputerName $address -Count 1 -ErrorAction SilentlyContinue
    if (-not $pingResult) {
        Start-Sleep -Seconds 5
    }
} while (-not $pingResult)

Write-Host "Host is up. Running command..."

# run command
Invoke-Expression $command
# or you can use Start-Process if you want to run a program instead of a command
# Start-Process -FilePath "C:\Path\To\YourProgram.exe" -ArgumentList $command

