# #! /bin/bash

# downloadUrlTarGz="https://code.visualstudio.com/sha/download?build=insider&os=cli-alpine-x64"
# fileNameTarGz="vscode_cli_alpine_x64_cli.tar.gz"
# https://code.visualstudio.com/sha/download?build=insider&os=cli-win32-x64

# ## targGz full ui build: 
# ## https://code.visualstudio.com/sha/download?build=insider&os=linux-x64
# downloadUrlUiDeb="https://code.visualstudio.com/sha/download?build=insider&os=linux-deb-x64"
# fileNameDeb="code-insiders.deb" #code-insiders_1.101.0-1747726248_amd64 (2).deb

# #curl -Lk $downloadUrlTarGz --output $fileNameTarGz
# curl -Lk $downloadUrlUiDeb --output $fileNameDeb
# sudo apt install ./$fileNameDeb

curl -Lk 'https://code.visualstudio.com/sha/download?build=insider&os=cli-alpine-x64' --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz
./code-insiders tunnel -help



