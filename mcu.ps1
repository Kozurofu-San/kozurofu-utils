param(
	[string] $script='mcuContinue',
	[string] $server='localhost',
	[string] $cpu,
	[int] $port=2000,
	[string] $programmer
)

$mcuReset = {
	param([string] $server, [string] $port, [string] $gdb, [string] $programmer)
	Write-Host "Reset MCU"
	if ($programmer -eq "jlink")
	{
		& $gdb -batch `
		-ex "target extended-remote ${server}:${port}" `
		-ex "monitor reset" `
		-ex "set confirm off" `
		-ex "quit"
	}
	else
	{
		& $gdb -batch `
		-ex "target extended-remote ${server}:${port}" `
		-ex "monitor reset" `
		-ex "monitor go" `
		-ex "set confirm off" `
		-ex "quit"
	}
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
	param([string] $server, [string] $port, [string] $gdb, [string] $programmer)
	Write-Host "Continue MCU"
	if ($programmer -eq "jlink")
	{
		& $gdb -batch `
		-ex "target extended-remote ${server}:${port}" `
		-ex "monitor go" `
		-ex "set confirm off" `
		-ex "quit"
	}
	else
	{
		& $gdb -batch `
		-ex "target extended-remote ${server}:${port}" `
		-ex "monitor resume" `
		-ex "set confirm off" `
		-ex "quit"
	}
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
	param([string] $server, [string] $port, [string] $gdb, [string] $programmer)
	# openocd -f interface\\stlink.cfg -f target\\stm32f7x.cfg -c "program C:/BL.bin verify reset exit  0x08000000"
	$path = "$PSScriptRoot/../../build/"
	$path = $path.Replace('\','/')

	$file = Get-File $path
	$file = $file.Replace('\','/')
	Write-Host $file $path

	if ($gdb -like "*arm*")
	{
		arm-none-eabi-objcopy --input-target=binary --output-target=elf32-little $file $path'data.elf'
		& $gdb ${path}'data.elf' -batch `
		-ex "target extended-remote ${server}:${port}" `
		-ex "set confirm off" `
		-ex "load ${path}data.elf 0x08000000" `
		-ex "monitor reset" `
		-ex "quit"
		Remove-Item ${path}'data.elf'
	}
	elseif ($gdb -like "*esp*")
	{
		if ($file -like "*bootloader.bin")
		{
			& $gdb -batch `
			-ex "pwd" `
			-ex "target extended-remote ${server}:${port}" `
			-ex "set confirm off" `
			-ex "monitor reset halt" `
			-ex "mon program_esp $file 0x0000 verify" `
			-ex "monitor reset" `
			-ex "quit"
		}
		elseif ($file -like "*partition-table.bin")
		{
			& $gdb -batch `
			-ex "pwd" `
			-ex "target extended-remote ${server}:${port}" `
			-ex "set confirm off" `
			-ex "monitor reset halt" `
			-ex "mon program_esp $file 0x8000 verify" `
			-ex "monitor reset" `
			-ex "quit"
		}
		else
		{
			& $gdb -batch `
			-ex "pwd" `
			-ex "target extended-remote ${server}:${port}" `
			-ex "set confirm off" `
			-ex "monitor reset halt" `
			-ex "mon program_esp $file 0x10000 verify" `
			-ex "monitor reset" `
			-ex "quit"
		}
		# & $gdb -batch `
        # -ex "pwd" `
        # -ex "target extended-remote ${server}:${port}" `
        # -ex "set confirm off" `
        # -ex "monitor reset halt" `
        # -ex "mon program_esp $folder/build/bootloader/bootloader.bin 0x0000 verify" `
        # -ex "mon program_esp $folder/build/partition_table/partition-table.bin 0x8000 verify" `
        # -ex "mon program_esp $file 0x10000 verify" `
        # -ex "monitor reset" `
        # -ex "quit"
	}
}

$mcuErase = {
	param([string] $server, [string] $port, [string] $gdb, [string] $programmer)
	# openocd -f interface\\stlink.cfg -f target\\stm32f7x.cfg -c "flash init; init; reset halt; flash erase_sector 0 0 0; exit"
	
	if ($cpu -like "PIC*")
	{
        if ($cpu -match "PIC32.*") {
            $mcuLine = $matches[0].Substring(3)
        }
		Set-Location ../../build
        & "$env:PIC_PATH\mplab_platform\mplab_ipe\ipecmd.exe" -TPPK3 -P"$mcuLine" -E
	}
	else
	{
		if ($programmer -eq "jlink")
		{
			& $gdb -batch `
			-ex "target extended-remote ${server}:${port}" `
			-ex "monitor flash erase 0x08000000" `
			-ex "monitor reset" `
			-ex "set confirm off" `
			-ex "quit" `
			program --arg --another
		}
		else
		{
			& $gdb -batch `
			-ex "target extended-remote ${server}:${port}" `
			-ex "monitor flash erase_sector 0 0 last" `
			-ex "set confirm off" `
			-ex "quit" `
			program --arg --another
		}
	}
}

$gdb = ""
if     ($cpu -like "*STM32*" -or $cpu -like "*SAM*") { $gdb = "arm-none-eabi-gdb"      }
elseif ($cpu -eq "ESP32"      )                           { $gdb = "xtensa-esp32-elf-gdb"   }
elseif ($cpu -eq "ESP32S2"    )                           { $gdb = "xtensa-esp32s2-elf-gdb" }
elseif ($cpu -eq "ESP32S3"    )                           { $gdb = "xtensa-esp32s3-elf-gdb" }
elseif ($cpu -like "*ESP32*"  )                           { $gdb = "riscv32-esp-elf-gdb"    }
elseif ($cpu -like "*MSP430*" )                           { $gdb = "msp430-elf-gdb"         }
elseif ($cpu -like "*PIC32*"  )                           { $gdb = ""                       }
elseif ($cpu -like "*AVR*"    )                           { $gdb = ""                       }

if ($script -match 'mcuReset') 		{Invoke-Command -ScriptBlock $mcuReset 		-ArgumentList $server, $port, $gdb, $programmer}
if ($script -match 'mcuContinue') 	{Invoke-Command -ScriptBlock $mcuContinue	-ArgumentList $server, $port, $gdb, $programmer}
if ($script -match 'mcuStop') 		{Invoke-Command -ScriptBlock $mcuStop 		-ArgumentList $server, $port, $gdb}
if ($script -match 'mcuLoad') 		{Invoke-Command -ScriptBlock $mcuLoad 		-ArgumentList $server, $port, $gdb, $programmer}
if ($script -match 'mcuErase') 		{Invoke-Command -ScriptBlock $mcuErase 		-ArgumentList $server, $port, $gdb, $programmer}
