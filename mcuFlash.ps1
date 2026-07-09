param([string] $cpu = "ESP32", [string] $name, [string] $programmer, [string] $server='localhost', [int] $port=2000)

if ($cpu -like "ESP32*") {
    
    if (!(Test-Path -Path "$PSScriptRoot/../../build/$name.bin" -PathType Leaf) -or
        !(Test-Path -Path "$PSScriptRoot/../../build/$name.elf" -PathType Leaf))
    {
        Write-Host "Binary file doesn't exist" -ForegroundColor Red
        exit 1
    }
    
    $p = Get-Process -Name openocd -ErrorAction SilentlyContinue

    if ($null -eq $p)
    {
        Get-Process -Name "python" -ErrorAction SilentlyContinue | Stop-Process -Force
        $com = python $PSScriptRoot\find_com_port.py
        if ($com -eq "None")
        {
            Write-Error "Serial port isn't found. Check the device connection"
            exit
        }
        # & "${ENV:IDF_PATH}/export.ps1"
        # idf.py -p $com flash
        python.exe -m esptool `
            -p $com `
            -b 921600 `
            --before default-reset `
            --after hard-reset `
            write-flash `
            --skip-flashed `
            0x0000 build/bootloader/bootloader.bin `
            0x8000 build/partition_table/partition-table.bin `
            0x10000 build/$($name).bin
    }
    else
    {
        # $idf_exports = python "${ENV:IDF_PATH}/tools/activate.py" --export
        # . $idf_exports
        
        if ($cpu -match "ESP32" -or $cpu -match "ESP32S2" -or $cpu -match "ESP32S3")
        {
            $versionDir = Get-ChildItem "$HOME/.espressif/tools/xtensa-esp-elf-gdb" -Directory | Select-Object -First 1
            $gdbBin = Join-Path $versionDir.FullName "xtensa-esp-elf-gdb/bin"
            $env:PATH = "$gdbBin;$env:PATH"
        }
        else
        {
            $versionDir = Get-ChildItem -Path "$HOME/.espressif/tools/riscv32-esp-elf-gdb" -Directory | Select-Object -First 1
            $gdbBin = Join-Path $versionDir.FullName "riscv32-esp-elf-gdb/bin"
            $env:PATH = "$gdbBin;$env:PATH"
        
        }

        $folder = Get-Location
        $folder = $folder -replace '\\', '/'
        $gdb = "riscv32-esp-elf-gdb"
        if ($cpu -match "ESP32" -or $cpu -match "ESP32S2" -or $cpu -match "ESP32S3")
        {
            $gdb = "xtensa-$($cpu.ToLower())-elf-gdb"
        }
        & $gdb -batch `
        -ex "pwd" `
        -ex "target extended-remote ${server}:${port}" `
        -ex "set confirm off" `
        -ex "monitor reset halt" `
        -ex "mon program_esp $folder/build/bootloader/bootloader.bin 0x0000 verify skip_loaded" `
        -ex "mon program_esp $folder/build/partition_table/partition-table.bin 0x8000 verify skip_loaded" `
        -ex "mon program_esp $folder/build/${name}.bin 0x10000 verify skip_loaded" `
        -ex "monitor reset" `
        -ex "quit"
    }
}
elseif ($cpu -like "*SAM3*" -or $cpu -like "STM32*")
{
    $folder = Get-Location
    $folder = $folder -replace '\\', '/'
    arm-none-eabi-gdb -batch `
    -ex "pwd" `
    -ex "target extended-remote ${server}:2000" `
    -ex "set confirm off" `
    -ex "monitor reset halt" `
    -ex "load $folder/build/${name}.elf" `
    -ex "monitor reset" `
    -ex "quit"
}
elseif ($cpu -like "MSP430*")
{
    $folder = Get-Location
    $folder = $folder -replace '\\', '/'
    & "$env:MSP_PATH/msp430-elf-gdb.exe" -batch `
    -ex "pwd" `
    -ex "target extended-remote ${server}:55000" `
    -ex "set confirm off" `
    -ex "monitor reset halt" `
    -ex "load $folder/build/${name}.elf" `
    -ex "monitor reset" `
    -ex "quit"
}
elseif ($cpu -like "PIC10*" -or $cpu -like "PIC12*" -or $cpu -like "PIC16*" -or $cpu -like "PIC18*")
{
    Set-Location build
    if ($cpu -match "PIC32.*") {
        $mcuLine = $matches[0].Substring(3)
    }
    $out = & "$env:PIC_PATH\mplab_platform\mplab_ipe\ipecmd.exe" -TPPK3 -P"$mcuLine" -F"$name.hex" -Y
    if ($out.ToLower().Contains("Verify failed")) {
        & "$env:PIC_PATH\mplab_platform\mplab_ipe\ipecmd.exe" -TPPK3 -P"$mcuLine" -F"$name.hex" -M
    }
}
elseif ($cpu -like "PIC32*")
{
    if ($programmer -eq "jlink")
    {

    }
    else {
        Set-Location build
        if ($cpu -match "PIC32.*") {
            $mcuLine = $matches[0].Substring(3)
        }
        $out = & "$env:PIC_PATH\mplab_platform\mplab_ipe\ipecmd.exe" -TPPK3 -P"$mcuLine" -F"$name.hex" -Y
        Write-Output $out
        if ($out.Contains("Verify failed")) {
            & "$env:PIC_PATH\mplab_platform\mplab_ipe\ipecmd.exe" -TPPK3 -P"$mcuLine" -F"$name.hex" -M 
        }
    }
    
}