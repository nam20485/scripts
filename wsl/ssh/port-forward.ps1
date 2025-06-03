$ListenIp = "0.0.0.0"
$ListenPort = "2222"
$ConnectIp = "192.168.161.124"
$ConnectPort = "22"

#Start-Process -FilePath "netsh" -Verb runas -ArgumentList "interface portproxy add v4tov4 listenaddress=$ListenIp listenport=$ListenPort connectaddress=$ConnectIp connectport=$ConnectPort -Wait"

netsh interface portproxy add v4tov4 listenaddress=$ListenIp listenport=$ListenPort connectaddress=$ConnectIp connectport=$ConnectPort