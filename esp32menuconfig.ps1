& "${ENV:IDF_PATH}/export.ps1"
# idf.py menuconfig
Set-Location "$PSScriptRoot/../../build"
ninja menuconfig
pause