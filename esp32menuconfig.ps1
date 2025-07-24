# $dir = Get-Location
Set-Location ${ENV:IDF_PATH}
./export.ps1
$dir = split-path -parent $MyInvocation.MyCommand.Definition
Set-Location $dir
Set-Location ..
idf.py menuconfig
pause