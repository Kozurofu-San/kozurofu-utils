param([string] $build = "Debug")

$start_time = Get-Date

$filePath = "C:/vcpkg"
if (-not (Test-Path -Path $filePath))
{
    Write-Host "Installation vcpkg"
    git clone https://github.com/microsoft/vcpkg.git "C:/"
    Set-Location $filePath
    ./bootstrap-vcpkg.bat
    ./vcpkg.exe install sdl2 --triplet x64-mingw-static --host-triplet x64-mingw-static
}

$filePath = "C:/vcpkg/packages/sdl2_x64-mingw-static/share/sdl2"
if (-not (Test-Path -Path $filePath))
{
    Write-Error "$filePath not found"
    exit 1
}

$compilerPath = "C:\msys64\ucrt64\bin"
if (-not (Test-Path -Path $compilerPath))
{
    Write-Error "Compiler at $compilerPath not found"
    exit 1
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
    -DSIMULATOR=1 `
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