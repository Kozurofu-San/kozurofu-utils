param([string] $script='mcuContinue', [string] $server='localhost', [string] $platform, [int] $port=2000)

$mcuReset = {
	param([string] $server, [string] $port, [string] $gdb)
	Write-Host "Reset MCU"
	& $gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor reset" `
	-ex "set confirm off" `
	-ex "quit"
}

$mcuStop = {
	param([string] $server, [string] $port, [string] $gdb)
	Write-Host "Stop MCU"
	& $gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor halt" `
	-ex "set confirm off" `
	-ex "quit"
}

$mcuContinue = {
	param([string] $server, [string] $port, [string] $gdb)
	Write-Host "Continue MCU"
	& $gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor resume" `
	-ex "set confirm off" `
	-ex "quit"
}

function Get-File($initialDirectory) {   
	Add-Type -AssemblyName System.Windows.Forms
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    if ($initialDirectory) { $OpenFileDialog.initialDirectory = $initialDirectory }
    $OpenFileDialog.filter = 'Binaries|*.bin;*.elf'
    [void] $OpenFileDialog.ShowDialog()
    return $OpenFileDialog.FileName
}

$mcuLoad = {
	param([string] $server, [string] $port, [string] $gdb)
	# openocd -f interface\\stlink.cfg -f target\\stm32f7x.cfg -c "program C:/BL.bin verify reset exit  0x08000000"
	$path = Resolve-Path -Path "../build"

	$file = Get-File $path
	$file = $file.Replace('\','/')

	arm-none-eabi-objcopy --input-target=binary --output-target=elf32-little $file $path'data.elf'
	arm-none-eabi-gdb ${path}'data.elf' -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "set confirm off" `
	-ex "load ${path}data.elf 0x08000000" `
	-ex "monitor reset" `
	-ex "quit"
	Remove-Item ${path}'data.elf'
}

$mcuErase = {
	param([string] $server, [string] $port, [string] $gdb)
	# openocd -f interface\\stlink.cfg -f target\\stm32f7x.cfg -c "flash init; init; reset halt; flash erase_sector 0 0 0; exit"
	& $gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor flash erase_sector 0 0 last" `
	-ex "set confirm off" `
	-ex "quit" `
	program --arg --another
}

$gdb = ""
if     ($platform -like "*STM32*" -or $platform -like "*SAM*") { $gdb = "arm-none-eabi-gdb"    }
elseif ($platform -like "*ESP32*")                             { $gdb = "xtensa-esp32-elf-gdb" }
elseif ($platform -like "*MSP4340*")                           { $gdb = ""                     }
elseif ($platform -like "*PIC32*")                             { $gdb = ""                     }
elseif ($platform -like "*AVR*")                               { $gdb = ""                     }

if ($script -match 'mcuReset') 		{Invoke-Command -ScriptBlock $mcuReset 		-ArgumentList $server, $port, $gdb}
if ($script -match 'mcuContinue') 	{Invoke-Command -ScriptBlock $mcuContinue	-ArgumentList $server, $port, $gdb}
if ($script -match 'mcuStop') 		{Invoke-Command -ScriptBlock $mcuStop 		-ArgumentList $server, $port, $gdb}
if ($script -match 'mcuLoad') 		{Invoke-Command -ScriptBlock $mcuLoad 		-ArgumentList $server, $port, $gdb}
if ($script -match 'mcuErase') 		{Invoke-Command -ScriptBlock $mcuErase 		-ArgumentList $server, $port, $gdb}