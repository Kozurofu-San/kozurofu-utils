param(
    [string] $cpu,
    [string] $board,
    [int] $log = 1,
    [string] $programmer,
    [string] $server = 'localhost',
    [int] $baudrate = 115200)

Set-Location $PSScriptRoot

$jlink_swo = "$env:JLINK_PATH/JLinkSWOViewerCL.exe"
$swoFrequency, $cpuFrequency, $cfg = ./mcuGetSpeed.ps1 $cpu $board $log

if ($cpu -like "*STM32*" -or $cpu -like "*SAM*")
{
    if ($programmer -eq "jlink")
    {
        & $jlink_swo -device $cpu -cpufreq $cpuFrequency -swofreq $swoFrequency -itmmask 0xF -outputfile "../../build/run.log"
    }
    else
    {
        python ./swo_parser.py $server 2001
    }
}

if ($cpu -like "*ESP32*")
{
    python ./serial_parser.py $baudrate
}
