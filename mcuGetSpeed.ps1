param(
    [string] $cpu = "ATSAM3X8E",
    [string] $board = "arduino-due",
    [int] $log = 1
)

Set-Location $PSScriptRoot

$driver = ./mcuGetDriver.ps1 $cpu
$boardPath = "$PSScriptRoot/../../platforms/$board"
$driverPath = "$PSScriptRoot/../../submodules/drivers/platforms/$driver"

if ($cpu -like "STM32*" -or $cpu -like "*SAM*")
{
    $swoFrequencyFile = Get-Content "$driverPath/ItmDriver.h" -Raw
    if ($swoFrequencyFile -match 'ItmBaudrate\s*=\s*(\d+)\s*;') {
        $swoFrequency = [uint32]$matches[1]
    }
    else {
        Write-Warning "ITM frequency isn't set. Write in ItmDriver.h:"
        Write-Warning "static constexpr uint32_t ItmBaudrate = 2250000;"
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
    }
    elseif ($cpu -like "STM32*") {
        $cpuFrequencyFile = Get-Content "$boardPath/*.ioc" -Raw
        if ($cpuFrequencyFile -match 'RCC\.SYSCLKFreq_VALUE=(\d+)') {
            $cpuFrequency = [int]$matches[1]
        }
        if ($cpu -match "STM32..") {
            $mcuLine = $matches[0].ToLower()
        }
    }
    if ($env:OCD_PATH) {
        if (Test-Path -Path $env:OCD_PATH) {
            $cfg = (Get-ChildItem -Path "$env:OCD_PATH/openocd/scripts/target" -Filter "*$mcuLine*").Name;
        }
    }
    return $swoFrequency, $cpuFrequency, $cfg
}
else {
    Write-Error "Selected not ARM device"
}