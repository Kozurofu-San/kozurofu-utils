param([string] $platform = "ESP32", [int] $cpu_frequency = 72000000, [int] $port = 2000)

Stop-Process -Name openocd -ErrorAction SilentlyContinue
$gdb = $port.ToString()
$tcl_port = ($port+1).ToString()
$telnet_port = ($port+2).ToString()

if ($platform -like "*STM32*")
{
    openocd `
    -f interface/stlink.cfg `
    -f target/stm32f1x.cfg `
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
elseif ($platform -like "*SAM3*")
{
    openocd `
    -f interface/jlink.cfg `
    -f target/at91sam3XXX.cfg `
    -c "set CONNECT_UNDER_RESET 1" `
    -c "gdb port $gdb" `
    -c "tcl port $tcl_port" `
    -c "telnet port $telnet_port" `
    -c "adapter speed 4000" `
    -c "bindto 0.0.0.0"
    # -c "reset_config srst_only srst_nogate connect_assert_srst" `
}
elseif ($platform -like "*ESP32*")
{
    $ocd_path = "${ENV:IDF_TOOLS_PATH}\tools\openocd-esp32"
    $path = Get-ChildItem -Directory $ocd_path
    $ocd_path = "$ocd_path\$path"
    $path = Get-ChildItem -Directory $ocd_path
    $ocd_path = "$ocd_path\$path\bin"
    Write-Host "HUESOS "$ocd_path
    Set-Location $ocd_path
    .\openocd.exe `
        -f board/esp32s3-builtin.cfg `
        -c "gdb port $gdb" `
        -c "tcl port $tcl_port" `
        -c "bindto 0.0.0.0"
        # -c 'set ESP_RTOS none'
}
elseif ($platform -like "*MSP430*")
{
    gdb_agent_console $env:MSP430_PATH/msp430.dat
}

pause