unit KeyValueScanner;

interface

uses
  AnsiStrings, Tries;

type
  TAnsiStrings = array of AnsiString;

  TStringValue = record
    Start: Integer;
    Length: Integer;
  end;

  PStringValue = ^TStringValue;

  ///<summary>Parses a set of known keys from the text representation of key value pairs</summary>
  TStringKeyValueScanner = class(TObject)
  private
    FValuePointersByKey: TTrie<PStringValue>;
    FValuesByIndex: array of TStringValue;
    FCount: Integer;
    FText: AnsiString;

    procedure SetValue(KeyNodeIndex, Start, Length: Integer; var ValueCount: Integer); inline;

  public
    constructor Create(Keys: TAnsiStrings);
    destructor Destroy; override;

    function SetText(const Text: AnsiString): Integer; overload;

    function ContainsKey(Index: Integer): Boolean;
    function GetValueDef(Index: Integer; const Default: AnsiString): AnsiString;
    function TryGetValue(Index: Integer; out Value: AnsiString): Boolean;
  end;


implementation

uses
  SysUtils, Sets, CollectionInterfaces, KeyValueLists;

{ TStringKeyValueScanner }

constructor TStringKeyValueScanner.Create(Keys: TAnsiStrings);
var
  KeyCharacter: AnsiChar;
  KeyCharacters: ISet<AnsiChar>;
  Index: Integer;
begin
  inherited Create;
  FCount := Length(Keys);
  SetLength(FValuesByIndex, FCount);

  // Create trie with the minimum set of characters needed for all keys
  KeyCharacters := TSet<AnsiChar>.Create;
  for Index := 0 to FCount - 1 do begin
    for KeyCharacter in Keys[Index] do begin
      KeyCharacters.Add(KeyCharacter);
    end;
  end;

  FValuePointersByKey := TTrie<PStringValue>.Create(KeyCharacters, FCount, 1);
  for Index := 0 to FCount - 1 do begin
    FValuePointersByKey.Add(Keys[Index], @FValuesByIndex[Index])
  end;
end;

destructor TStringKeyValueScanner.Destroy;
begin
  FreeAndNil(FValuePointersByKey);
  SetLength(FValuesByIndex, 0);
  inherited Destroy;
end;

function TStringKeyValueScanner.SetText(const Text: AnsiString): Integer;
var
  Character: AnsiChar;
  Index: Integer;
  Start: Integer;
  TextLength: Integer;
  PreviousKeyNodeIndex: Integer;
  KeyNodeIndex: Integer;
  KeyIndexIndex: Integer;
begin
  FText := Text;
  TextLength := Length(Text);
  // Result tracks the number of keys found (in case of duplicate keys, the first
  // value is retained and only counted once)
  Result := 0;
  FillChar(FValuesByIndex[0], FCount * SizeOf(TStringValue), 0);

  Index := 1;
  KeyNodeIndex := 0;

  while (Index <= TextLength) do begin
    Character := Text[Index];
    PreviousKeyNodeIndex := KeyNodeIndex;
    if (FValuePointersByKey.TryGetNodeIndexIncremental(Character, KeyIndexIndex, KeyNodeIndex)) then begin
      Inc(Index);
    end else if (Character = KeyValueSeparator ) then begin
      // Skip to end of key-value-pair
      Start := Index + 1;
      repeat
        Inc(Index);
      until (Index > TextLength) or (IsLineFeedOrCarriageReturn(Text[Index]));
      // Save value position unless we already had that key
      SetValue(PreviousKeyNodeIndex, Start, Index-Start, Result);
      // Ignore the rest when all keys have been found
      if (Result = FCount) then begin
        Break;
      end;
      // Skip to beginning of next key
      KeyNodeIndex := 0;
      repeat
        Inc(Index);
      until (Index > TextLength) or (not IsLineFeedOrCarriageReturn(Text[Index]));
    end else begin
      SetValue(KeyNodeIndex, Index, 0, Result);
      // Skip to end of key-value-pair
      repeat
        Inc(Index);
      until (Index > TextLength) or (IsLineFeedOrCarriageReturn(Text[Index]));
      // Skip to beginning of next key
      repeat
        Inc(Index);
      until (Index > TextLength) or (not IsLineFeedOrCarriageReturn(Text[Index]));
    end;
  end;
  // If the last key does not end with a key value separator, record an empty key
  SetValue(KeyNodeIndex, Index, 0, Result);
end;

procedure TStringKeyValueScanner.SetValue(KeyNodeIndex, Start, Length: Integer; var ValueCount: Integer);
var
  ValuePointer: PStringValue;
begin
  if (KeyNodeIndex <> 0) then begin
    // Save value position unless we already had that key
    if (FValuePointersByKey.TryGetValueByNodeIndex(KeyNodeIndex, ValuePointer) and
        (ValuePointer.Start = 0)) then begin
      Inc(ValueCount);
      ValuePointer.Start := Start;
      ValuePointer.Length := Length;
    end;
  end;
end;

function TStringKeyValueScanner.ContainsKey(Index: Integer): Boolean;
begin
  Result := FValuesByIndex[Index].Start <> 0;
end;

function TStringKeyValueScanner.GetValueDef(Index: Integer; const Default: AnsiString): AnsiString;
begin
  if (not TryGetValue(Index, Result)) then begin
    Result := Default;
  end;
end;

function TStringKeyValueScanner.TryGetValue(Index: Integer; out Value: AnsiString): Boolean;
var
  ValuePointer: PStringValue;
begin
  ValuePointer := @FValuesByIndex[Index];
  Result := ValuePointer.Start <> 0;
  if (Result) then begin
    Value := Copy(FText, ValuePointer.Start, ValuePointer.Length);
  end;
end;


end.
