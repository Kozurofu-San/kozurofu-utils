param([string] $build, [string] $project, [string] $cpu = "ESP32", [string] $board, [int] $log, [string] $build_system)

$start_time = Get-Date
$driver = ""

# MSYS2 check
if (-not $env:MSYS_PATH) {
    Write-Error "Install MSYS2 https://www.msys2.org/ `
    Add the environmental variable MSYS_PATH. Execute: `
    rundll32.exe sysdm.cpl,EditEnvironmentVariables"
    exit
}

# OpenOCD check
if (-not $env:OCD_PATH) {
    Write-Error "Install Openocd https://github.com/xpack-dev-tools/openocd-xpack/releases `
    Add the environmental variable OCD_PATH. Execute: `
    rundll32.exe sysdm.cpl,EditEnvironmentVariables"
}

# Ninja check
if ($build_system -eq "ninja")
{
    $ninjaPath = "$env:MSYS_PATH\mingw64\bin"
    if (-not (Test-Path -Path "$ninjaPath\ninja.exe"))
    {
        Write-Error "Ninja at $ninjaPath is not found. Install https://packages.msys2.org/packages/mingw-w64-x86_64-ninja"
    }
    if ($env:Path -notlike "*$ninjaPath*")
    {
        $env:Path += ";$ninjaPath"
    }
    $build_system_alias = "Ninja"
}

# Makefile check
if ($build_system -eq "make")
{
    $makePath = "$env:MSYS_PATH\usr\bin"
    if (-not (Test-Path -Path "$makePath\make.exe"))
    {
        Write-Error "Make at $makePath is not found. Install https://packages.msys2.org/packages/make"
    }
    if ($env:Path -notlike "*$makePath*")
    {
        $env:Path += ";$makePath"
    }
    $build_system_alias = "MSYS Makefiles"
}

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

if     ( $cpu -like "*STM32F1*" ) { $driver = "STM32F1" }
elseif ( $cpu -like "*STM32F4*" ) { $driver = "STM32F4" }
elseif ( $cpu -like "*ATSAM3X*" ) { $driver = "ATSAM3X" }
elseif ( $cpu -like "*PIC32MX*" ) { $driver = "PIC32MX" }
elseif ( $cpu -like "*ESP32*"   ) { $driver = "ESP32"   }
elseif ( $cpu -like "*MSP430*"  ) { $driver = "MSP430"  }
elseif ( $cpu -like "*ATtiny*"  ) { $driver = "AVR"     }
elseif ( $cpu -like "*ATmega*"  ) { $driver = "AVR"     }

if ($cpu -like "*STM32*") 
{

    $filePath = Resolve-Path -Path "./platforms/${board}/cmake/stm32cubemx/CMakeLists.txt"
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

    $filePath = Resolve-Path -Path "./platforms/${board}/cmake/gcc-arm-none-eabi.cmake"
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

    $filePath = Resolve-Path -Path "./platforms/${board}/cmake/stm32cubemx/CMakeLists.txt"
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

if ($cpu -like "*STM32*")
{
    if (-not (Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue))
    {
        Write-Error "Install ARM GNU toolchain https://gitlab.arm.com/tooling/gnu-toolchains-for-arm `
        Add the environmental variable PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    cmake .. -G $build_system_alias `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$cpu" `
        -DBOARD="$board"
}
elseif ($cpu -like "*ATSAM*")
{
    if (-not (Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue))
    {
        Write-Error "Install ARM GNU toolchain https://gitlab.arm.com/tooling/gnu-toolchains-for-arm `
        Add the environmental variable PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    if (-not $env:ASF_PATH) {
        Write-Error "Install Atmel toolchain https://www.microchip.com/en-us/tools-resources/develop/libraries/advanced-software-framework `
        Add the environmental variable ASF_PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    cmake .. -G $build_system_alias `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$cpu" `
        -DBOARD="$board"
}
elseif ($cpu -like "*PIC32MX*")
{
    if (-not (Get-Command "xc32-gcc" -ErrorAction SilentlyContinue))
    {
        Write-Error "Install PIC32 toolchain https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers/xc32 `
        Add the environmental variable PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    if (-not $env:PIC_PATH) {
        Write-Error "Install PIC16/24/32 IDE https://www.microchip.com/en-us/tools-resources/archives/mplab-ecosystem `
        MPLAB v6.20 is the latest IDE that supports PICKIT3
        Add the environmental variable PIC_PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    cmake .. -G $build_system_alias `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$cpu" `
        -DBOARD="$board"
}
elseif ($cpu -like "*ESP32*")
{
    if (-not $env:IDF_PATH) {
        Write-Error "Install ESP32 toolchain https://dl.espressif.com/dl/eim/ `
        Add the environmental variable IDF_PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
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
    cmake .. -G $build_system_alias `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DPYTHON="python" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DTARGET="$cpu" `
        -DBOARD="$board" `
        -DCMAKE_TOOLCHAIN_FILE="${ENV:IDF_PATH}/tools/cmake/toolchain-${cpu}.cmake" `
        -DESP_PLATFORM=1 `
        -DLOG="${log}" `
        -DSDKCONFIG="c:/Users/Kozurofu/Documents/hello_world/sdkconfig"
}
elseif ($cpu -like "*MSP430*")
{
    if (-not $env:MSP430_PATH) {
        Write-Error "Install MSP430 toolchain https://www.ti.com/tool/MSP430-GCC-OPENSOURCE#downloads `
        Add the environmental variable MSP430_PATH. Execute: `
        rundll32.exe sysdm.cpl,EditEnvironmentVariables"
        exit
    }
    cmake .. -G $build_system_alias `
        -DCMAKE_BUILD_TYPE="${build}" `
        -DPLATFORM_DRIVER="${driver}" `
        -DCMAKE_PROJECT_NAME="${project}" `
        -DCMAKE_SYSTEM_NAME=Generic `
        -DLOG="${log}" `
        -DTARGET="$cpu" `
        -DBOARD="$board"
        # msp430-elf-size -A build/Template.elf
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

& $build_system -j16

if ($LASTEXITCODE -ne 0) {
    Write-Host "$build_system_alias failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

if ($cpu -like "*ESP32*") { ninja size }
Set-Location $dir
# idf.py size

$end_time = Get-Date
$executionTime =  $end_time - $start_time
Write-Host "Time elapsed $($executionTime.ToString("m':'ss\.fff"))"