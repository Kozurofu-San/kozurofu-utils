param([string] $build, [string] $project, [string] $platform = "ESP32", [int] $log)

$start_time = Get-Date
$driver = ""

function SetEnv {
    param (
        [string] $path
    )
    
    $compiler_path = Get-ChildItem -Directory $path
    $compiler_path = Get-ChildItem -Directory $compiler_path
    $compiler_path = "$compiler_path\bin"
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not $currentPath.Contains($compiler_path))
    {
        $updatedPath = "$currentPath;$compiler_path;"
        [Environment]::SetEnvironmentVariable("PATH", $updatedPath, "User")
        Write-Host "Added environtment $compiler_path"
    }
}

if     ( $platform -like "*STM32F1*" ) { $driver = "STM32F1" }
elseif ( $platform -like "*STM32F4*" ) { $driver = "STM32F4" }
elseif ( $platform -like "*ATSAM3X*" ) { $driver = "ATSAM3X" }
elseif ( $platform -like "*PIC32MX*" ) { $driver = "PIC32MX" }
elseif ( $platform -like "*ESP32*"   ) { $driver = "ESP32"   }
elseif ( $platform -like "*MSP430*"  ) { $driver = "MSP430"  }

if ($platform -like "*STM32*") 
{

$filePath = Resolve-Path -Path "./platforms/${platform}/cmake/stm32cubemx/CMakeLists.txt"
if (-not (Test-Path -Path $filePath)) {
    Write-Error "File was not found: $filePath"
    exit 1
}

$content = Get-Content -Path $filePath -Raw

if ($content -notmatch [regex]::Escape("PLATFORM_PATH")) {
    $pattern = '\$\{CMAKE_SOURCE_DIR\}'
    $replacement = "`${CMAKE_SOURCE_DIR}/`${PLATFORM_PATH}"
    $newContent = $content -replace $pattern, $replacement
    Set-Content -Path $filePath -Value $newContent -NoNewline
}

$filePath = Resolve-Path -Path "./platforms/${platform}/cmake/gcc-arm-none-eabi.cmake"
if (-not (Test-Path -Path $filePath)) {
    Write-Error "File was not found: $filePath"
    exit 1
}

$content = Get-Content -Path $filePath -Raw

if ($content -notmatch [regex]::Escape("PLATFORM_PATH")) {
    $pattern = '\$\{CMAKE_SOURCE_DIR\}'
    $replacement = "`${CMAKE_SOURCE_DIR}/`${PLATFORM_PATH}"
    $newContent = $content -replace $pattern, $replacement
    Set-Content -Path $filePath -Value $newContent -NoNewline
}

$filePath = Resolve-Path -Path "./platforms/${platform}/cmake/stm32cubemx/CMakeLists.txt"
$targetString = '${CMAKE_SOURCE_DIR}/${PLATFORM_PATH}'

if (-not (Test-Path $filePath)) {
    Write-Host "File was not found: $filePath"
    exit 1
}

$content = Get-Content $filePath -Raw

if ($content -notmatch [regex]::Escape($targetString)) {
    $newContent = $content -replace '\$\{CMAKE_SOURCE_DIR\}', '$${CMAKE_SOURCE_DIR}/$${PLATFORM_PATH}'
    $newContent | Set-Content $filePath -NoNewline
}

}

$build_folder = 'build'
if (-not(Test-Path -Path $build_folder)) {
    mkdir $build_folder | Out-Null
    Write-Host "Build folder is created"
}
$dir = Get-Location
Set-Location $build_folder

if ($env:Path -notlike "*C:\msys64\mingw64\bin*") { $env:Path += ";C:\msys64\mingw64\bin" }     # Ninja
if ($env:Path -notlike "*C:\msys64\usr\bin*") { $env:Path += ";C:\msys64\usr\bin" }             # make

if ($platform -like "*STM32*")
{
    cmake .. -G "Ninja" `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$platform"
}
elseif ($platform -like "*ATSAM*")
{
    cmake .. -G Ninja `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$platform"
}
elseif ($platform -like "*PIC32MX*")
{
    cmake .. -G Ninja `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DTARGET="$platform"
}
elseif ($platform -like "*ESP32*")
{
    $idf_exports = python "${ENV:IDF_PATH}/tools/activate.py" --export
    try {
        . $idf_exports
    }
    catch {
        Write-Host $idf_exports
        Write-Warning "No IDF exports"
        exit 0
    }
    SetEnv("$HOME/.espressif/tools/xtensa-esp-elf-gdb")
    SetEnv("$HOME/.espressif/tools/riscv32-esp-elf-gdb")
    SetEnv("$HOME/.espressif/tools/xtensa-esp-elf")
    SetEnv("$HOME/.espressif/tools/riscv32-esp-elf")
    cmake .. -G Ninja `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DPYTHON="python" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DTARGET="$platform" `
        -DCMAKE_TOOLCHAIN_FILE="${ENV:IDF_PATH}/tools/cmake/toolchain-${platform}.cmake" `
        -DESP_PLATFORM=1 `
        -DLOG="${log}" `
        -DSDKCONFIG="c:/Users/Kozurofu/Documents/hello_world/sdkconfig"
}
elseif ($platform -like "*MSP430*")
{
    cmake .. -G Ninja `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DTARGET="$platform"
        # msp430-elf-size -A build/Template.elf
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

ninja -j16
# make -j32

if ($LASTEXITCODE -ne 0) {
    Write-Host "Ninja failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

if ($platform -like "*ESP32*") { ninja size }
Set-Location $dir
# idf.py size

$end_time = Get-Date
$executionTime =  $end_time - $start_time
Write-Host "Time elapsed $($executionTime.ToString("m':'ss\.fff"))"