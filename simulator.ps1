param([string] $build = "Debug")

# Ninja check
$ninjaPath = "C:\msys64\mingw64\bin"
if (-not (Test-Path -Path "$ninjaPath\ninja.exe"))
{
    Write-Error "Ninja at $ninjaPath is not found. Install https://packages.msys2.org/packages/mingw-w64-x86_64-ninja"
}
if ($env:Path -notlike "*$ninjaPath*")
{
    $env:Path += ";$ninjaPath"
}

# # Makefile check
# $makePath = "C:\msys64\usr\bin"
# if (-not (Test-Path -Path "$makePath\make.exe"))
# {
#     Write-Error "Make at $makePath is not found. Install https://packages.msys2.org/packages/make"
# }
# if ($env:Path -notlike "*$makePath*")
# {
#     $env:Path += ";$makePath"
# }

# Compiler check
$compilerPath1 = "C:\msys64\ucrt64\bin"
$compilerPath2 = "C:\msys64\mingw64\bin"
if (Test-Path -Path "$compilerPath1\gcc.exe")
{
    $compilerPath = $compilerPath1
}
elseif (Test-Path -Path "$compilerPath2\gcc.exe")
{
    $compilerPath = $compilerPath2
}
else
{
    Write-Error "Compiler at $compilerPath1 and $compilerPath2 is not found. Install https://www.msys2.org/"
}

# Debugger check
$debuggerPath = "C:\msys64\mingw64\bin\gdb.exe"
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