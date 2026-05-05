param([string] $platform = "ESP32", [string] $programmer, [string] $server = 'localhost', [string] $io, [int] $baudrate = 115200)

$jlink_swo = "C:\Program Files\SEGGER\JLink\JLinkSWOViewerCL.exe"

if     ( $platform -like "*STM32F103*"  ) { $device = "STM32F103C8"     ; $cpuFrequency = 72000000  }
elseif ( $platform -like "*STM32F407*"  ) { $device = "STM32F407VE"     ; $cpuFrequency = 168000000 }
elseif ( $platform -like "*ATSAM3X*"    ) { $device = "ATSAM3X8E"       ; $cpuFrequency = 84000000  }
elseif ( $platform -like "*PIC32MX*"    ) { $device = "PIC32MX440F256H" }

if ($platform -like "*STM32*" -or $platform -like "*SAM*")
{
    if ($programmer -eq "jlink")
    {
        & $jlink_swo -device $device -cpufreq $cpuFrequency -swofreq 2250000 -itmmask 0xF -outputfile "../../build/run.log"
    }
    else
    {
        python ./swo_parser.py $server 2001
    }
}

if ($platform -like "*ESP32*")
{
    python ./serial_parser.py $baudrate $io
}
