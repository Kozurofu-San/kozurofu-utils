param([string] $script='mcuContinue', [string] $server='localhost', [int] $port=2000)

$mcuReset = {
	param([string] $server, [string] $port)
	Write-Host "Reset MCU"
	arm-none-eabi-gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor reset" `
	-ex "set confirm off" `
	-ex "quit"
}

$mcuContinue = {
	param([string] $server, [string] $port)
	Write-Host "Continue MCU"
	arm-none-eabi-gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor resume" `
	-ex "set confirm off" `
	-ex "quit"
}

$mcuStop = {
	param([string] $server, [string] $port)
	Write-Host "Stop MCU"
	arm-none-eabi-gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor halt" `
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
	param([string] $server, [string] $port)
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
	param([string] $server, [string] $port)
	# openocd -f interface\\stlink.cfg -f target\\stm32f7x.cfg -c "flash init; init; reset halt; flash erase_sector 0 0 0; exit"
	arm-none-eabi-gdb -batch `
	-ex "target extended-remote ${server}:${port}" `
	-ex "monitor flash erase_sector 0 0 last" `
	-ex "set confirm off" `
	-ex "quit" `
	program --arg --another
}

if ($script -match 'mcuReset') 		{Invoke-Command -ScriptBlock $mcuReset 		-ArgumentList $server, $port}
if ($script -match 'mcuContinue') 	{Invoke-Command -ScriptBlock $mcuContinue	-ArgumentList $server, $port}
if ($script -match 'mcuStop') 		{Invoke-Command -ScriptBlock $mcuStop 		-ArgumentList $server, $port}
if ($script -match 'mcuLoad') 		{Invoke-Command -ScriptBlock $mcuLoad 		-ArgumentList $server, $port}
if ($script -match 'mcuErase') 		{Invoke-Command -ScriptBlock $mcuErase 		-ArgumentList $server, $port}