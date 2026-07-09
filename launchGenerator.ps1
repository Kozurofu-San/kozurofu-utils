param(
    [string] $cpu = "ATSAM3X8E",
    [string] $board = "arduino-due",
    [int] $log = 1,
    [string] $programmer,
    [string] $workspace_path
)

Set-Location $PSScriptRoot

$allowed = @()
if (Test-Path -Path "$PSScriptRoot/../../submodules/lvgl" -PathType Container) {
    $allowed += @("lvgl")
}

$launch = Get-Content launch.template.json -Raw | ConvertFrom-Json
if ($cpu -like "STM32*" -or $cpu -like "*SAM*")
{
    $allowed += @("ARM", "Debug", "Debug continue")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
    $arm = $launch.configurations | Where-Object name -eq 'ARM'
    $swoFrequency, $cpuFrequency, $cfg = ./mcuGetSpeed.ps1 $cpu $board $log
    if ($log) {
        $arm.swoConfig.swoFrequency = $swoFrequency
        $arm.swoConfig.cpuFrequency = $cpuFrequency
        $arm.configFiles[1] = "target/$cfg"
    }
    else {
        $arm.PSObject.Properties.Remove("swoConfig")
    }

    if ($cpu -match "STM32....") {
        $mcuLine = $matches[0].ToLower()
    }
    elseif ($cpu -match "SAM...") {
        $mcuLine = $matches[0].ToLower()
    }
    $svd = (Get-ChildItem -Path "svd" -Filter "*$mcuLine*").Name;

    $arm.svdFile = "${workspaceRoot}/submodules/utils/svd/$svd"

    if ($programmer -eq "jlink") {
        $arm.servertype = "jlink"
        $arm.serverpath = "${env:JLINK_PATH}/JLinkGDBServerCL.exe"
        $arm.name = "J-LINK"
    }
    else {
        $arm.servertype = "openocd"
        $arm.serverpath = "${env:OCD_PATH}/openocd.exe"
        $arm.name = "ST-LINK"
    }
}
elseif ($cpu -like "ESP32*")
{
    $allowed += @("ESP32")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
    $gdb = "riscv32-esp-elf-gdb"
    if ($cpu -eq "ESP32" -or $cpu -eq "ESP32S2" -or $cpu -eq "ESP32S3")
    {
        $gdb = "xtensa-$($cpu.ToLower())-elf-gdb"
    }
    $esp = $launch.configurations | Where-Object name -eq 'ESP32'
    $esp.miDebuggerPath = $gdb
}
elseif ($cpu -like "MSP430*")
{
    $allowed += @("MSP430")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
}
elseif ($cpu -like "PIC32*")
{
    
    $allowed += @("Debug", "Debug continue")
    $launch.configurations = @(
        $launch.configurations | Where-Object {
            $_.name -in $allowed
        }
    )
}
else
{
    exit
}

$launch | ConvertTo-Json -Depth 100 | Set-Content ../../.vscode/launch.json