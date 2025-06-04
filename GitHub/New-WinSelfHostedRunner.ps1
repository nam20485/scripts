# https://github.com/nam20485/AgentAsAService/settings/actions/runners/new?arch=x64&os=win

# Download

# Create a folder under the drive root
mkdir actions-runner; cd actions-runner# Download the latest runner package
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.324.0/actions-runner-win-x64-2.324.0.zip -OutFile actions-runner-win-x64-2.324.0.zip
# Optional: Validate the hash
if((Get-FileHash -Path actions-runner-win-x64-2.324.0.zip -Algorithm SHA256).Hash.ToUpper() -ne '78b70ddc65e0c2f1940195859e453bdfaa098fe3475cf89bc9378614d2adc197'.ToUpper()){ throw 'Computed checksum did not match' }# Extract the installer

# Configure

# Create the runner and start the configuration experience
./config.cmd --url https://github.com/nam20485/AgentAsAService --token AAN6UFF4ZC7NDDOREWOJ4UTIICFYM
# Run it!
./run.cmd

# Using your self-hosted runner

# Use this YAML in your workflow file for each job
#runs-on: self-hosted
$ Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD/actions-runner-win-x64-2.324.0.zip", "$PWD")