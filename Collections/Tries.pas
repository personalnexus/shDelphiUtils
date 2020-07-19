unit Tries;

// Delphi version of my C# Trie implementation
// https://github.com/personalnexus/ShUtilities/blob/master/Collections/Trie.cs

interface

uses
  Generics.Collections,
  CollectionInterfaces,
  SysUtils;

type
  TTrieNode<T> = record
    Value: T;
    HasValue: Boolean;
  end;

  ///<summary>Experimental Trie implementation with support for a reduced set of
  /// possible key elements to minimize space requirements</summary>
  TTrie<TValue> = class(TInterfacedObject, IDictionary<AnsiString, TValue>)
  private
    // Key lookup
    FKeyIndexByCharacterCode: array of Integer;

    // Nodes
    FNodes: array of TTrieNode<TValue>;
    FNodeIndexes: array of Integer;
    FLastUsedNodeIndex: Integer;

    FPossibleCharacterCount: Integer;
    FCapacityIncrement: Integer;

    FCount: Integer;

    function GetCount: Integer;
    function GetNode(const Key: AnsiString;
                     CreateIfMissing: Boolean): Pointer;
    procedure Resize(NewSize: Integer);
    procedure SetValue(const Key: AnsiString;
                       const Value: TValue;
                       RaiseIfKeyExists: Boolean);

  public
    constructor Create(const PossibleCharacters: ISet<AnsiChar>;
                       InitialCapacity: Integer;
                       CapacityIncrement: Integer);

    procedure Add(const Key: AnsiString; const Value: TValue);
    function ContainsKey(const Key: AnsiString): Boolean;
    function Remove(const Key: AnsiString): Boolean;
    function TryGetValue(const Key: AnsiString; out Value: TValue): Boolean;

    function TryGetNodeIndexIncremental(Character: AnsiChar; var IndexIndex, NodeIndex: Integer): Boolean; inline;
    function TryGetValueByNodeIndex(NodeIndex: Integer; out Value: TValue): Boolean; inline;

    property Count: Integer read FCount;
  end;

  ///<summary>Experimental IDictionary implementation that combines an array for
  /// single character keys with a TTrie for short keys and finally a TDictionary
  /// for long keys</summary>
  TTrieDictionary<TValue> = class(TInterfacedObject, IDictionary<AnsiString, TValue>)
  private
    FArray: array[AnsiChar] of TTrieNode<TValue>; // for single character keys
    FTrie: IDictionary<AnsiString, TValue>;       // for short keys
    FDictionary: TDictionary<AnsiString, TValue>; // for long keys

    FMaxKeyLengthForTrie: Integer;
    FCount: Integer;

    FKeyWasRemovedFromDictionary: Boolean;
    procedure HandleKeyNotification(Sender: TObject; const Key: AnsiString; Action: TCollectionNotification);

    function GetCount: Integer;

  public
    constructor Create(const PossibleCharacters: ISet<AnsiChar>;
                       InitialCapacity: Integer;
                       CapacityIncrement: Integer;
                       MaxKeyLengthForTrie: Integer);
    destructor Destroy; override;

    procedure Add(const Key: AnsiString; const Value: TValue);
    function ContainsKey(const Key: AnsiString): Boolean;
    function Remove(const Key: AnsiString): Boolean;
    function TryGetValue(const Key: AnsiString; out ResultValue: TValue): Boolean;

    property Count: Integer read FCount;
  end;

implementation

// TTrie<TValue>

constructor TTrie<TValue>.Create(const PossibleCharacters: ISet<AnsiChar>;
                                 InitialCapacity: Integer;
                                 CapacityIncrement: Integer);
var
  Index: Integer;
  Character: AnsiChar;
  CharacterCode: Integer;
begin
  Index := 0;
  for Character in PossibleCharacters do begin
    CharacterCode := Ord(Character);
    if (CharacterCode >= Length(FKeyIndexByCharacterCode)) then begin
      SetLength(FKeyIndexByCharacterCode, CharacterCode + 1);
    end;
    FKeyIndexByCharacterCode[CharacterCode] := Index;
    Inc(Index);
  end;
  FCapacityIncrement := CapacityIncrement;
  FPossibleCharacterCount := PossibleCharacters.Count;
  Resize(InitialCapacity);
end;

// TTrie<TValue> - Helper methods

function TTrie<TValue>.GetCount: Integer;
begin
  Result := FCount;
end;

function TTrie<TValue>.GetNode(const Key: AnsiString; CreateIfMissing: Boolean): Pointer;
var
  NodeIndex: Integer;
  Character: AnsiChar;
  IndexIndex: Integer;
begin
  NodeIndex := 0;
  for Character in Key do begin
    if (not TryGetNodeIndexIncremental(Character, IndexIndex, NodeIndex)) then begin
      if (CreateIfMissing) then begin
        Inc(FLastUsedNodeIndex);
        if (FLastUsedNodeIndex = Length(FNodes)) then begin
          Resize(Length(FNodes) + FCapacityIncrement);
        end;
        FNodeIndexes[indexIndex] := FLastUsedNodeIndex;
        NodeIndex := FLastUsedNodeIndex;
      end else begin
        Break;
      end;
    end;
  end;
  Result := @FNodes[nodeIndex];
end;

function TTrie<TValue>.TryGetNodeIndexIncremental(Character: AnsiChar; var IndexIndex, NodeIndex: Integer): Boolean;
var
  CharacterCode: Integer;
begin
  CharacterCode := Ord(Character);
  // Step 1: get the index of where in the indexes array the index into nodes is found
  IndexIndex := (NodeIndex * FPossibleCharacterCount) + FKeyIndexByCharacterCode[characterCode];
  // Step 2: get the index of the node in FNodes
  NodeIndex := FNodeIndexes[indexIndex];
  Result := NodeIndex <> 0;
end;

function TTrie<TValue>.TryGetValueByNodeIndex(NodeIndex: Integer; out Value: TValue): Boolean;
begin
  Result := FNodes[NodeIndex].HasValue;
  Value  := FNodes[NodeIndex].Value;
end;

procedure TTrie<TValue>.Resize(NewSize: Integer);
var
  OldSize: Integer;
begin
  OldSize := Length(FNodes);
  SetLength(FNodes, NewSize);
  FillChar(FNodes[oldSize], NewSize - oldSize, 0);

  NewSize := NewSize * FPossibleCharacterCount;
  OldSize := Length(FNodeIndexes);
  SetLength(FNodeIndexes, NewSize);
  FillChar(FNodeIndexes[oldSize], NewSize - OldSize, 0);
end;

procedure TTrie<TValue>.SetValue(const Key: AnsiString;
                                 const Value: TValue;
                                 RaiseIfKeyExists: Boolean);
var
  node: Pointer;
begin
  node := GetNode(Key, True);
  if (not TTrieNode<TValue>(node^).HasValue) then begin
    Inc(FCount);
  end else if (RaiseIfKeyExists) then begin
    raise EArgumentException.CreateFmt('Key %s already exists', [Key]);
  end;
  TTrieNode<TValue>(node^).Value := Value;
  TTrieNode<TValue>(node^).HasValue := True;
end;

// TTrie<TValue> - IDictionary

procedure TTrie<TValue>.Add(const Key: AnsiString; const Value: TValue);
begin
  SetValue(Key, Value, True);
end;

function TTrie<TValue>.ContainsKey(const Key: AnsiString): Boolean;
var
  Node: Pointer;
begin
  Node := GetNode(Key, False);
  Result := TTrieNode<TValue>(node^).HasValue;
end;

function TTrie<TValue>.Remove(const Key: AnsiString): Boolean;
var
  Node: Pointer;
begin
  Node := GetNode(Key, False);
  Result := TTrieNode<TValue>(node^).HasValue;
  if (Result) then begin
    Dec(FCount);
    TTrieNode<TValue>(node^).HasValue := False;
  end;
end;

function TTrie<TValue>.TryGetValue(const Key: AnsiString; out Value: TValue): Boolean;
var
  Node: Pointer;
begin
  node := GetNode(Key, False);
  Result := TTrieNode<TValue>(node^).HasValue;
  if (Result) then begin
    Value := TTrieNode<TValue>(node^).Value;
  end;
end;

// TTrieDictionary<TValue>

constructor TTrieDictionary<TValue>.Create(const PossibleCharacters: ISet<AnsiChar>;
                                           InitialCapacity: Integer;
                                           CapacityIncrement: Integer;
                                           MaxKeyLengthForTrie: Integer);
begin
  inherited Create;
  FTrie := TTrie<TValue>.Create(PossibleCharacters,
                                Trunc(InitialCapacity / 2),
                                CapacityIncrement);
  FDictionary := TDictionary<AnsiString, TValue>.Create(InitialCapacity div 2);
  FDictionary.OnKeyNotify := HandleKeyNotification;
  FMaxKeyLengthForTrie := MaxKeyLengthForTrie;
end;

destructor TTrieDictionary<TValue>.Destroy;
begin
  FTrie := nil;
  FreeAndNil(FDictionary);
end;

// TTrieDictionary<TValue> - Helper methods

procedure TTrieDictionary<TValue>.HandleKeyNotification(Sender: TObject; const Key: AnsiString; Action: TCollectionNotification);
begin
  FKeyWasRemovedFromDictionary := Action = cnRemoved;
end;

function TTrieDictionary<TValue>.GetCount: Integer;
begin
  Result := FCount;
end;

// TTrieDictionary<TValue> - IDictionary

procedure TTrieDictionary<TValue>.Add(const Key: AnsiString; const Value: TValue);
var
  KeyLength: Integer;
begin
  KeyLength := Length(Key);
  if (KeyLength = 1) then begin
    with FArray[Key[1]] do begin
      Value := Value;
      if (HasValue) then begin
        raise EArgumentException.CreateFmt('Key %s already exists', [Key]);
      end;
      HasValue := True;
    end;
  end else if (KeyLength <= FMaxKeyLengthForTrie) then begin
    FTrie.Add(Key, Value);
  end else begin
    FDictionary.Add(Key, Value);
  end;
  Inc(FCount);
end;

function TTrieDictionary<TValue>.ContainsKey(const Key: AnsiString): Boolean;
var
  KeyLength: Integer;
begin
  KeyLength := Length(Key);
  if (KeyLength = 1) then begin
    Result := FArray[Key[1]].HasValue;
  end else if (KeyLength <= FMaxKeyLengthForTrie) then begin
    Result := FTrie.ContainsKey(Key);
  end else begin
    Result := FDictionary.ContainsKey(Key);
  end;
end;

function TTrieDictionary<TValue>.Remove(const Key: AnsiString): Boolean;
var
  KeyLength: Integer;
begin
  KeyLength := Length(Key);
  if (KeyLength = 1) then begin
    with FArray[Key[1]] do begin
      Result := HasValue;
      HasValue := False;
    end;
  end else if (KeyLength <= FMaxKeyLengthForTrie) then begin
    Result := FTrie.Remove(Key);
  end else begin
    FKeyWasRemovedFromDictionary := False;
    FDictionary.Remove(Key);
    Result := FKeyWasRemovedFromDictionary;
  end;
  if (Result) then begin
    Dec(FCount);
  end;
end;

function TTrieDictionary<TValue>.TryGetValue(const Key: AnsiString; out ResultValue: TValue): Boolean;
var
  KeyLength: Integer;
begin
  KeyLength := Length(Key);
  if (KeyLength = 1) then begin
    with FArray[Key[1]] do begin
      Result := HasValue;
      ResultValue := Value;
    end;
  end else if (KeyLength <= FMaxKeyLengthForTrie) then begin
    Result := FTrie.TryGetValue(Key, ResultValue);
  end else begin
    Result := FDictionary.TryGetValue(Key, ResultValue);
  end;
end;


end.
