param(
    [string] $cpu = "ATSAM3X",
    [string] $board = "arduino-due",
    [int] $log = 1,
    [string] $programmer = "jlink",
    [int] $port = 2000
)

$jlink_gdb = "${env:JLINK_PATH}/JLinkGDBServerCL.exe"
if (-not (Test-Path -Path $jlink_gdb -PathType Leaf) -and ($programmer -eq "jlink"))
{
    Write-Error "Jlink isn't installed. https://www.segger.com/downloads/jlink/"
    pause
    exit
}
$openocd = "${env:OCD_PATH}/bin/openocd.exe"
if (-not (Test-Path -Path $openocd -PathType Leaf) -and ($programmer -ne "jlink"))
{
    Write-Error "OpenOCD isn't installed"
    pause
    exit
}
Stop-Process -Name openocd -ErrorAction SilentlyContinue

$gdb         = ($port + 0).ToString()
$tcl_port    = ($port + 1).ToString()
$telnet_port = ($port + 2).ToString()

$swoFrequency, $cpuFrequency, $cfg = ./mcuGetSpeed.ps1 $cpu $board $log

if ($cpu -like "STM32*" -or $cpu -like "*SAM*")
{
    if ($programmer -eq "jlink")
    {
        & $jlink_gdb -device $cpu -if SWD -port $gdb -swoport $tcl_port -telnetport $telnet_port -speed 10000 -nolocalhostonly -nohalt
    }
    elseif ($programmer -eq "other")
    {
        & $openocd `
        -c "set CHIPNAME $cpu" `
        -c "set CONNECT_UNDER_RESET 1" `
        -f interface/stlink.cfg `
        -c "transport select swd" `
        -f target/$cfg `
        -c "gdb port $gdb" `
        -c "tcl port $tcl_port" `
        -c "telnet port $telnet_port" `
        -c "adapter speed 4000" `
        -c "bindto 0.0.0.0" `
        -c "itm ports on"
        # -c "tpiu config internal - uart off $cpu_frequency" `
        # -c "reset_config srst_only srst_nogate connect_assert_srst" `
    }
}
elseif ($cpu -like "*ESP32*")
{
    if     ( $cpu -like "*ESP32"   ) { $cfg = "esp32-bridge"    }
    elseif ( $cpu -like "*ESP32S3" ) { $cfg = "esp32s3-builtin" }
    elseif ( $cpu -like "*ESP32P4" ) { $cfg = "esp32p4-builtin" }
    if ($programmer -eq "jlink")
    {
        & $jlink_gdb -device $device -if SWD -port $gdb -swoport $tcl_port -telnetport $telnet_port -speed 1000 -nolocalhostonly -nohalt
    }
    elseif ($programmer -eq "other")
    {
        $ocd_path = "$HOME\.espressif\tools\openocd-esp32"
        $path = Get-ChildItem -Directory $ocd_path
        $ocd_path = "$ocd_path\$path"
        $path = Get-ChildItem -Directory $ocd_path
        $ocd_path = "$ocd_path\$path\bin"
        Set-Location $ocd_path
        .\openocd.exe `
            -f board/$cfg.cfg `
            -c "gdb port $gdb" `
            -c "tcl port $tcl_port" `
            -c "telnet port $telnet_port" `
            -c "bindto 0.0.0.0"
            # -c "set _RTOS none" `   # target/esp_common.cfg -> set _RTOS "none"/"hwthread"
    }
}
elseif ($cpu -like "*MSP430*")
{
    gdb_agent_console $env:MSP430_PATH/msp430.dat
}

pause