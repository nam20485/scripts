#! /bin/pwsh

# Provision a new self-hosted runner on Linux
# https://github.com/nam20485/AgentAsAService/settings/actions/runners/new?arch=x64&os=linux

# Download

# Create a folder
mkdir actions-runner && cd actions-runner
# Download the latest runner package
curl -o actions-runner-linux-x64-2.324.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.324.0/actions-runner-linux-x64-2.324.0.tar.gz
# Optional: Validate the hash
echo "e8e24a3477da17040b4d6fa6d34c6ecb9a2879e800aa532518ec21e49e21d7b4  actions-runner-linux-x64-2.324.0.tar.gz" | shasum -a 256 -c
# Extract the installer
tar xzf ./actions-runner-linux-x64-2.324.0.tar.gz

# Configure

# Create the runner and start the configuration experience
$ ./config.sh --url https://github.com/nam20485/AgentAsAService --token AAN6UFDMV6GNUOMTZY432XDIIBQ5Y
# Last step, run it!
$ ./run.sh

# Using your self-hosted runner

# Use this YAML in your workflow file for each job
#runs-on: self-hosted