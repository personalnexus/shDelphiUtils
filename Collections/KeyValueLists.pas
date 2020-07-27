unit KeyValueLists;

interface

uses
  Classes,
  CollectionInterfaces;

type
  TStringKeyValuePair = record
    Key: AnsiString;
    Value: AnsiString;
  end;

  TBaseStringMap = class abstract(TInterfacedObject, IDictionary<AnsiString, AnsiString>)
  private
    FStrings: array of TStringKeyValuePair;

    // non range-checked methods for internal use
    function GetKeyByIndexInternal(Index: Integer): AnsiString; inline;
    function GetValueByIndexInternal(Index: Integer): AnsiString; inline;
    procedure SetKeyByIndexInternal(Index: Integer; const Key: AnsiString); inline;
    procedure SetValueByIndexInternal(Index: Integer; const Value: AnsiString); inline;


    function GetKeyByIndex(Index: Integer): AnsiString; inline;
    function GetValueByIndex(Index: Integer): AnsiString; inline;
    procedure SetValueByIndex(Index: Integer; const Value: AnsiString); inline;
    function GetKeyValuePairByIndex(Index: Integer): TStringKeyValuePair; inline;

    function FindInternal(const Key: AnsiString; UsedCount: Integer; out FoundAtIndex: Integer): Boolean;

  protected
    function GetCount: Integer; virtual; abstract;

  public
    destructor Destroy; override;

    procedure Add(const Key, Value: AnsiString); inline;
    function Remove(const Key: AnsiString): Boolean; inline;
    procedure Clear; virtual; abstract;

    function ContainsKey(const Key: AnsiString): Boolean;
    function GetValue(const Key: AnsiString): AnsiString;
    function GetValueDef(const Key, DefaultValue: AnsiString): AnsiString;
    function TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
    function Find(const Key: AnsiString; out Index: Integer): Boolean;
    procedure Sort;

    property Keys[Index: Integer]: AnsiString read GetKeyByIndex;
    property Values[Index: Integer]: AnsiString read GetValueByIndex write SetValueByIndex;
    property Items[Index: Integer]: TStringKeyValuePair read GetKeyValuePairByIndex;
  end;

  ///<summary>A never-shrinking key value list parsed efficiently from a text-representation of sorted key value pairs</summary>
  TGrowingStringMap = class(TBaseStringMap)
  private
    FCount: Integer;
    FCapacity: Integer;

    procedure Append(const Key, Value: AnsiString); inline;

  protected
    function GetCount: Integer; override;

  public
    constructor Create(Capacity: Integer); overload;

    procedure SetText(const Text: AnsiString);
    procedure SetSortedText(const Text: AnsiString);

    procedure Clear; override;

    property Count: Integer read FCount;
  end;

  ///<summary>A string map that is optimzed for minimal memory footprint at the expense of more frequent memory reallocations</summary>
  TSlimStringMap = class(TBaseStringMap)
  private
    procedure SetCapacity(NewCapacity: Integer); inline;

  protected
    function GetCount: Integer; override;

  public
    procedure SetStrings(Source: TStrings);

    procedure Clear; override;

    property Count: Integer read GetCount;
  end;

const
  LineFeed          = AnsiChar(#10);
  CarriageReturn    = AnsiChar(#13);
  KeyValueSeparator = AnsiChar('=');

function IsLineFeedOrCarriageReturn(Character: AnsiChar): Boolean; inline;


implementation

uses
  SysUtils, AnsiStrings;

function IsLineFeedOrCarriageReturn(Character: AnsiChar): Boolean; inline;
begin
  Result := (Character = LineFeed) or (Character = CarriageReturn);
end;

{ TBaseStringMap }

destructor TBaseStringMap.Destroy;
begin
  Finalize(FStrings);
  SetLength(FStrings, 0);
  inherited Destroy;
end;

function TBaseStringMap.GetKeyByIndexInternal(Index: Integer): AnsiString;
begin
  {$IFOPT R+}
    {$DEFINE RANGECHECK_WAS_ON}
    {$R-}
  {$ELSE}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
  Result := FStrings[Index].Key;
  {$IFDEF RANGECHECK_WAS_ON}
    {$R+}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
end;

function TBaseStringMap.GetValueByIndexInternal(Index: Integer): AnsiString;
begin
  {$IFOPT R+}
    {$DEFINE RANGECHECK_WAS_ON}
    {$R-}
  {$ELSE}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
  Result := FStrings[Index].Value;
  {$IFDEF RANGECHECK_WAS_ON}
    {$R+}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
end;

procedure TBaseStringMap.SetKeyByIndexInternal(Index: Integer; const Key: AnsiString);
begin
  {$IFOPT R+}
    {$DEFINE RANGECHECK_WAS_ON}
    {$R-}
  {$ELSE}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
  FStrings[Index].Key := Key;
  {$IFDEF RANGECHECK_WAS_ON}
    {$R+}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
end;

procedure TBaseStringMap.SetValueByIndexInternal(Index: Integer; const Value: AnsiString);
begin
  {$IFOPT R+}
    {$DEFINE RANGECHECK_WAS_ON}
    {$R-}
  {$ELSE}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
  FStrings[Index].Value := Value;
  {$IFDEF RANGECHECK_WAS_ON}
    {$R+}
    {$UNDEF RANGECHECK_WAS_ON}
  {$ENDIF}
end;

function TBaseStringMap.GetKeyByIndex(Index: Integer): AnsiString;
begin
  Result := FStrings[Index].Key;
end;

function TBaseStringMap.GetValueByIndex(Index: Integer): AnsiString;
begin
  Result := FStrings[Index].Value;
end;

procedure TBaseStringMap.SetValueByIndex(Index: Integer; const Value: AnsiString);
begin
  FStrings[Index].Value := Value;
end;

function TBaseStringMap.GetKeyValuePairByIndex(Index: Integer): TStringKeyValuePair;
begin
  Result := FStrings[Index];
end;

function TBaseStringMap.GetValue(const Key: AnsiString): AnsiString;
begin
  if (not TryGetValue(Key, Result)) then begin
    raise EArgumentException.CreateFmt('Key %s not found', [Key]);
  end;
end;

function TBaseStringMap.GetValueDef(const Key, DefaultValue: AnsiString): AnsiString;
begin
  if (not TryGetValue(Key, Result)) then begin
    Result := DefaultValue;
  end;
end;

function TBaseStringMap.TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := Find(Key, Index);
  if (Result) then begin
    Value := GetValueByIndexInternal(Index);
  end;
end;

function TBaseStringMap.ContainsKey(const Key: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := FindInternal(Key, GetCount, Index);
end;

function TBaseStringMap.Find(const Key: AnsiString; out Index: Integer): Boolean;
begin
  Result := FindInternal(Key, GetCount, Index);
end;

function TBaseStringMap.FindInternal(const Key: AnsiString; UsedCount: Integer; out FoundAtIndex: Integer): Boolean;
var
  Index: Integer;
  Comparison: Integer;
begin
  // TODO: implement better searching
  Result := False;
  FoundAtIndex := UsedCount;
  for Index := 0 to UsedCount - 1 do begin
    Comparison := CompareStr(Key, GetKeyByIndexInternal(Index));
    if (Comparison = 0) then begin
      Result := True;
      FoundAtIndex := Index;
      Break;
    end else if (Comparison < 0) then begin
      FoundAtIndex := Index;
      Break;
    end;
  end;
end;

procedure TBaseStringMap.Sort;
begin
  raise ENotImplemented.Create( 'TBaseStringMap.Sort not implemented' );
end;

procedure TBaseStringMap.Add(const Key, Value: AnsiString);
begin
  raise ENotSupportedException.Create( 'Use one of the Set methods on this class to add values' );
end;

function TBaseStringMap.Remove(const Key: AnsiString): Boolean;
begin
  raise ENotSupportedException.Create( 'Use one of the Set methods on this class to set new values thus removing old values' );
end;

{ TGrowingStringMap }

constructor TGrowingStringMap.Create(Capacity: Integer);
begin
  Create;
  FCapacity := Capacity;
  SetLength(FStrings, FCapacity);
end;

procedure TGrowingStringMap.SetText(const Text: AnsiString);
begin
  SetSortedText(Text);
  Sort;
end;

procedure TGrowingStringMap.SetSortedText(const Text: AnsiString);
var
  Index, Start, TextLength: Integer;
  IsKey: Boolean;
  Key: AnsiString;
begin
  // For performance reasons ignore any keys and values set beyond the end of
  // used range. Keys and values in the used range are always set together.
  FCount := 0;
  TextLength := Length(Text);
  Start := 1;
  Index := 1;
  IsKey := True;
  while (Index <= TextLength) do begin
    case Text[Index] of
       KeyValueSeparator: begin
          if (not IsKey) then begin
            // '=' in the middle of a value is skipped like any other character
            Inc(Index);
          end else begin
            // end of key reached
            Key := Copy(Text, Start, Index - Start);
            // Skip to start of value
            Inc(Index);
            Start := Index;
            IsKey := False;
          end;
       end;
       LineFeed, CarriageReturn: begin
         // end of value reached
         if (IsKey) then begin
           Append(Copy(Text, Start, Index - Start), '');
         end else begin
           Append(Key, Copy(Text, Start, Index - Start));
         end;
         Key := '';
         // Skip to end of key-value-pair
         while (Index <= TextLength) and IsLineFeedOrCarriageReturn(Text[Index]) do begin
           Inc(Index);
         end;
         Start := Index;
         IsKey := True;
       end
       else begin
         Inc(Index);
       end;
    end;
  end;
  // Is a key of value left over?
  if (Key <> '') or (Start <> Index) then begin
    if (IsKey) then begin
      Append(Copy(Text, Start, Index - Start), '');
    end else begin
      Append(Key, Copy(Text, Start, Index - Start));
    end;
  end;
end;

procedure TGrowingStringMap.Append(const Key, Value: AnsiString);
begin
  // The list only ever grows and never shrinks, so we can grow in moderate increments
  if (FCount = FCapacity) then begin
    FCapacity := FCount + 16;
    SetLength(FStrings, FCapacity);
  end;
  SetKeyByIndexInternal(FCount, Key);
  SetValueByIndexInternal(FCount, Value);
  Inc(FCount);
end;

function TGrowingStringMap.GetCount;
begin
  Result := FCount;
end;

procedure TGrowingStringMap.Clear;
begin
  FCount := 0;
end;

{ TSlimStringMap }

procedure TSlimStringMap.SetStrings(Source: TStrings);
var
  SourceCount: Integer;
  ReadIndex: Integer;
  WrittenCount: Integer;
  FoundAtIndex: Integer;
  SeparatorPosition: Integer;
  KeyAndValue: AnsiString;
  Key: AnsiString;
  Value: AnsiString;
begin
  WrittenCount := 0;
  // start with the assumption that all strings from the source are valid key-value-pairs
  SourceCount := Source.Count;
  SetCapacity(SourceCount);
  for ReadIndex := 0 to SourceCount - 1 do begin
    KeyAndValue := Source[ReadIndex];
    // Skip empty lines
    if (KeyAndValue <> '') then begin
      SeparatorPosition := AnsiStrings.AnsiPos(KeyValueSeparator, KeyAndValue);
      if (SeparatorPosition = 0) then begin
        Key   := KeyAndValue;
        Value := '';
      end else begin
        Key := Copy(KeyAndValue, 1, SeparatorPosition-1);
        Value := Copy(KeyAndValue, SeparatorPosition+1, MaxInt);;
      end;
      // Newer values do not overwrite old ones for the same key (mimicing the
      // behavior with dupIgnore from TStringList)
      if (not FindInternal(Key, WrittenCount, FoundAtIndex)) then begin
        if (FoundAtIndex < WrittenCount) then begin
          // decrement the ref-count for the strings at the end to be overwritten by Move
          Finalize(FStrings[WrittenCount]);
          Move(FStrings[FoundAtIndex], FStrings[FoundAtIndex+1], (WrittenCount-FoundAtIndex) * SizeOf(TStringKeyValuePair));
          // zero out the free slot so there isn't another reference to the strings moved up one position
          FillChar(FStrings[FoundAtIndex], SizeOf(TStringKeyValuePair), 0)
        end;
        SetKeyByIndexInternal(FoundAtIndex, Key);
        SetValueByIndexInternal(FoundAtIndex, Value);
        Inc(WrittenCount);
      end;
    end;
  end;
  // Trim FStrings in the unlikely case there were empty lines
  if (WrittenCount <> SourceCount) then begin
    SetCapacity(WrittenCount);
  end;
end;

procedure TSlimStringMap.SetCapacity(NewCapacity: Integer);
var
  CurrentCapacity: Integer;
begin
  CurrentCapacity := Length(FStrings);
  if (NewCapacity < CurrentCapacity) then begin
    Finalize(FStrings[NewCapacity], CurrentCapacity-NewCapacity);
  end;
  SetLength(FStrings, NewCapacity);
end;

function TSlimStringMap.GetCount: Integer;
begin
  Result := Length(FStrings);
end;

procedure TSlimStringMap.Clear;
begin
  Finalize(FStrings);
  SetLength(FStrings, 0);
end;


end.