param(
    [string] $cpu,
    [string] $board,
    [int] $log = 1,
    [string] $programmer,
    [string] $server = 'localhost',
    [int] $baudrate = 115200)

Set-Location $PSScriptRoot

$jlink_swo = "$env:JLINK_PATH/JLinkSWOViewerCL.exe"
$jlink_rtt = "$env:JLINK_PATH/JLinkRTTClient.exe"
if ($IsLinux) {
    $jlink_swo = "JLinkSWOViewer"
    $jlink_rtt = "JLinkRTTClient"
}

if ($cpu -like "STM32*" -or $cpu -like "*SAM*") {
    $swoFrequency, $cpuFrequency, $cfg = ./mcuGetSpeed.ps1 $cpu $board $log
    if ($programmer -eq "jlink") {
        # & $jlink_swo -device $cpu -cpufreq $cpuFrequency -swofreq $swoFrequency -itmmask 0xF -outputfile "../../build/run.log"
        & $jlink_rtt 
    }
    else {
        python3 ./swo_parser.py $server 2001
    }
}

if ($cpu -like "ESP32*" -or $cpu -like "*mega*") {
    python3 ./serial_parser.py $baudrate
}
