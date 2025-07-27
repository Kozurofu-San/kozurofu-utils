param([string] $platform = "ESP32", [string] $programmer, [string] $server = 'localhost', [int] $baudrate = 115200)

$jlink_swo = "C:\Program Files\SEGGER\JLink\JLinkSWOViewerCL.exe"

if ($platform -like "*STM32*") {
    if ($programmer -eq "jlink")
    {
        & $jlink_swo -device STM32F103C8 -cpufreq 72000000 -swofreq 2250000 -itmmask 0xF
    }
    else
    {
        python ./swo_parser.py $server 2001
    }
    
}
if ($platform -like "*ESP32*") {
    python ./serial_parser.py $baudrate
}