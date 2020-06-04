# eepromrw
EEPROM Read/Write

This program reads, writes, or erases an EEPROM located at a given address.\
I have written it to easily program and read back OPTION ROMs.

```
Usage is:
  eepromrw.exe [-help] -read | -write | -erase [-protect] -addr=SSSS:OOOO
    size=BBBB [-file=filename.bin]

Where:
  -help    shows this screen; all other parameters are ignored
  -read    reads the ROM contents into specified filename
  -write   writes the EEPROM with data from specified filename
  -erase   writes the EEPROM with zeroes
  -protect if specified, enables EEPROM SDP after write or erase
  -addr    specifies the hexadecimal EEPROM address as SEGMENT:OFFSET
  -size    specifies the hexadecimal (EEP)ROM size, in bytes
  -file    specifies the path and filename of the binary ROM file
           and is mandatory for read and write operations

Examples:
  eepromrw.exe -read -addr=D000:0000 -size=2000 -file=ioifrom0.bin
  eepromrw.exe -write -protect -addr=D000:0000 -size=4000 -file=rom.bin
  eepromrw.exe -erase -addr=D000:0000 -size=2000
```
