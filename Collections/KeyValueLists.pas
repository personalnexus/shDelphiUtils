unit KeyValueLists;

interface

type
  TKeyValueListMerger = class(TObject)
    //TODO: WIP
  end;

  TStringKeyValuePair = record
    Key: AnsiString;
    Value: AnsiString;
  end;

  ///<summary>A never-shrinking key value list parsed efficiently from a text-representation of sorted key value pairs</summary>
  TStringKeyValueList = class abstract(TObject)
  private
    FStrings: array of TStringKeyValuePair;
    FCount: Integer;
    FCapacity: Integer;

    procedure Append(const Key, Value: AnsiString);
    function GetKey(Index: Integer): AnsiString; inline;
    function GetValue(Index: Integer): AnsiString; inline;

  public
    constructor Create; overload;
    constructor Create(Capacity: Integer); overload;

    procedure SetSortedText(const Text: AnsiString);

    property Count: Integer read FCount;
    property Keys[Index: Integer]: AnsiString read GetKey;
    property Values[Index: Integer]: AnsiString read GetValue;
  end;

  ///<summary>Based on TStringKeyValueList this class adds sorting and lookup of values by key</summary>
  TStringMap = class(TStringKeyValueList)
  public
    procedure SetText(const Text: AnsiString);
    function TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
    function Find(const Key: AnsiString; out Index: Integer): Boolean;
    procedure Sort;
  end;

const
  LineFeed          = AnsiChar(#10);
  CarriageReturn    = AnsiChar(#13);
  KeyValueSeparator = AnsiChar('=');

function IsLineFeedOrCarriageReturn(Character: AnsiChar): Boolean; inline;


implementation

uses
  SysUtils;

function IsLineFeedOrCarriageReturn(Character: AnsiChar): Boolean; inline;
begin
  Result := (Character = LineFeed) or (Character = CarriageReturn);
end;

{ TStringKeyValueList }

constructor TStringKeyValueList.Create;
begin
  inherited Create;
end;

constructor TStringKeyValueList.Create(Capacity: Integer);
begin
  Create;
  FCapacity := Capacity;
  SetLength(FStrings, FCapacity);
end;

procedure TStringKeyValueList.SetSortedText(const Text: AnsiString);
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

procedure TStringKeyValueList.Append(const Key, Value: AnsiString);
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

function TStringKeyValueList.GetKey(Index: Integer): AnsiString;
begin
   Result := FStrings[Index].Key;
end;

function TStringKeyValueList.GetValue(Index: Integer): AnsiString;
begin
   Result := FStrings[Index].Value;
end;

{ TStringMap }

procedure TStringMap.SetText(const Text: AnsiString);
begin
  SetSortedText(Text);
  Sort;
end;

function TStringMap.TryGetValue(const Key: AnsiString; out Value: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := Find(Key, Index);
  if (Result) then begin
    Value := FStrings[Index].Value;
  end;
end;

function TStringMap.Find(const Key: AnsiString; out Index: Integer): Boolean;
begin
  raise ENotImplemented.Create( 'TStringMap.Find not implemented' );
end;

procedure TStringMap.Sort;
begin
  raise ENotImplemented.Create( 'TStringMap.Sort not implemented' );
end;


end.