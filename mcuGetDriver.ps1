param( [string] $cpu )

if     ( $cpu -like "STM32*"   ) { $driver = $cpu.Substring(0, 7) }
elseif ( $cpu -like "*SAM*"    ) { $driver = "ATSAM"   }
elseif ( $cpu -like "PIC32*"   ) { $driver = "PIC32"   }
elseif ( $cpu -like "ESP32*"   ) { $driver = "ESP32"   }
elseif ( $cpu -like "MSP430*"  ) { $driver = "MSP430"  }
elseif ( $cpu -like "ATtiny*"  ) { $driver = "AVR"     }
elseif ( $cpu -like "ATmega*"  ) { $driver = "AVR"     }
elseif ( $cpu -like "ATxmega*" ) { $driver = "AVR"     }
else { return }

return $driver