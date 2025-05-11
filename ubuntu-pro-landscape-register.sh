#! 

sudo landscape-config --silent --account-name="${LANDSCAPE_ACCOUNT_NAME}" --computer-title="${LANDSCAPE_COMPUTER_TITLE}" --tags='' --script-users='nobody,landscape,root' --ping-url="http://${LANDSCAPE_FQDN}/ping" --url="https://${LANDSCAPE_FQDN}/message-system"


echo | openssl s_client -connect landscape.canonical.com:443 | openssl x509 | sudo tee /etc/landscape/server.pem


juju deploy landscape-client --config account-name='standalone' --config tags='' --config script-users='nobody,landscape,root' --config ping-url="http://${LANDSCAPE_FQDN}/ping" --config url="https://${LANDSCAPE_FQDN}/message-system"