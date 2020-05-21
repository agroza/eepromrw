{ --------------------------------------------------------------------------- }
{ - EEPROM Read/Write (eepromrw.pas)                                        - }
{ - Copyright (C) 1998-2020 Alexandru Groza of Microprogramming TECHNIQUES  - }
{ - All rights reserved.                                                    - }
{ --------------------------------------------------------------------------- }
{ - License: GNU General Public License v3.0                                - }
{ --------------------------------------------------------------------------- }
program eepromrw;

uses
  Crt;

const
  { program stringtable }
  sProgramTitle          = 'EEPROM Read/Write  VER: 0.1 REV: B';
  sProgramCopyright      = 'Copyright (C) 1998-2020 Microprogramming TECHNIQUES';
  sProgramAuthor         = 'Programming/PC Code: Alexandru Groza';
  sProgramRights         = 'All rights reserved.';

  sParametersMissing     = 'Parameters missing.';
  sAddressInvalid        = 'Address parameter is invalid.';
  sSizeInvalid           = 'Size parameter is invalid.';
  sReadWriteInvalid      = 'Read, Write, or Erase parameter is invalid.';
  sUsageBasic            = 'Usage is:' + #13#10 +
                           '  eepromrw.exe -read|write|erase -address=SSSS:OOOO -size=BBBB <filename.bin>' + #13#10;
  sUsageExtra1           = 'Where:' + #13#10 +
                           '  -read reads the EEPROM into specified filename' + #13#10 +
                           '  -write writes the EEPROM from specified filename' + #13#10 +
                           '  -erase writes the EEPROM with zeroes';
  sUsageExtra2           = '  SSSS:OOOO represents hexadecimal address as SEGMENT:OFFSET' + #13#10 +
                           '  BBBB represents hexadecimal ROM size in bytes' + #13#10 +
                           '  <filename.bin> is mandatory for reads and writes' + #13#10;
  sUsageExample          = 'Examples:' + #13#10 +
                           '  eepromrw.exe -read  -address=D000:0000 -size=2000 ioifrom0.bin' + #13#10 +
                           '  eepromrw.exe -write -address=D000:0000 -size=4000 rom.bin' + #13#10 +
                           '  eepromrw.exe -erase -address=D000:0000 -size=2000';

  sSizeMismatch          = 'Input file size does not match the specified ROM size.';
  sCannotReadInputFile   = 'Cannot read input file ';
  sCannotWriteOutputFile = 'Cannot write output file ';
  sCannotWriteMemory     = 'Cannot write memory. Chip is not an EEPROM or is damaged.';
  sProgress              = 'Progress: ';

  pRead                  = '-read';
  pWrite                 = '-write';
  pErase                 = '-erase';
  pAddress               = '-address=';
  pSize                  = '-size=';

  cBackslash             = '\';
  cHexIdentifier         = '$';

function LowerCase(const AString: String): String; assembler;
asm
  push ds

  cld

  lds si,AString
  les di,@result
  lodsb
  stosb

  xor ah,ah
  xchg ax,cx
  jcxz @exit

@uppercase:
  lodsb
  cmp al,'A'
  jb @next
  cmp al,'Z'
  ja @next
  add al,20h

@next:
  stosb
  loop @uppercase

@exit:
  pop ds

end;

function ExtractFileName(const AString: String): String;
var
  I: Byte;

begin
  for I := Length(AString) downto 1 do
    if AString[I] = cBackslash then
      Break;

  if (I = 1) and (AString[I] <> cBackslash) then
  begin
    ExtractFileName := AString;
  end else
  begin
    ExtractFileName := Copy(AString, Succ(I), Succ(Length(AString) - I));
  end;
end;

function StrToIntDef(const AString: String; const ADefault: Longint): Longint;
var
  LValue: Longint;
  LErrorCode: Integer;

begin
  Val(AString, LValue, LErrorCode);
  if LErrorCode = 0 then
  begin
    StrToIntDef := LValue;
  end else
  begin
    StrToIntDef := ADefault;
  end;
end;

function ExtractSegmentOffset(const AParameter: String; var ASegment, AOffset: Word): Boolean;
begin
  ExtractSegmentOffset := Pos(pAddress, AParameter) <> 0;

  ASegment := StrToIntDef(cHexIdentifier + Copy(AParameter, Succ(Pos('=', AParameter)), 4), 0);
  AOffset := StrToIntDef(cHexIdentifier + Copy(AParameter, Succ(Pos(':', AParameter)), 4), 0);
end;

function ExtractSize(const AParameter: String; var ASize: Word): Boolean;
begin
  ExtractSize := Pos(pSize, AParameter) <> 0;

  ASize := StrToIntDef(cHexIdentifier + Copy(AParameter, Succ(Pos('=', AParameter)), 4), 0);
end;

procedure DisplayProgress(const AOffset, ASize: Word);
var
  LCurrentX: Byte;
  LProgress: String;

begin
  Str((Succ(AOffset) / ASize) * 100 : 4 : 2, LProgress);

  LCurrentX := WhereX;
  Write(LProgress, '%');
  GotoXY(LCurrentX, WhereY);
end;

procedure ReadEEPROM(const ASegment, AOffset, ASize: Word; const AFileName: String);
var
  I: Integer;
  LOutputFile: File of Byte;

begin
  Assign(LOutputFile, AFileName);
{$I-}
  Rewrite(LOutputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotWriteOutputFile, AFileName);
    Exit;
  end;

  Write(sProgress);

  for I := 0 to Pred(ASize) do
  begin
    Write(LOutputFile, Mem[ASegment : AOffset + I]);

    DisplayProgress(I, ASize);
  end;

  Writeln;

  Close(LOutputFile);
end;

procedure EnableSDPWrites(const ASegment, AOffset: Word);
begin
  Mem[ASegment : $1555] := $AA;     { this sequence is described }
  Mem[ASegment : $0AAA] := $55;     { in the ATMEL 28C64B datasheet }
  Mem[ASegment : $1555] := $A0;     { at page 8 (REV. 0270H-12/99) }
end;

function WriteMemoryByte(const ASegment, AOffset: Word; const AByte: Byte): Boolean;
var
  LRetries: Byte;

begin
  if Mem[ASegment : AOffset] <> AByte then
  begin
    Mem[ASegment : AOffset] := AByte;

    LRetries := 6;

    while (Mem[ASegment : AOffset] <> AByte) and (LRetries <> 0)  do
    begin
      Delay(2);
      Dec(LRetries);
    end;
  end;

  WriteMemoryByte := Mem[ASegment : AOffset] = AByte;
end;

function WriteEEPROMByte(const ASegment, AOffset: Word; const AByte: Byte): Boolean;
begin
  WriteEEPROMByte := True;

  if not WriteMemoryByte(ASegment, AOffset, AByte) then
  begin
    EnableSDPWrites(ASegment, AOffset);

    if not WriteMemoryByte(ASegment, AOffset, AByte) then
    begin
      Writeln;
      Writeln(sCannotWriteMemory);
      WriteEEPROMByte := False;
    end;
  end;
end;

procedure WriteEEPROM(const ASegment, AOffset, ASize: Word; const AFileName: String);
var
  I: Integer;
  LByte: Byte;
  LOutputFile: File of Byte;

begin
  Assign(LOutputFile, AFileName);
{$I-}
  Reset(LOutputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotReadInputFile, AFileName);
    Exit;
  end;

  if ASize <> FileSize(LOutputFile) then
  begin
    Writeln(sSizeMismatch);
    Exit;
  end;

  Write(sProgress);

  for I := 0 to Pred(ASize) do
  begin
    Read(LOutputFile, LByte);

    DisplayProgress(I, ASize);

    if not WriteEEPROMByte(ASegment, AOffset + I, LByte) then
      Break;
  end;

  Writeln;

  Close(LOutputFile);
end;

procedure EraseEEPROM(const ASegment, AOffset, ASize: Word);
var
  I: Integer;

begin
  Write(sProgress);

  for I := 0 to Pred(ASize) do
  begin
    DisplayProgress(I, ASize);

    if not WriteEEPROMByte(ASegment, AOffset + I, 0) then
      Break;
  end;

  Writeln;
end;

procedure WriteUsage;
begin
  Writeln;
  Writeln(sUsageBasic);
  Writeln(sUsageExtra1);
  Writeln(sUsageExtra2);
  Writeln(sUsageExample);
end;

var
  GSegment: Word;
  GOffset: Word;
  GSize: Word;

begin
  Writeln;
  Writeln(sProgramTitle);
  Writeln(sProgramCopyright);
  Writeln(sProgramAuthor);
  Writeln(sProgramRights);
  Writeln;

  if ParamCount >= 3 then
  begin
    if not ExtractSegmentOffset(LowerCase(ParamStr(2)), GSegment, GOffset) then
    begin
      Writeln(sAddressInvalid);
      WriteUsage;
      Exit;
    end;

    if not ExtractSize(LowerCase(ParamStr(3)), GSize) then
    begin
      Writeln(sSizeInvalid);
      WriteUsage;
      Exit;
    end;

    if LowerCase(ParamStr(1)) = pRead then
    begin
      ReadEEPROM(GSegment, GOffset, GSize, ParamStr(4));
    end else
    if LowerCase(ParamStr(1)) = pWrite then
    begin
      WriteEEPROM(GSegment, GOffset, GSize, ParamStr(4));
    end else
    if LowerCase(ParamStr(1)) = pErase then
    begin
      EraseEEPROM(GSegment, GOffset, GSize);
    end else
    begin
      Writeln(sReadWriteInvalid);
      WriteUsage;
    end;

    Writeln;
  end else
  begin
    Writeln(sParametersMissing);
    WriteUsage;
  end;
end.
