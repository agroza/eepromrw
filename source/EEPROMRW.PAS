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
  sProgramTitle          = 'EEPROM Read/Write  VER: 0.1 REV: D';
  sProgramCopyright      = 'Copyright (C) 1998-2020 Microprogramming TECHNIQUES';
  sProgramAuthor         = 'Programming/PC Code: Alexandru Groza';
  sProgramRights         = 'All rights reserved.';

  sParameterErrors: array[TParameterError] of String = (
    'Operation',
    'Address',
    'Size',
    'File'
  );

  sParameterMissing      = ' parameter missing.';
  sTypeHelp              = 'Type:' + #13#10 +
                           '  eepromrw.exe -help';
  sHelpUsage             = 'Usage is:' + #13#10 +
                           '  eepromrw.exe [-help] -read | -write | -erase [-protect] -addr=SSSS:OOOO' + #13#10 +
                           '    size=BBBB [-file=filename.bin]' + #13#10;
  sHelpParameters1       = 'Where:' + #13#10 +
                           '  -help    shows this screen; all other parameters are ignored' + #13#10 +
                           '  -read    reads the ROM contents into specified filename' + #13#10 +
                           '  -write   writes the EEPROM with data from specified filename';
  sHelpParameters2       = '  -erase   writes the EEPROM with zeroes' + #13#10 +
                           '  -protect if specified, enables EEPROM SDP after write or erase' + #13#10 +
                           '  -addr    specifies the hexadecimal (EEP)ROM address as SEGMENT:OFFSET';
  sHelpParameters3       = '  -size    specifies the hexadecimal (EEP)ROM size, in bytes' + #13#10 +
                           '  -file    specifies the path and filename of the binary ROM file' + #13#10 +
                           '           and is mandatory for read and write operations' + #13#10;
  sHelpExamples          = 'Examples:' + #13#10 +
                           '  eepromrw.exe -read -addr=D000:0000 -size=2000 -file=ioifrom0.bin' + #13#10 +
                           '  eepromrw.exe -write -protect -addr=D000:0000 -size=4000 -file=rom.bin' + #13#10 +
                           '  eepromrw.exe -erase -addr=D000:0000 -size=2000';

  sSizeMismatch          = 'Input file size does not match the specified ROM size.';
  sCannotReadInputFile   = 'Cannot read input file ';
  sCannotWriteOutputFile = 'Cannot write output file ';
  sCannotWriteMemory     = 'Cannot write memory. Chip is not an EEPROM or is damaged.';

  sProgress              = 'Progress: ';

  sEmpty                 = '';

  pHelp                  = '-help';
  pRead                  = '-read';
  pWrite                 = '-write';
  pErase                 = '-erase';
  pProtect               = '-protect';
  pAddress               = '-addr=';
  pSize                  = '-size=';
  pFileName              = '-file=';

  cBackslash             = '\';
  cHexIdentifier         = '$';
  cPercent               = '%';
  cEqual                 = '=';
  cColon                 = ':';

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

procedure ReadEEPROM(const AParameters: TParameters);
var
  I: Integer;
  LOutputFile: File of Byte;

begin
  Assign(LOutputFile, AParameters.FileName);
{$I-}
  Rewrite(LOutputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotWriteOutputFile, AParameters.FileName);
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

procedure EnableSDPWrites(const ASegment: Word);
begin
  Mem[ASegment : $1555] := $AA;     { this sequence is described }
  Mem[ASegment : $0AAA] := $55;     { in the ATMEL 28C64B datasheet }
  Mem[ASegment : $1555] := $A0;     { at page 8 (REV. 0270H-12/99) }
end;

procedure DisableSDPWrites(const ASegment: Word);
begin
  Mem[ASegment : $1555] := $AA;     { this sequence is described }
  Mem[ASegment : $0AAA] := $55;     { in the ATMEL 28C64B datasheet }
  Mem[ASegment : $1555] := $80;     { at page 8 (REV. 0270H-12/99) }
  Mem[ASegment : $1555] := $AA;
  Mem[ASegment : $0AAA] := $55;
  Mem[ASegment : $1555] := $20;
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
      Writeln(sCannotWriteMemory);
      WriteEEPROMByte := False;
    end;
  end;
end;

procedure WriteEEPROM(const AParameters: TParameters);
var
  I: Integer;
  LByte: Byte;
  LOutputFile: File of Byte;

begin
  Assign(LOutputFile, AParameters.FileName);
{$I-}
  Reset(LOutputFile);
{$I+}
  if IOResult <> 0 then
  begin
    Writeln(sCannotReadInputFile, AParameters.FileName);
    Exit;
  end;

  if AParameters.Size <> FileSize(LOutputFile) then
  begin
    Writeln(sSizeMismatch);
    Exit;
  end;

  Write(sProgress);

  for I := 0 to Pred(AParameters.Size) do
  begin
    Read(LOutputFile, LByte);

    WriteProgress(I, AParameters.Size);

    if not WriteEEPROMByte(AParameters.Segment, AParameters.Offset + I, LByte) then
      Break;
  end;

  if AParameters.Protect then
  begin
    DisableSDPWrites(AParameters.Segment);
  end;

  Writeln;

  Close(LOutputFile);
end;

procedure EraseEEPROM(const AParameters: TParameters);
var
  I: Integer;

begin
  Write(sProgress);

  for I := 0 to Pred(AParameters.Size) do
  begin
    WriteProgress(I, AParameters.Size);

    if not WriteEEPROMByte(AParameters.Segment, AParameters.Offset + I, $00) then
      Break;
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
  Writeln(sHelpExamples);
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
  I: Integer;
  LParameter: String;

begin
  FillChar(AParameters, SizeOf(AParameters), $00);

  SetAllParameterErrors(AParameters.Errors);

  if ParamCount > 0 then
  begin
    for I := 1 to ParamCount do
    begin
      LParameter := LowerCase(ParamStr(I));

      if LParameter = pRead then
      begin
        AParameters.Operation := opRead;

        Break;
      end else
      if LParameter = pWrite then
      begin
        AParameters.Operation := opWrite;

        Break;
      end else
      if LParameter = pErase then
      begin
        AParameters.Operation := opErase;

        Break;
      end;
    end;

    if AParameters.Operation <> opInvalid then
    begin
      Exclude(AParameters.Errors, erOperation);
    end;

    case AParameters.Operation of
      opWrite, opErase:
        for I := 1 to ParamCount do
        begin
          if LowerCase(ParamStr(I)) = pProtect then
          begin
            AParameters.Protect := True;

            Break;
          end;
        end;

    end;

    for I := 1 to ParamCount do
    begin
      LParameter := LowerCase(ParamStr(I));

      if Pos(pAddress, LParameter) <> 0 then
      begin
        AParameters.Segment := StrToIntDef(cHexIdentifier + Copy(LParameter, Succ(Pos(cEqual, LParameter)), 4), 0);
        AParameters.Offset := StrToIntDef(cHexIdentifier + Copy(LParameter, Succ(Pos(cColon, LParameter)), 4), 0);

        Exclude(AParameters.Errors, erAddress);

        Break;
      end;
    end;

    for I := 1 to ParamCount do
    begin
      LParameter := LowerCase(ParamStr(I));

      if Pos(pSize, LParameter) <> 0 then
      begin
        Aparameters.Size := StrToIntDef(cHexIdentifier + Copy(LParameter, Succ(Pos(cEqual, LParameter)), 4), 0);

        Exclude(AParameters.Errors, erSize);

        Break;
      end;
    end;

    if AParameters.Operation = opErase then
    begin
      Exclude(AParameters.Errors, erFile);
    end else
    begin
      for I := 1 to ParamCount do
      begin
        LParameter := LowerCase(ParamStr(I));

        if Pos(pFileName, LParameter) <> 0 then
        begin
          Aparameters.FileName := LParameter;
          Delete(AParameters.FileName, 1, Pos(cEqual, LParameter));

          Exclude(AParameters.Errors, erFile);

          Break;
        end;
      end;
    end;
  end;

  ProcessParameters := AParameters.Errors = [];
end;

var
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
          ReadEEPROM(GParameters);

        opWrite:
          WriteEEPROM(GParameters);

        opErase:
          EraseEEPROM(GParameters);

      end;
    end else
    begin
      WriteParameterErrors(GParameters.Errors);
    end;
  end;
end.
