param(
    [string] $build,
    [string] $project,
    [string] $cpu = "ATSAM3X8E",
    [string] $board = "arduino-due",
    [int] $log = 1,
    [string] $build_system,
    [string] $programmer,
    [string] $workspace_path
)

Set-Location $PSScriptRoot

if     ( $cpu -like "*STM32*"   ) { $driver = $cpu.Substring(0, 7) }
elseif ( $cpu -like "*SAM3*"    ) { $driver = "ATSAM3X" }
elseif ( $cpu -like "*PIC32MX*" ) { $driver = "PIC32MX" }
elseif ( $cpu -like "*ESP32*"   ) { $driver = "ESP32"   }
elseif ( $cpu -like "*MSP430*"  ) { $driver = "MSP430"  }
elseif ( $cpu -like "*ATtiny*"  ) { $driver = "AVR"     }
elseif ( $cpu -like "*ATmega*"  ) { $driver = "AVR"     }
elseif ( $cpu -like "*ATxmega*" ) { $driver = "AVR"     }

$boardPath = "$PSScriptRoot/../../platforms/$board"
$driverPath = "$PSScriptRoot/../../submodules/drivers/platforms/$driver"

$allowed = @()
if (Test-Path -Path "$PSScriptRoot/../../submodules/lvgl" -PathType Container) {
    $allowed += @("lvgl")
}

$launch = Get-Content launch.template.json -Raw | ConvertFrom-Json
if ($cpu -like "STM32*" -or $cpu -like "*SAM*")
{
    $allowed += @("ARM", "Debug", "Debug continue")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
    $arm = $launch.configurations | Where-Object name -eq 'ARM'
    $swoFrequency = 0
    $cpuFrequency = 0
    if ($log) {
        $swoFrequencyFile = Get-Content "$driverPath/LogDriver.h" -Raw
        if ($swoFrequencyFile -match 'StLinkV2MaxSpeed\s*=\s*(\d+)\s*;') {
            $swoFrequency = [uint32]$matches[1]
        }
        if ($cpu -like "*SAM*") {
            if ($cpu -match "SAM..") {
                $mcuLine = $matches[0].ToLower()
            }
            if ($cpu -match "SAM....") {
                $mcu = $matches[0].ToLower()
            }
            $cpuFrequencyFile = Get-Content "$env:ASF_PATH\sam\utils\cmsis\$mcuLine\include\$mcu.h" -Raw
            if ($cpuFrequencyFile -match 'CHIP_FREQ_CPU_MAX\s+\((\d+)UL\)') {
                $cpuFrequency = [int]$matches[1]
            }
            $cfg = (Get-ChildItem -Path "$env:OCD_PATH/../openocd/scripts/target" -Filter "*$mcuLine*").Name;
        }
        elseif ($cpu -like "STM32*") {
            $cpuFrequencyFile = Get-Content "$boardPath/*.ioc" -Raw
            if ($cpuFrequencyFile -match 'RCC\.SYSCLKFreq_VALUE=(\d+)') {
                $cpuFrequency = [int]$matches[1]
            }
            if ($cpu -match "STM32..") {
                $mcuLine = $matches[0].ToLower()
            }
            $cfg = (Get-ChildItem -Path "$env:OCD_PATH/../openocd/scripts/target" -Filter "*$mcuLine*").Name;
        }
        $arm.swoConfig.swoFrequency = $swoFrequency
        $arm.swoConfig.cpuFrequency = $cpuFrequency
        $arm.configFiles[1] = "target/$cfg"
    }
    else {
        $arm.PSObject.Properties.Remove("swoConfig")
    }
    if ($programmer -eq "jlink") {
        $arm.PSObject.Properties.Remove("configFiles")
        $arm.servertype = "jlink"
        $arm.serverpath = "${env:JLINK_PATH}/JLinkGDBServerCL.exe"
        $arm.name = "JLINK"
    }
    else {
        $arm.servertype = "openocd"
        $arm.serverpath = "${env:OCD_PATH}/openocd.exe"
        $arm.name = "ST-LINK"
    }

}
elseif ($cpu -like "ESP32*")
{
    $allowed += @("ESP32")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
}
elseif ($cpu -like "MSP430*")
{
    $allowed += @("MSP430")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
}
else
{
    exit
}

$launch | ConvertTo-Json -Depth 100 | Set-Content ../../.vscode/launch.json