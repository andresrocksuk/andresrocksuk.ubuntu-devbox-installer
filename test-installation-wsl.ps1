[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu-24.04"
)

$wslSourcePath = $PSScriptRoot -replace "C:", "/mnt/c" -replace "\\", "/"
wsl --distribution $Distribution -- bash -c "cd $wslSourcePath/src/tests && bash test-installation.sh"
