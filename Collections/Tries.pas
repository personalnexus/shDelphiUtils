unit Tries;

// Delphi version of my C# Trie implementation
// https://github.com/personalnexus/ShUtilities/blob/master/Collections/Trie.cs

interface

uses
  Generics.Collections,
  CollectionInterfaces,
  SysUtils;

type
  TTrieNodeSearch = (tnsNotFound, tnsFound, tnsInvalid);

  TTrieNode<T> = record
    Value: T;
    HasValue: Boolean;
  end;

  ///<summary>Experimental Trie implementation with support for a reduced set of
  /// possible key elements to minimize space requirements</summary>
  TTrie<TValue> = class(TInterfacedObject, IDictionary<AnsiString, TValue>)
  private
    // Key lookup
    FKeyIndexByCharacterCode: array[AnsiChar] of Integer;

    // Nodes
    FNodes: array of TTrieNode<TValue>;
    FNodeIndexes: array of Integer;
    FLastUsedNodeIndex: Integer;

    FPossibleKeyCharacterCount: Integer;
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
    constructor Create(const PossibleKeyCharacters: ISet<AnsiChar>;
                       InitialCapacity: Integer;
                       CapacityIncrement: Integer);

    procedure Add(const Key: AnsiString; const Value: TValue);
    function ContainsKey(const Key: AnsiString): Boolean;
    function Remove(const Key: AnsiString): Boolean;
    function TryGetValue(const Key: AnsiString; out Value: TValue): Boolean;

    function TryGetNodeIndexIncremental(Character: AnsiChar; var IndexIndex, NodeIndex: Integer): TTrieNodeSearch; inline;
    function TryGetValueByNodeIndex(NodeIndex: Integer; out Value: TValue): Boolean; inline;

    property Count: Integer read FCount;
  end;

  ///<summary>Experimental IDictionary implementation that combines an array for
  /// single character keys with a TTrie for short keys and finally a TDictionary
  /// for long keys</summary>
  TMultiLengthKeyTrie<TValue> = class(TInterfacedObject, IDictionary<AnsiString, TValue>)
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
    constructor Create(const PossibleKeyCharacters: ISet<AnsiChar>;
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

  ///<summary>Given a long key, returns a shortened key suitable for use in TShortenedKeyTrie</summary>
  TTrieKeyShortener = function(const LongKey: AnsiString): AnsiString;

  TShortenedKeyTrieBucket<TValue> = record
    LongKey: AnsiString;
    Value:   TValue;
  end;

  ///<summary>Experimental IDictionary implementation that given long keys uses
  /// a shortening function to produce short keys for use in a TTrie accepting
  /// the risk (assumed to be small) of key collisions.</summary>
  TShortenedKeyTrie<TValue> = class(TInterfacedObject, IDictionary<AnsiString, TValue>)
  private
    FBucketsByShortKey: TTrie<TList<TShortenedKeyTrieBucket<TValue>>>;
    FKeyShortener:      TTrieKeyShortener;

    function GetCount: Integer;

  public
    constructor Create(const PossibleKeyCharacters: ISet<AnsiChar>;
                       InitialCapacity: Integer;
                       CapacityIncrement: Integer;
                       KeyShortener: TTrieKeyShortener);
    destructor Destroy; override;

    procedure Add(const LongKey: AnsiString; const Value: TValue);
    function ContainsKey(const LongKey: AnsiString): Boolean;
    function Remove(const LongKey: AnsiString): Boolean;
    function TryGetValue(const LongKey: AnsiString; out Value: TValue): Boolean;

    property Count:        Integer           read GetCount;
    property OnShortenKey: TTrieKeyShortener read FKeyShortener write FKeyShortener; //TODO: nil check in setter
  end;

implementation

const
  INVALID_CHARACTER_INDEX = -1;

// TTrie<TValue>

constructor TTrie<TValue>.Create(const PossibleKeyCharacters: ISet<AnsiChar>;
                                 InitialCapacity: Integer;
                                 CapacityIncrement: Integer);
var
  Index: Integer;
  Character: AnsiChar;
begin
  FillChar(FKeyIndexByCharacterCode, 256, -1);
  Index := 0;
  for Character in PossibleKeyCharacters do begin
    FKeyIndexByCharacterCode[Character] := Index;
    Inc(Index);
  end;
  FCapacityIncrement := CapacityIncrement;
  FPossibleKeyCharacterCount := PossibleKeyCharacters.Count;
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
  NodeSearch: TTrieNodeSearch;
begin
  NodeIndex := 0;
  for Character in Key do begin
    NodeSearch := TryGetNodeIndexIncremental(Character, IndexIndex, NodeIndex);
    if (NodeSearch = tnsInvalid) then begin
      raise EArgumentOutOfRangeException.Create('Key contains characters unsupported by this TTrie');
    end else if (NodeSearch = tnsNotFound) then begin
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

function TTrie<TValue>.TryGetNodeIndexIncremental(Character: AnsiChar; var IndexIndex, NodeIndex: Integer): TTrieNodeSearch;
var
  KeyIndex: Integer;
begin
  KeyIndex := FKeyIndexByCharacterCode[Character];
  if (KeyIndex = INVALID_CHARACTER_INDEX) then begin
    Result := tnsInvalid;
  end else begin
    // Step 1: get the index of where in the indexes array the index into nodes is found
    IndexIndex := (NodeIndex * FPossibleKeyCharacterCount) + KeyIndex;
    // Step 2: get the index of the node in FNodes
    NodeIndex := FNodeIndexes[indexIndex];
    if (NodeIndex = 0) then begin
      Result := tnsNotFound;
    end else begin
      Result := tnsFound;
    end;
  end;
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

  NewSize := NewSize * FPossibleKeyCharacterCount;
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

// TMultiLengthKeyTrie<TValue>

constructor TMultiLengthKeyTrie<TValue>.Create(const PossibleKeyCharacters: ISet<AnsiChar>;
                                           InitialCapacity: Integer;
                                           CapacityIncrement: Integer;
                                           MaxKeyLengthForTrie: Integer);
begin
  inherited Create;
  FTrie := TTrie<TValue>.Create(PossibleKeyCharacters,
                                Trunc(InitialCapacity / 2),
                                CapacityIncrement);
  FDictionary := TDictionary<AnsiString, TValue>.Create(InitialCapacity div 2);
  FDictionary.OnKeyNotify := HandleKeyNotification;
  FMaxKeyLengthForTrie := MaxKeyLengthForTrie;
end;

destructor TMultiLengthKeyTrie<TValue>.Destroy;
begin
  FTrie := nil;
  FreeAndNil(FDictionary);
end;

// TMultiLengthKeyTrie<TValue> - Helper methods

procedure TMultiLengthKeyTrie<TValue>.HandleKeyNotification(Sender: TObject; const Key: AnsiString; Action: TCollectionNotification);
begin
  FKeyWasRemovedFromDictionary := Action = cnRemoved;
end;

function TMultiLengthKeyTrie<TValue>.GetCount: Integer;
begin
  Result := FCount;
end;

// TMultiLengthKeyTrie<TValue> - IDictionary

procedure TMultiLengthKeyTrie<TValue>.Add(const Key: AnsiString; const Value: TValue);
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

function TMultiLengthKeyTrie<TValue>.ContainsKey(const Key: AnsiString): Boolean;
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

function TMultiLengthKeyTrie<TValue>.Remove(const Key: AnsiString): Boolean;
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

function TMultiLengthKeyTrie<TValue>.TryGetValue(const Key: AnsiString; out ResultValue: TValue): Boolean;
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

// TShortenedKeyTrie<TValue>

constructor TShortenedKeyTrie<TValue>.Create(const PossibleKeyCharacters: ISet<AnsiChar>;
                                             InitialCapacity: Integer;
                                             CapacityIncrement: Integer;
                                             KeyShortener: TTrieKeyShortener);
begin
  inherited Create;
  FBucketsByShortKey := TTrie<TList<TShortenedKeyTrieBucket<TValue>>>.Create(PossibleKeyCharacters,
                                                                             InitialCapacity,
                                                                             CapacityIncrement);
  OnShortenKey := KeyShortener;
end;

destructor TShortenedKeyTrie<TValue>.Destroy;
var
  Index: Integer;
begin
  for Index := 0 to Length(FBucketsByShortKey.FNodes) - 1 do begin
    if ((FBucketsByShortKey.FNodes[Index].HasValue) and
        (FBucketsByShortKey.FNodes[Index].Value <> nil)) then begin
      FBucketsByShortKey.FNodes[Index].Value.Free;
    end;
  end;
  FreeAndNil(FBucketsByShortKey);

  inherited Destroy;
end;

function TShortenedKeyTrie<TValue>.GetCount: Integer;
begin
  Result := FBucketsByShortKey.Count;
end;

// TShortenedKeyTrie<TValue> - IDictionary

procedure TShortenedKeyTrie<TValue>.Add(const LongKey: AnsiString; const Value: TValue);
var
  ShortKey:   AnsiString;
  BucketList: TList<TShortenedKeyTrieBucket<TValue>>;
  Bucket:     TShortenedKeyTrieBucket<TValue>;
  Index:      Integer;
begin
  ShortKey := FKeyShortener(LongKey);
  if (not FBucketsByShortKey.TryGetValue(ShortKey, BucketList)) then begin
    BucketList := TList<TShortenedKeyTrieBucket<TValue>>.Create;
    BucketList.Capacity := 1;
    FBucketsByShortKey.Add(ShortKey, BucketList);
  end;
  //
  // We assume the risk of key collision is small, so the list is not sorted
  //
  for Index := 0 to BucketList.Count - 1 do begin
    if (BucketList[Index].LongKey = LongKey) then begin
      raise EArgumentException.CreateFmt('Key %s already exists', [LongKey]);
    end;
  end;
  Bucket.LongKey := LongKey;
  Bucket.Value   := Value;
  BucketList.Add(Bucket);
end;

function TShortenedKeyTrie<TValue>.Remove(const LongKey: AnsiString): Boolean;
var
  ShortKey:   AnsiString;
  BucketList: TList<TShortenedKeyTrieBucket<TValue>>;
  Bucket:     TShortenedKeyTrieBucket<TValue>;
  Index:      Integer;
begin
  Result   := False;
  ShortKey := FKeyShortener(LongKey);
  if (FBucketsByShortKey.TryGetValue(ShortKey, BucketList)) then begin
    if (BucketList.Count = 1) then begin
      //
      // The last value to be removed from the bucket list removes the list from
      // the trie
      //
      if (BucketList[0].LongKey = LongKey) then begin
        FBucketsByShortKey.Remove(ShortKey);
        BucketList.Free;
        Result := True;
      end;
    end else begin
      for Index := 0 to BucketList.Count - 1 do begin
        if (BucketList[Index].LongKey = LongKey) then begin
          BucketList.Delete(Index);
          Result := True;
          Break;
        end;
      end;
    end;
  end;
end;

function TShortenedKeyTrie<TValue>.ContainsKey(const LongKey: AnsiString): Boolean;
var
  _: TValue;
begin
  Result := TryGetValue(LongKey, _);
end;

function TShortenedKeyTrie<TValue>.TryGetValue(const LongKey: AnsiString; out Value: TValue): Boolean;
var
  ShortKey:   AnsiString;
  BucketList: TList<TShortenedKeyTrieBucket<TValue>>;
  Bucket:     TShortenedKeyTrieBucket<TValue>;
  Index:      Integer;
begin
  Result   := False;
  ShortKey := FKeyShortener(LongKey);
  if (FBucketsByShortKey.TryGetValue(ShortKey, BucketList)) then begin
    for Index := 0 to BucketList.Count - 1 do begin
      if (BucketList[Index].LongKey = LongKey) then begin
        Value  := BucketList[Index].Value;
        Result := True;
        Break;
      end;
    end;
  end;
end;


end.
