& "${ENV:IDF_PATH}/export.ps1"
Set-Location "$PSScriptRoot/../../"
idf.py menuconfig
pause