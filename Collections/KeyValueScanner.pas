unit KeyValueScanner;

interface

uses
  CollectionInterfaces, Tries;

type
  TAnsiStringArray = array of AnsiString;

  TSubstringPosition = record
    Start: Integer;
    Length: Integer;
  end;

  PSubstringPosition = ^TSubstringPosition;

  ///<summary>Experimental parser for a set of known keys in the text representation of key value pairs</summary>
  TStringKeyValueScanner = class(TInterfacedObject, IDictionary<Integer, AnsiString>)
  private
    FValuePositionsByKey: TTrie<PSubstringPosition>;
    FValuePositionsByIndex: array of TSubstringPosition;
    FKeyCount: Integer;
    FValueCountInText: Integer;
    FText: AnsiString;

    procedure SetValue(KeyNodeIndex, Start, Length: Integer; var ValueCount: Integer); inline;

    // IDictionary
    function GetCount: Integer; inline;
    procedure Add(const Index: Integer; const Value: AnsiString);
    function Remove(const Index: Integer): Boolean;

  public
    ///<summary>Initializes the scanner with the given keys. Each key's index in
    /// the array is the index used to retrieve the value later</summary>
    constructor Create(Keys: TAnsiStringArray);
    destructor Destroy; override;

    function SetText(const Text: AnsiString): Integer;

    function ContainsKey(const Index: Integer): Boolean; inline;
    function TryGetValue(const Index: Integer; out Value: AnsiString): Boolean; inline;
    function GetValueDef(Index: Integer; const Default: AnsiString): AnsiString; inline;
  end;


implementation

uses
  SysUtils, Sets, KeyValueLists;

{ TStringKeyValueScanner }

constructor TStringKeyValueScanner.Create(Keys: TAnsiStringArray);
var
  KeyCharacter: AnsiChar;
  KeyCharacters: ISet<AnsiChar>;
  Index: Integer;
begin
  inherited Create;
  FKeyCount := Length(Keys);
  SetLength(FValuePositionsByIndex, FKeyCount);

  // Create trie with the minimum set of characters needed for all keys
  KeyCharacters := TSet<AnsiChar>.Create;
  for Index := 0 to FKeyCount - 1 do begin
    for KeyCharacter in Keys[Index] do begin
      KeyCharacters.Add(KeyCharacter);
    end;
  end;

  FValuePositionsByKey := TTrie<PSubstringPosition>.Create(KeyCharacters, FKeyCount, 1);
  for Index := 0 to FKeyCount - 1 do begin
    FValuePositionsByKey.Add(Keys[Index], @FValuePositionsByIndex[Index])
  end;
end;

destructor TStringKeyValueScanner.Destroy;
begin
  FreeAndNil(FValuePositionsByKey);
  SetLength(FValuePositionsByIndex, 0);
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
  _: Integer;
begin
  FText := Text;
  TextLength := Length(Text);
  // FValueCountInText tracks the number of keys found (in case of duplicate keys, the first
  // value is retained and only counted once)
  FValueCountInText := 0;
  FillChar(FValuePositionsByIndex[0], FKeyCount * SizeOf(TSubstringPosition), 0);

  Index := 1;
  KeyNodeIndex := 0;

  while (Index <= TextLength) do begin
    Character := Text[Index];
    PreviousKeyNodeIndex := KeyNodeIndex;
    if (FValuePositionsByKey.TryGetNodeIndexIncremental(Character, _, KeyNodeIndex) = tnsFound) then begin
      Inc(Index);
    end else if (Character = KeyValueSeparator ) then begin
      // Skip to end of key-value-pair
      Start := Index + 1;
      repeat
        Inc(Index);
      until (Index > TextLength) or (IsLineFeedOrCarriageReturn(Text[Index]));
      // Save value position unless we already had that key
      SetValue(PreviousKeyNodeIndex, Start, Index-Start, FValueCountInText);
      // Ignore the rest when all keys have been found
      if (FValueCountInText = FKeyCount) then begin
        Break;
      end;
      // Skip to beginning of next key
      KeyNodeIndex := 0;
      repeat
        Inc(Index);
      until (Index > TextLength) or (not IsLineFeedOrCarriageReturn(Text[Index]));
    end else begin
      SetValue(KeyNodeIndex, Index, 0, FValueCountInText);
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
  SetValue(KeyNodeIndex, Index, 0, FValueCountInText);
  Result := FValueCountInText;
end;

procedure TStringKeyValueScanner.SetValue(KeyNodeIndex, Start, Length: Integer; var ValueCount: Integer);
var
  ValuePosition: PSubstringPosition;
begin
  if (KeyNodeIndex <> 0) then begin
    // Save value position unless we already had that key
    if (FValuePositionsByKey.TryGetValueByNodeIndex(KeyNodeIndex, ValuePosition) and
        (ValuePosition.Start = 0)) then begin
      Inc(ValueCount);
      ValuePosition.Start := Start;
      ValuePosition.Length := Length;
    end;
  end;
end;

{ TStringKeyValueScanner - IDictionary }

function TStringKeyValueScanner.GetCount: Integer;
begin
  Result := FValueCountInText;
end;

procedure TStringKeyValueScanner.Add(const Index: Integer; const Value: AnsiString);
begin
  raise ENotSupportedException.Create( 'Only SetText can be used to modify TStringKeyValueScanner.' );
end;

function TStringKeyValueScanner.Remove(const Index: Integer): Boolean;
begin
  raise ENotSupportedException.Create( 'Only SetText can be used to modify TStringKeyValueScanner.' );
end;

function TStringKeyValueScanner.ContainsKey(const Index: Integer): Boolean;
begin
  Result := FValuePositionsByIndex[Index].Start <> 0;
end;

function TStringKeyValueScanner.GetValueDef(Index: Integer; const Default: AnsiString): AnsiString;
begin
  if (not TryGetValue(Index, Result)) then begin
    Result := Default;
  end;
end;

function TStringKeyValueScanner.TryGetValue(const Index: Integer; out Value: AnsiString): Boolean;
var
  ValuePosition: PSubstringPosition;
begin
  ValuePosition := @FValuePositionsByIndex[Index];
  Result := ValuePosition.Start <> 0;
  if (Result) then begin
    Value := Copy(FText, ValuePosition.Start, ValuePosition.Length);
  end;
end;


end.
