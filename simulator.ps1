param([string] $build = "Debug", [string] $server = "localhost", [string] $workspace_path = "C:/tools")

Set-Location $PSScriptRoot
./checkInstall.ps1 "gcc" $server $workspace_path
./checkInstall.ps1 "gdb" $server $workspace_path
$compilerPath = "$env:MSYS_PATH\mingw64\bin"
$env:PATH=";$compilerPath;$env:PATH"
./checkInstall.ps1 "vcpkg" $server $workspace_path
Set-Location $PSScriptRoot

$filePath = "$env:VCPKG_PATH/packages/sdl2_x64-mingw-static/share/sdl2"

$start_time = Get-Date
$dir = Get-Location

$build_folder = 'build-lvgl'
if (-not(Test-Path -Path $build_folder)) {
    mkdir $build_folder | Out-Null
    Write-Host "Build folder is created"
}
$dir = Get-Location
Set-Location $build_folder

cmake .. -G Ninja `
    -DCMAKE_BUILD_TYPE="${build}" `
    -DCMAKE_COLOR_DIAGNOSTICS="ON" `
    -DSDL2_DIR="$filePath" `
    -DCMAKE_SYSTEM_NAME=Generic `
    -DTARGET="Simulator" `
    -DCMAKE_TOOLCHAIN_FILE="C:/vcpkg/scripts/buildsystems/vcpkg.cmake" `
    -DCMAKE_C_COMPILER="$compilerPath/gcc.exe" `
    -DCMAKE_ASM_COMPILER="$compilerPath/gcc.exe" `
    -DCMAKE_CXX_COMPILER="$compilerPath/g++.exe" `
    -DCMAKE_LINKER="$compilerPath/g++.exe"

ninja -j16
# $lddPath = "C:\msys64\usr\bin"
# & $lddPath\ldd.exe $dir/$build_folder/main.exe
& $compilerPath/size.exe --format=GNU $dir/$build_folder/main.exe
Set-Location $dir

$end_time = Get-Date
$executionTime =  $end_time - $start_time
Write-Host "Time elapsed $($executionTime.ToString("m':'ss\.fff"))"