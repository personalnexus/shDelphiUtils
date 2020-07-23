unit KeyValueLists;

interface

uses
  Classes;

type
  TKeyValueListMerger = class(TObject)
    //TODO: WIP
  end;

  TStringKeyValuePair = record
    Key: AnsiString;
    Value: AnsiString;
  end;

  TBaseStringMap = class abstract(TObject)
  private
    FStrings: array of TStringKeyValuePair;

    function GetKey(Index: Integer): AnsiString; inline;
    function GetValue(Index: Integer): AnsiString; inline;

    function FindInternal(const Key: AnsiString; UsedCount: Integer; out FoundAtIndex: Integer): Boolean;

  public
    constructor Create; overload;
    destructor Destroy; override;

    procedure Clear; virtual; abstract;

    function TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
    function Find(const Key: AnsiString; out Index: Integer): Boolean; virtual; abstract;
    procedure Sort;

    property Keys[Index: Integer]: AnsiString read GetKey;
    property Values[Index: Integer]: AnsiString read GetValue;
  end;

  ///<summary>A never-shrinking key value list parsed efficiently from a text-representation of sorted key value pairs</summary>
  TGrowingStringMap = class(TBaseStringMap)
  private
    FCount: Integer;
    FCapacity: Integer;

    procedure Append(const Key, Value: AnsiString); inline;

  public
    constructor Create(Capacity: Integer); overload;

    procedure SetText(const Text: AnsiString);
    procedure SetSortedText(const Text: AnsiString);

    property Count: Integer read FCount;

  end;

  ///<summary>A string map that is optimzed for minimal memory footprint at the expense of more frequent memory reallocations</summary>
  TSlimStringMap = class(TBaseStringMap)
  private
    function GetCount: Integer;

  public
    procedure SetStrings(Source: TStrings);

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

constructor TBaseStringMap.Create;
begin
  inherited Create;
  SetLength(FStrings, 0);
end;

destructor TBaseStringMap.Destroy;
begin
  SetLength(FStrings, 0);
  inherited Destroy;
end;

function TBaseStringMap.GetKey(Index: Integer): AnsiString;
begin
   Result := FStrings[Index].Key;
end;

function TBaseStringMap.GetValue(Index: Integer): AnsiString;
begin
   Result := FStrings[Index].Value;
end;

function TBaseStringMap.TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := Find(Key, Index);
  if (Result) then begin
    Value := FStrings[Index].Value;
  end;
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
    Comparison := CompareStr(Key, FStrings[Index].Key);
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
  FStrings[FCount].Key := Key;
  FStrings[FCount].Value := Value;
  Inc(FCount);
end;

{ TSlimStringMap }

function TSlimStringMap.GetCount: Integer;
begin
  Result := Length(FStrings);
end;

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
  // start with the assumption that all strings from the source are valid key-value-pairs
  SourceCount := Source.Count;
  SetLength(FStrings, SourceCount);
  WrittenCount := 0;
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
      // Newer values overwrite old ones for the same key
      if (FindInternal(Key, WrittenCount, FoundAtIndex)) then begin
        FStrings[FoundAtIndex].Value := Value;
      end else begin
        if (FoundAtIndex < WrittenCount) then begin
          // decrement the ref-count for the strings at the end to be overwritten by Move
          FStrings[WrittenCount].Key := '';
          FStrings[WrittenCount].Value := '';
          Move(FStrings[FoundAtIndex], FStrings[FoundAtIndex+1], (WrittenCount-FoundAtIndex) * SizeOf(TStringKeyValuePair));
          // zero out the free slot so there isn't another reference to the strings moved up one position
          FillChar(FStrings[FoundAtIndex], SizeOf(TStringKeyValuePair), 0)
        end;
        FStrings[FoundAtIndex].Key := Key;
        FStrings[FoundAtIndex].Value := Value;
        Inc(WrittenCount);
      end;
    end;
  end;
  // Trim FStrings in the unlikely case there were empty lines
  if (WrittenCount <> SourceCount) then begin
    SetLength(FStrings, WrittenCount);
  end;
end;

end.