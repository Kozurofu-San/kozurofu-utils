param([string] $platform = "ESP32", [string] $server = 'localhost', [string] $port = 'COM3', [int] $baudrate = 115200)

if ($platform -like "*STM32*") {
    python ./swo_parser.py $server 2001
}
if ($platform -like "*ESP32*") {
    python ./serial_parser.py $port $baudrate
}