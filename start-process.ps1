# Obviously, this requires the GitHub Windows client.
. (Resolve-Path "$env:LOCALAPPDATA\GitHub\shell.ps1")

# Start processing images.
vagrant ssh -c /vagrant/process/process.sh