# eepromrw
EEPROM Read/Write

This program reads, writes, or erases an EEPROM located at a given address.\
I have written it to easily program and read back OPTION ROMs.

```
Usage is:
  eepromrw.exe -read|write|erase -address=SSSS:OOOO -size=BBBB <filename.bin>

Where:
  -read reads the EEPROM into specified filename
  -write writes the EEPROM from specified filename
  -erase writes the EEPROM with zeroes
  SSSS:OOOO represents hexadecimal address as SEGMENT:OFFSET
  BBBB represents hexadecimal ROM size in bytes
  <filename.bin> is mandatory for reads and writes

Examples:
  eepromrw.exe -read  -address=D000:0000 -size=2000 ioifrom0.bin
  eepromrw.exe -write -address=D000:0000 -size=4000 rom.bin
  eepromrw.exe -erase -address=D000:0000 -size=2000
```
