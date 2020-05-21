@echo off
echo ---------------------------------------------------------------------------
echo - EEPROM Read Test (romread.bat)                                          -
echo - Copyright (C) 1998-2020 Alexandru Groza of Microprogramming TECHNIQUES  -
echo - All rights reserved.                                                    -
echo ---------------------------------------------------------------------------
echo - License: GNU General Public License v3.0                                -
echo ---------------------------------------------------------------------------

eepromrw.exe -read -address=d000:0000 -size=2000 read.bin
