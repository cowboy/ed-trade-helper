# To run the processor, create a shortcut with the following target:
# powershell -noexit -executionpolicy bypass "& "C:\path\to\ed-trade-helper\start-process.ps1"

# Obviously, this requires the GitHub Windows client.
. (Resolve-Path "$env:LOCALAPPDATA\GitHub\shell.ps1")

# Start processing images.
vagrant ssh -c /vagrant/process/process.sh