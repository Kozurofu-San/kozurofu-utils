param([string] $build = "Debug")

if ($env:Path -notlike "*C:\msys64\mingw64\bin*") { $env:Path += ";C:\msys64\mingw64\bin" }     # Ninja
if ($env:Path -notlike "*C:\msys64\usr\bin*") { $env:Path += ";C:\msys64\usr\bin" }             # make

$start_time = Get-Date
$dir = Get-Location

$compilerPath = "C:\msys64\ucrt64\bin"
$debuggerPath = "C:\msys64\mingw64\bin\gdb.exe"
if (-not (Test-Path -Path $compilerPath))
{
    Write-Error "Compiler at $compilerPath is not found. Install https://www.msys2.org/"
    exit 1
}
if (-not (Test-Path -Path $debuggerPath))
{
    Write-Error "Debugger at $debuggerPath is not found. Install https://packages.msys2.org/packages/mingw-w64-x86_64-gdb"
    exit 1
}
$env:PATH=";$compilerPath;$env:PATH"

$filePath = "C:/vcpkg"
if (-not (Test-Path -Path $filePath))
{
    Write-Host "Installation vcpkg from https://github.com/microsoft/vcpkg.git"
    git clone https://github.com/microsoft/vcpkg.git "C:/vcpkg"
}

$filePath = "C:/vcpkg/packages/sdl2_x64-mingw-static/share/sdl2"
if (-not (Test-Path -Path $filePath))
{
    Write-Host "Installation sdl2"
    Set-Location "C:/vcpkg"
    ./bootstrap-vcpkg.bat
    ./vcpkg.exe install sdl2 --triplet x64-mingw-static --host-triplet x64-mingw-static
}

# $path = Resolve-Path -Path "./lv_port_pc_vscode"
# Set-Location $path

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