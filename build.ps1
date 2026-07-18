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

if ($build_system -eq "ninja") {
    ./checkInstall.ps1 "msys" $server $workspace_path
    $build_system_bin = "$env:MSYS_PATH/mingw64/bin/ninja.exe"
    $build_system_alias = "Ninja"
}
elseif ($build_system -eq "make") {
    ./checkInstall.ps1 "msys" $server $workspace_path
    $build_system_bin = "$env:MSYS_PATH/usr/bin/make.exe"
    $build_system_alias = "MSYS Makefiles"
}

if ($programmer -eq "jlink") {
    ./checkInstall.ps1 "jlink" $server $workspace_path
}
elseif ($cpu -like "STM32*" -or $cpu -like "*SAM*") {
    ./checkInstall.ps1 "ocd" $server $workspace_path
    ./checkInstall.ps1 "libusb" $server $workspace_path
    ./checkInstall.ps1 "stlink" $server $workspace_path
}
elseif ($cpu -like "*tiny*" -or $cpu -like "*mega*") {
    ./checkInstall.ps1 "avrdude" $server $workspace_path
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
if ($cpu -like "STM32*") {
    $filePath = Resolve-Path -Path "../../platforms/${board}/cmake/gcc-arm-none-eabi.cmake"
    if (-not (Test-Path -Path $filePath)) {
        Write-Error "File was not found: $filePath"
        exit 1
    }

    $content = Get-Content -Path $filePath -Raw
    if ($content -notmatch [regex]::Escape("PLATFORM_PATH")) {
        $content = $content.Replace("`${CMAKE_SOURCE_DIR}", "`${CMAKE_SOURCE_DIR}/`${PLATFORM_PATH}")
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
        ../submodules/utils/checkInstall.ps1 "idf" $server $workspace_path
        $idf_exports = python "${ENV:IDF_PATH}/tools/activate.py" --export
        try {
            . $idf_exports
        }
        catch {
            Write-Host $idf_exports
            Write-Warning "No IDF exports"
            exit 0
        }
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
        ../submodules/utils/checkInstall.ps1 "asf" $server $workspace_path
        Compile
    }

    "PIC32*"
    {
        ../submodules/utils/checkInstall.ps1 "pic"  $server $workspace_path
        ../submodules/utils/checkInstall.ps1 "xc32" $server $workspace_path
        Compile
    }

    "MSP430*"
    {
        ../submodules/utils/checkInstall.ps1 "msp430" $server $workspace_path
        Compile
    }

    {$_ -like "*tiny*" -or $_ -like "*mega*"}
    {
        ../submodules/utils/checkInstall.ps1 "avr" $server $workspace_path
        Compile
    }

    "PIC1*"
    {
        ../submodules/utils/checkInstall.ps1 "pic" $server $workspace_path
        ../submodules/utils/checkInstall.ps1 "xc8" $server $workspace_path
        Compile
    }

    default
    {
        Write-Error "Wrong CPU"
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