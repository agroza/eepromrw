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

type
  TOperation = (
    opInvalid,
    opRead,
    opWrite,
    opVerify,
    opErase
  );

  TParameterError = (
    erOperation,
    erAddress,
    erSize,
    erFile
  );
  TParameterErrors = set of TParameterError;

  TParameters = record
    Operation: TOperation;
    Protect: Boolean;
    Segment: Word;
    Offset: Word;
    Size: Word;
    FileName: String;
    Errors: TParameterErrors;
  end;

const
  { program stringtable }
  sEmpty                 = '';

  sProgramTitle          = '28C64B EEPROM Read/Write  VER: 0.2 REV: A';
  sProgramCopyright      = 'Copyright (C) 1998-2020 Microprogramming TECHNIQUES';
  sProgramAuthor         = 'Programming/PC Code: Alexandru Groza';
  sProgramRights         = 'All rights reserved.';

  sParameterMissing      = ' parameter missing.';

  sTypeHelp              = 'Type:' + #13#10 +
                           '  eepromrw.exe -help';
  sHelpUsage             = 'Usage is:' + #13#10 +
                           '  eepromrw.exe [-help] -read | -write | -verify | -erase [-protect]' + #13#10 +
                           '    -addr=SSSS:OOOO -size=BBBB [-file=filename.bin]' + #13#10;
  sHelpParameters1       = 'Where:' + #13#10 +
                           '  -help    shows this screen; all other parameters are ignored' + #13#10 +
                           '  -read    reads the ROM contents into specified filename';
  sHelpParameters2       = '  -write   writes the EEPROM with data from specified filename' + #13#10 +
                           '  -verify  verifies the ROM contents against data from specified filename' + #13#10 +
                           '  -erase   writes the EEPROM with zeroes';
  sHelpParameters3       = '  -protect if specified, enables EEPROM SDP after write or erase' + #13#10 +
                           '  -addr    specifies the hexadecimal (EEP)ROM address as SEGMENT:OFFSET' + #13#10 +
                           '  -size    specifies the hexadecimal (EEP)ROM size, in bytes';
  sHelpParameters4       = '  -file    specifies the path and filename of the binary ROM file' + #13#10 +
                           '           and is mandatory for read and write operations' + #13#10;

  sPressAnyKey           = 'Press any key to display usage examples...';

  sHelpExamples1         = 'Examples:' + #13#10 +
                           '  eepromrw.exe -read -addr=D000:0000 -size=2000 -file=ioifrom0.bin' + #13#10 +
                           '  eepromrw.exe -write -protect -addr=D000:0000 -size=4000 -file=rom.bin';
  sHelpExamples2         = '  eepromrw.exe -verify -addr=D000:0000 -size=2000 -file=verify.bin' + #13#10 +
                           '  eepromrw.exe -erase -addr=D000:0000 -size=2000';

  sSizeMismatch          = 'Input file size does not match the specified ROM size.';
  sCannotReadInputFile   = 'Cannot read input file ';
  sCannotWriteOutputFile = 'Cannot write output file ';
  sCannotWriteMemory     = 'Cannot write memory. Chip is not an EEPROM or is damaged.';
  sROMFileDifferent      = 'ROM contents is different than the input file.';
  sFirstDifferentByte    = 'First different byte is at address ';

  sProgress              = 'Progress: ';

  sStatisticsBytes       = ' bytes ';
  sStatisticsProtection  = 'Protection: ';

  sEnabledDisabled: array[Boolean] of String = (
    'Disabled',
    'Enabled'
  );

  sOperations: array[TOperation] of String = (
    sEmpty,
    'read',
    'written',
    'verified',
    'erased'
  );

  sParameterErrors: array[TParameterError] of String = (
    'Operation',
    'Address',
    'Size',
    'File'
  );

  { program commandline parameters }
  pHelp                  = '-help';
  pRead                  = '-read';
  pWrite                 = '-write';
  pVerify                = '-verify';
  pErase                 = '-erase';
  pProtect               = '-protect';
  pAddress               = '-addr=';
  pSize                  = '-size=';
  pFileName              = '-file=';

  { single character constants }
  cBackslash             = '\';
  cHexIdentifier         = '$';
  cPercent               = '%';
  cEqual                 = '=';
  cColon                 = ':';
  cSpace                 = ' ';

  { program general constants }
  kWriteRetries          = 6;
  kMinimumWriteCycleTime = 2;

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

@lowercase:
  lodsb
  cmp al,'A'
  jb @next
  cmp al,'Z'
  ja @next
  add al,20h

@next:
  stosb
  loop @lowercase

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

function IntToHex(const AInteger: Integer): String;
const
  kHexLength = 4;
  kHexDigits: array[0..15] of Char = '0123456789ABCDEF';

var
  I: Integer;
  LInteger: Integer;

begin
  LInteger := AInteger;

  IntToHex[0] := Char(kHexLength);

  for I := kHexLength downto 1 do
  begin
    IntToHex[I] := kHexDigits[LInteger and $F];
    LInteger := LInteger shr kHexLength;
  end;
end;

procedure WriteProgress(const AOffset, ASize: Word);
var
  LCurrentX: Byte;
  LProgress: String;

begin
  Str((Succ(AOffset) / ASize) * 100 : 4 : 2, LProgress);

  LCurrentX := WhereX;
  Write(LProgress, cPercent);
  GotoXY(LCurrentX, WhereY);
end;

function ReadEEPROM(const AParameters: TParameters): Boolean;
var
  I: Integer;
  LOutputFile: File of Byte;

begin
  ReadEEPROM := True;

  Assign(LOutputFile, AParameters.FileName);
{$I-}
  Rewrite(LOutputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotWriteOutputFile, AParameters.FileName);
    ReadEEPROM := False;

    Exit;
  end;

  Write(sProgress);

  for I := 0 to Pred(AParameters.Size) do
  begin
    Write(LOutputFile, Mem[AParameters.Segment : AParameters.Offset + I]);

    WriteProgress(I, AParameters.Size);
  end;

  Writeln;

  Close(LOutputFile);
end;

procedure DisableSDPWrites(const ASegment: Word);
begin
  Mem[ASegment : $1555] := $AA;     { this sequence is described }
  Mem[ASegment : $0AAA] := $55;     { in the ATMEL 28C64B datasheet }
  Mem[ASegment : $1555] := $A0;     { at page 8 (REV. 0270H-12/99) }

  Delay(kWriteRetries * kMinimumWriteCycleTime);
end;

procedure EnableSDPWrites(const ASegment: Word);
begin
  Mem[ASegment : $1555] := $AA;     { this sequence is described }
  Mem[ASegment : $0AAA] := $55;     { in the ATMEL 28C64B datasheet }
  Mem[ASegment : $1555] := $80;     { at page 8 (REV. 0270H-12/99) }
  Mem[ASegment : $1555] := $AA;
  Mem[ASegment : $0AAA] := $55;
  Mem[ASegment : $1555] := $20;

  Delay(kWriteRetries * kMinimumWriteCycleTime);
end;

function WriteMemoryByte(const ASegment, AOffset: Word; const AByte: Byte): Boolean;
var
  LRetries: Byte;

begin
  if Mem[ASegment : AOffset] <> AByte then
  begin
    Mem[ASegment : AOffset] := AByte;

    LRetries := kWriteRetries;

    while (Mem[ASegment : AOffset] <> AByte) and (LRetries <> 0)  do
    begin
      Delay(kMinimumWriteCycleTime);
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
    EnableSDPWrites(ASegment);

    if not WriteMemoryByte(ASegment, AOffset, AByte) then
    begin
      Writeln;
      Writeln;
      Write(sCannotWriteMemory);

      WriteEEPROMByte := False;
    end;
  end;
end;

function WriteVerifyEEPROM(const AParameters: TParameters): Boolean;
var
  I: Integer;
  LByte: Byte;
  LInputFile: File of Byte;

begin
  WriteVerifyEEPROM := True;

  Assign(LInputFile, AParameters.FileName);
{$I-}
  Reset(LInputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotReadInputFile, AParameters.FileName);
    WriteVerifyEEPROM := False;

    Exit;
  end;

  if AParameters.Size <> FileSize(LInputFile) then
  begin
    Writeln(sSizeMismatch);
    WriteVerifyEEPROM := False;

    Exit;
  end;

  Write(sProgress);

  for I := 0 to Pred(AParameters.Size) do
  begin
    Read(LInputFile, LByte);

    WriteProgress(I, AParameters.Size);

    case AParameters.Operation of
      opWrite, opErase:
        if not WriteEEPROMByte(AParameters.Segment, AParameters.Offset + I, LByte) then
        begin
          WriteVerifyEEPROM := False;

          Break;
        end;

      opVerify:
        if Mem[AParameters.Segment : AParameters.Offset + I] <> LByte then
        begin
          Writeln;
          Writeln;
          Writeln(sROMFileDifferent);
          Write(sFirstDifferentByte, IntToHex(AParameters.Segment), cColon, IntToHex(AParameters.Offset + 1));

          WriteVerifyEEPROM := False;

          Break;
        end;

    end;

  end;

  if (AParameters.Operation = opWrite) and AParameters.Protect then
  begin
    DisableSDPWrites(AParameters.Segment);
  end;

  Writeln;

  Close(LInputFile);
end;

function EraseEEPROM(const AParameters: TParameters): Boolean;
var
  I: Integer;

begin
  EraseEEPROM := True;

  Write(sProgress);

  for I := 0 to Pred(AParameters.Size) do
  begin
    WriteProgress(I, AParameters.Size);

    if not WriteEEPROMByte(AParameters.Segment, AParameters.Offset + I, $00) then
    begin
      EraseEEPROM := False;

      Break;
    end;
  end;

  if AParameters.Protect then
  begin
    DisableSDPWrites(AParameters.Segment);
  end;

  Writeln;
end;

procedure WriteProgramHeader;
begin
  Writeln;
  TextColor(White);
  Writeln(sProgramTitle);
  TextColor(LightGray);
  Writeln(sProgramCopyright);
  Writeln(sProgramAuthor);
  Writeln(sProgramRights);
  Writeln;
end;

procedure WriteHelp;
begin
  Writeln(sHelpUsage);
  Writeln(sHelpParameters1);
  Writeln(sHelpParameters2);
  Writeln(sHelpParameters3);
  Writeln(sHelpParameters4);

  Writeln(sPressAnyKey);
  Writeln;

  Readkey;

  Writeln(sHelpExamples1);
  Writeln(sHelpExamples2);
end;

procedure WriteParameterErrors(const AParameterErrors: TParameterErrors);
var
  LParameterError: TParameterError;

begin
  TextColor(Red);

  for LParameterError := Low(TParameterError) to High(TParameterError) do
  begin
    if LParameterError in AParameterErrors then
    begin
      Write(sParameterErrors[LParameterError]);
      Writeln(sParameterMissing);
    end;
  end;

  TextColor(LightGray);
  Writeln;
  Writeln(sTypeHelp);
end;

procedure WriteStatistics(const AParameters: TParameters);
begin
  Writeln;
  TextColor(White);
  Write(IntToHex(AParameters.Segment), cColon, IntToHex(AParameters.Offset), cSpace);
  TextColor(Yellow);
  Write(AParameters.Size);
  TextColor(LightGray);
  Writeln(sStatisticsBytes, sOperations[AParameters.Operation]);

  case AParameters.Operation of
    opWrite, opErase:
      Writeln(sStatisticsProtection, sEnabledDisabled[AParameters.Protect]);

  end;
end;

function FindSimpleParameter(const AParameter: String): Boolean;
var
  I: Integer;

begin
  FindSimpleParameter := False;

  for I := 1 to ParamCount do
  begin
    if LowerCase(ParamStr(I)) = AParameter then
    begin
      FindSimpleParameter := True;

      Break;
    end;
  end;
end;

function FindComplexParameter(const AParameter: String; var AValue: String): Boolean;
var
  I: Integer;

begin
  FindComplexParameter := False;

  for I := 1 to ParamCount do
  begin
    if Pos(AParameter, LowerCase(ParamStr(I))) <> 0 then
    begin
      AValue := ParamStr(I);

      FindComplexParameter := True;

      Break;
    end;
  end;
end;

procedure SetAllParameterErrors(var AParameterErrors: TParameterErrors);
var
  LParameterError: TParameterError;

begin
  for LParameterError := Low(TParameterError) to High(TParameterError) do
  begin
    Include(AParameterErrors, LParameterError);
  end;
end;

function ProcessParameters(var AParameters: TParameters): Boolean;
var
  LValue: String;

begin
  FillChar(AParameters, SizeOf(AParameters), $00);

  SetAllParameterErrors(AParameters.Errors);

  if ParamCount > 0 then
  begin
    if FindSimpleParameter(pRead) then
    begin
      AParameters.Operation := opRead;
    end else
    if FindSimpleParameter(pWrite) then
    begin
      AParameters.Operation := opWrite;
    end else
    if FindSimpleParameter(pVerify) then
    begin
      AParameters.Operation := opVerify;
    end else
    if FindSimpleParameter(pErase) then
    begin
      AParameters.Operation := opErase;
    end;

    if AParameters.Operation <> opInvalid then
    begin
      Exclude(AParameters.Errors, erOperation);
    end;

    case AParameters.Operation of
      opWrite, opErase:
        AParameters.Protect := FindSimpleParameter(pProtect);

    end;

    if FindComplexParameter(pAddress, LValue) then
    begin
      AParameters.Segment := StrToIntDef(cHexIdentifier + Copy(LValue, Succ(Pos(cEqual, LValue)), 4), 0);
      AParameters.Offset := StrToIntDef(cHexIdentifier + Copy(LValue, Succ(Pos(cColon, LValue)), 4), 0);

      Exclude(AParameters.Errors, erAddress);
    end;

    if FindComplexParameter(pSize, LValue) then
    begin
      Aparameters.Size := StrToIntDef(cHexIdentifier + Copy(LValue, Succ(Pos(cEqual, LValue)), 4), 0);

      Exclude(AParameters.Errors, erSize);
    end;

    if AParameters.Operation = opErase then
    begin
      Exclude(AParameters.Errors, erFile);
    end else
    begin
      if FindComplexParameter(pFileName, LValue) then
      begin
        Aparameters.FileName := LValue;
        Delete(AParameters.FileName, 1, Pos(cEqual, LValue));

        Exclude(AParameters.Errors, erFile);
      end;
    end;
  end;

  ProcessParameters := AParameters.Errors = [];
end;

var
  GSuccess: Boolean;
  GParameters: TParameters;

begin
  WriteProgramHeader;

  if (ParamCount > 0) and (ParamStr(1) = pHelp) then
  begin
    WriteHelp;
  end else
  begin
    if ProcessParameters(GParameters) then
    begin
      case GParameters.Operation of
        opRead:
          GSuccess := ReadEEPROM(GParameters);

        opWrite, opVerify:
          GSuccess := WriteVerifyEEPROM(GParameters);

        opErase:
          GSuccess := EraseEEPROM(GParameters);

      end;

      if GSuccess then
      begin
        WriteStatistics(GParameters);
      end;
    end else
    begin
      WriteParameterErrors(GParameters.Errors);
    end;
  end;
end.
