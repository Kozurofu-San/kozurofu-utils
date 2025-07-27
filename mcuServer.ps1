param([string] $platform = "ESP32", [string] $programmer, [int] $port = 2000)

$jlink_gdb = "C:/Program Files/SEGGER/JLink/JLinkGDBServerCL.exe"
Stop-Process -Name openocd -ErrorAction SilentlyContinue

$gdb         = $port.ToString()
$tcl_port    = ($port+1).ToString()
$telnet_port = ($port+2).ToString()


if     ( $platform -like "*STM32F103*"  ) { $device = "STM32F103C8"     ; $cfg = "stm32f1x"   ; $cpu_frequency = 72000000  }
elseif ( $platform -like "*STM32F407*"  ) { $device = "STM32F407VE"     ; $cfg = "stm32f4x"   ; $cpu_frequency = 168000000 }
elseif ( $platform -like "*ATSAM3X*"    ) { $device = "ATSAM3X8E"       ; $cfg = "at91sam3XXX"; $cpu_frequency = 84000000  }
elseif ( $platform -like "*PIC32MX*"    ) { $device = "PIC32MX440F256H" }
elseif ( $platform -like "*ESP32"       ) { $device = "XTENSA LX6"      }
elseif ( $platform -like "*ESP32S3"     ) { $device = "XTENSA LX7"      }

if ($platform -like "*STM32*" -or $platform -like "*SAM3*")
{
    if ($programmer -eq "jlink")
    {
        & $jlink_gdb -device $device -if SWD -port $gdb -swoport $tcl_port -telnetport $telnet_port -speed 10000
    }
    elseif ($programmer -eq "other")
    {
        openocd `
        -f interface/stlink.cfg `
        -f target/$cfg.cfg `
        -c "set CONNECT_UNDER_RESET 1" `
        -c "gdb port $gdb" `
        -c "tcl port $tcl_port" `
        -c "telnet port $telnet_port" `
        -c "adapter speed 4000" `
        -c "bindto 0.0.0.0" `
        -c "tpiu config internal - uart off $cpu_frequency" `
        -c "itm ports on"
        # -c "reset_config srst_only srst_nogate connect_assert_srst" `
    }
}
elseif ($platform -like "*ESP32*")
{
    if ($programmer -eq "jlink")
    {
        & $jlink_gdb -device $device -if SWD -port $gdb -swoport $tcl_port -telnetport $telnet_port
    }
    elseif ($programmer -eq "other")
    {
        $ocd_path = "${ENV:IDF_TOOLS_PATH}\tools\openocd-esp32"
        $path = Get-ChildItem -Directory $ocd_path
        $ocd_path = "$ocd_path\$path"
        $path = Get-ChildItem -Directory $ocd_path
        $ocd_path = "$ocd_path\$path\bin"
        Set-Location $ocd_path
        .\openocd.exe `
            -f board/esp32s3-builtin.cfg `
            -c "gdb port $gdb" `
            -c "tcl port $tcl_port" `
            -c "bindto 0.0.0.0"
            # -c 'set ESP_RTOS none'
    }
}
elseif ($platform -like "*MSP430*")
{
    gdb_agent_console $env:MSP430_PATH/msp430.dat
}

pause