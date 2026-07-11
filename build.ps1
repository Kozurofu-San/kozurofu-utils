param(
    [string] $build,
    [string] $project,
    [string] $cpu = "ESP32",
    [string] $board,
    [int] $log,
    [string] $build_system,
    [string] $programmer,
    [string] $workspace_path,
    [string] $server
)

$start_time = Get-Date
$driver = ""

$rootDir = Get-Location

Set-Location $PSScriptRoot
./checkInstall.ps1 "msys" $server $workspace_path
./checkInstall.ps1 "cmake" $server $workspace_path

if ($build_system -eq "ninja")
{
    ./checkInstall.ps1 "msys" $server $workspace_path
    $build_system_bin = "$env:MSYS_PATH/mingw64/bin/ninja.exe"
    $build_system_alias = "Ninja"
}
elseif ($build_system -eq "make")
{
    ./checkInstall.ps1 "msys" $server $workspace_path
    $build_system_bin = "$env:MSYS_PATH/usr/bin/make.exe"
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

function Compile {
    cmake .. -G $build_system_alias `
    -DCMAKE_MAKE_PROGRAM="$build_system_bin" `
    -DCMAKE_BUILD_TYPE="${build}" `
    -DPLATFORM_DRIVER="${driver}" `
    -DCMAKE_PROJECT_NAME="${project}" `
    -DCMAKE_SYSTEM_NAME=Generic `
    -DLOG="${log}" `
    -DTARGET="$cpu" `
    -DBOARD="$board"  
}

$driver = ./mcuGetDriver.ps1 $cpu

# Edit CUBEMX cmake file
if ($cpu -like "*STM32*") 
{
    $filePath = Resolve-Path -Path "../../platforms/${board}/cmake/gcc-arm-none-eabi.cmake"
    if (-not (Test-Path -Path $filePath)) {
        Write-Error "File was not found: $filePath"
        exit 1
    }

    $content = Get-Content -Path $filePath -Raw
    if ($content -notmatch [regex]::Escape("PLATFORM_PATH")) {
        $content = $content.Replace("`${CMAKE_SOURCE_DIR}", "`${CMAKE_SOURCE_DIR}/`${PLATFORM_PATH}")
    }
    if ($content -notmatch [regex]::Escape("`$ENV{ARM_PATH}")) {
        $content = $content.Replace("arm-none-eabi", "`$ENV{ARM_PATH}/arm-none-eabi")
    }
    if ($content -notmatch [regex]::Escape("gcc.exe")) {
        $content = $content.Replace("gcc)", "gcc.exe)")
    }
    if ($content -notmatch [regex]::Escape("g++.exe")) {
        $content = $content.Replace("g++)", "g++.exe)")
    }
    if ($content -notmatch [regex]::Escape("objcopy.exe")) {
        $content = $content.Replace("objcopy)", "objcopy.exe)")
    }
    if ($content -notmatch [regex]::Escape("size.exe")) {
        $content = $content.Replace("size)", "size.exe)")
    }
    Set-Content -Path $filePath -Value $content -NoNewline
}

Set-Location $rootDir
$build_folder = 'build'
if (-not(Test-Path -Path $build_folder)) {
    mkdir $build_folder | Out-Null
    Write-Host "Build folder is created"
}
$dir = Get-Location
Set-Location $build_folder

switch -Wildcard ($cpu)
{
    "ESP32*"
    {
        if (-not $env:IDF_PATH) {
            Write-Error "Install ESP32 toolchain https://dl.espressif.com/dl/eim/ `
            Add the environmental variable IDF_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        $idf_exports = python "${ENV:IDF_PATH}/tools/activate.py" --export
        try
        {
            . $idf_exports
        }
        catch
        {
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
        break
    }

    "STM32*"
    {
        ../submodules/utils/checkInstall.ps1 "arm" $server $workspace_path
        Compile
    }

    "*SAM*"
    {
        ../submodules/utils/checkInstall.ps1 "arm" $server $workspace_path
        if (-not $env:ASF_PATH) {
            Write-Error "Install Atmel toolchain https://www.microchip.com/en-us/tools-resources/develop/libraries/advanced-software-framework `
            Add the environmental variable ASF_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        Compile
    }

    "PIC32*"
    {
        if (-not (Get-Command "xc32-gcc" -ErrorAction SilentlyContinue)) {
            Write-Error "Install PIC32 toolchain https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers/xc32 `
            Add the environmental variable PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        if (-not $env:PIC_PATH) {
            Write-Error "Install PIC10/12/16/18/24/32 IDE https://www.microchip.com/en-us/tools-resources/archives/mplab-ecosystem `
            MPLAB v6.20 is the latest IDE that supports PICKIT3
            Add the environmental variable PIC_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        Compile
    }

    "MSP430*"
    {
        if (-not $env:MSP430_PATH) {
            Write-Error "Install MSP430 toolchain https://www.ti.com/tool/MSP430-GCC-OPENSOURCE#downloads `
            Add the environmental variable MSP430_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        Compile
    }

    {$_ -like "ATtiny*" -or $_ -like "ATmega*" -or $_ -like "ATxmega*"}
    {
        if (-not $env:AVR_PATH) {
            Write-Error "Install MSP430 toolchain https://www.microchip.com/en-us/tools-resources/develop/microchip-studio/gcc-compilers `
            Add the environmental variable AVR_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        Compile
    }

    "PIC1*"
    {
        if (-not (Get-Command "xc8-gcc" -ErrorAction SilentlyContinue))
        {
            Write-Error "Install PIC8 toolchain https://www.microchip.com/en-us/tools-resources/develop/mplab-xc-compilers/xc8 `
            Add the environmental variable PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        if (-not $env:PIC_PATH) {
            Write-Error "Install PIC10/12/16/18/24/32 IDE https://www.microchip.com/en-us/tools-resources/archives/mplab-ecosystem `
            MPLAB v6.20 is the latest IDE that supports PICKIT3
            Add the environmental variable PIC_PATH. Execute: `
            rundll32.exe sysdm.cpl,EditEnvironmentVariables"
            exit
        }
        Compile
    }

    default
    {
        Write-Error "Wrong MCU"
        exit
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

& $build_system_bin -j16

if ($LASTEXITCODE -ne 0) {
    Write-Host "$build_system_alias failed" -ForegroundColor Red
    Remove-Item -Path "$PSScriptRoot/../../build/Template.bin" -ErrorAction SilentlyContinue
    Remove-Item -Path "$PSScriptRoot/../../build/Template.elf" -ErrorAction SilentlyContinue
    exit 1
}

if ($cpu -like "*ESP32*") { & $build_system_bin size }
Set-Location $dir
# idf.py size

./submodules/utils/launchGenerator.ps1 $cpu $board $log $programmer $workspace_path

$end_time = Get-Date
$executionTime =  $end_time - $start_time
Write-Host "Time elapsed $($executionTime.ToString("m':'ss\.fff"))"