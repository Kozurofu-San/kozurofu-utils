param([string] $platform = "ESP32", [string] $name, [string] $server='localhost', [int] $port=2000)

if ($platform -like "*STM32*")
{
}
elseif ($platform -like "*ESP32*") {

    $p = Get-Process -Name openocd -ErrorAction SilentlyContinue
    if ($null -eq $p) {
        $dir = Get-Location
        $idf_path = ${ENV:IDF_PATH}
        $idf_path = $idf_path.replace('\', '/')
        Set-Location $idf_path
        ./export.ps1
        Set-Location $dir
        # idf.py -p COM3 flash
        python -m esptool `
            -p COM3 `
            -b 460800 `
            --before default_reset `
            --after hard_reset write_flash `
            0x0000 build/bootloader/bootloader.bin `
            0x8000 build/partition_table/partition-table.bin `
            0x10000 build/Template.bin
    } else {
        $idf_exports = python "${ENV:IDF_PATH}/tools/activate.py" --export
        . $idf_exports
        $folder = Get-Location
        $folder = $folder -replace '\\', '/'
        xtensa-esp32-elf-gdb -batch `
        -ex "pwd" `
        -ex "target extended-remote ${server}:${port}" `
        -ex "set confirm off" `
        -ex "monitor reset halt" `
        -ex "mon program_esp $folder/build/bootloader/bootloader.bin 0x0000 verify" `
        -ex "mon program_esp $folder/build/partition_table/partition-table.bin 0x8000 verify" `
        -ex "mon program_esp $folder/build/${name}.bin 0x10000 verify" `
        -ex "monitor reset" `
        -ex "quit"
    }
}
elseif ($platform -like "*SAM3*") {
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
elseif ($platform -like "*MSP430*") {
    $folder = Get-Location
    $folder = $folder -replace '\\', '/'
    msp430-elf-gdb -batch `
    -ex "pwd" `
    -ex "target extended-remote ${server}:55000" `
    -ex "set confirm off" `
    -ex "monitor reset halt" `
    -ex "load $folder/build/${name}.elf" `
    -ex "monitor reset" `
    -ex "quit"
}