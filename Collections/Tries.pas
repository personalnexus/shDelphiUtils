unit Tries;

// Delphi version of my C# Trie implementation
// https://github.com/personalnexus/ShUtilities/blob/master/Collections/Trie.cs

interface

uses
  CollectionInterfaces,
  SysUtils;

type
  TTrieNode<T> = record
    Value: T;
    HasValue: Boolean;
  end;

  ///<summary>Experimental Trie implementation with support for a reduced set of
  /// possible key elements to minimize space requirements</summary>
  TTrie<TValue> = class(TObject)
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

    function GetNode(const AKey: AnsiString;
                     ACreateIfMissing: Boolean): Pointer;
    procedure Resize(ANewSize: Integer);
    procedure SetValue(const AKey: AnsiString;
                       const AValue: TValue;
                       ARaiseIfKeyExists: Boolean);

  public
    constructor Create(const APossibleCharacters: ISet<AnsiChar>;
                       AInitialCapacity: Integer;
                       ACapacityIncrement: Integer);

    procedure Add(const AKey: AnsiString; AValue: TValue);
    function ContainsKey(const AKey: AnsiString): Boolean;
    function Remove(const AKey: AnsiString): Boolean;
    function TryGetValue(const AKey: AnsiString; out AValue: TValue): Boolean;

    property Count: Integer read FCount;
  end;

  ///<summary>Combines an array for single character keys with a Trie for short
  /// keys and finally a Dictionary for long keys</summary>
  TTrieDictionary<TValue> = class(TObject)
  private
    FArray: array[AnsiChar] of TTrieNode<TValue>; // for single character keys
    FTrie: TTrie<TValue>;                         // for short keys
    FDictionary: TDictionary<AnsiString, TValue>; // for long keys

    FMaxKeyLengthForTrie: Integer;
    FCount:               Integer;
  public
    constructor Create(const APossibleCharacters: ISet<AnsiChar>;
                       AInitialCapacity: Integer;
                       ACapacityIncrement: Integer;
                       AMaxKeyLengthForTrie: Integer);

    procedure Add(const AKey: AnsiString; AValue: TValue);
    function ContainsKey(const AKey: AnsiString): Boolean;
    function Remove(const AKey: AnsiString): Boolean;
    function TryGetValue(const AKey: AnsiString; out AValue: TValue): Boolean;

    property Count: Integer read FCount;
  end;

implementation

// TTrie<TValue>

constructor TTrie<TValue>.Create(const APossibleCharacters: ISet<AnsiChar>;
                                 AInitialCapacity: Integer;
                                 ACapacityIncrement: Integer);
var
  index: Integer;
  character: AnsiChar;
  characterCode: Integer;
begin
  index := 0;
  for character in APossibleCharacters do begin
    characterCode := Ord(character);
    if (characterCode >= Length(FKeyIndexByCharacterCode)) then begin
      SetLength(FKeyIndexByCharacterCode, characterCode + 1);
    end;
    FKeyIndexByCharacterCode[characterCode] := index;
    Inc(index);
  end;
  FCapacityIncrement := ACapacityIncrement;
  FPossibleCharacterCount := APossibleCharacters.Count;
  Resize(AInitialCapacity);
end;

// TTrie<TValue> - Helper methods

function TTrie<TValue>.GetNode(const AKey: AnsiString; ACreateIfMissing: Boolean): Pointer;
var
  nodeIndex: Integer;
  character: AnsiChar;
  characterCode: Integer;
  indexIndex: Integer;
begin
  nodeIndex := 0;
  for character in AKey do begin
    characterCode := Ord(character);
    // Step 1: get the index of where in the indexes array the index into nodes is found
    indexIndex := (nodeIndex * FPossibleCharacterCount) + FKeyIndexByCharacterCode[characterCode];
    // Step 2: get the index of the node in FNodes
    nodeIndex := FNodeIndexes[indexIndex];
    if (nodeIndex = 0) then begin
      if (ACreateIfMissing) then begin
        Inc(FLastUsedNodeIndex);
        if (FLastUsedNodeIndex = Length(FNodes)) then begin
          Resize(Length(FNodes) + FCapacityIncrement);
        end;
        FNodeIndexes[indexIndex] := FLastUsedNodeIndex;
        nodeIndex := FLastUsedNodeIndex;
      end else begin
        Break;
      end;
    end;
  end;
  Result := @FNodes[nodeIndex];
end;

procedure TTrie<TValue>.Resize(ANewSize: Integer);
var
  oldSize: Integer;
begin
  oldSize := Length(FNodes);
  SetLength(FNodes, ANewSize);
  FillChar(FNodes[oldSize], ANewSize - oldSize, 0);

  ANewSize := ANewSize * FPossibleCharacterCount;
  oldSize := Length(FNodeIndexes);
  SetLength(FNodeIndexes, ANewSize);
  FillChar(FNodeIndexes[oldSize], ANewSize - oldSize, 0);
end;

procedure TTrie<TValue>.SetValue(const AKey: AnsiString;
                                 const AValue: TValue;
                                 ARaiseIfKeyExists: Boolean);
var
  node: Pointer;
begin
  node := GetNode(AKey, True);
  if (not TTrieNode<TValue>(node^).HasValue) then begin
    Inc(FCount);
  end else if (ARaiseIfKeyExists) then begin
    raise EArgumentException.CreateFmt('Key %s already exists', [AKey]);
  end;
  TTrieNode<TValue>(node^).Value := AValue;
  TTrieNode<TValue>(node^).HasValue := True;
end;

// TTrie<TValue> - Functionality

procedure TTrie<TValue>.Add(const AKey: AnsiString; AValue: TValue);
begin
  SetValue(Akey, AValue, True);
end;

function TTrie<TValue>.ContainsKey(const AKey: AnsiString): Boolean;
var
  node: Pointer;
begin
  node := GetNode(AKey, False);
  Result := TTrieNode<TValue>(node^).HasValue;
end;

function TTrie<TValue>.Remove(const AKey: AnsiString): Boolean;
var
  node: Pointer;
begin
  node := GetNode(AKey, False);
  Result := TTrieNode<TValue>(node^).HasValue;
  if (Result) then begin
    Dec(FCount);
    TTrieNode<TValue>(node^).HasValue := False;
  end;
end;

function TTrie<TValue>.TryGetValue(const AKey: AnsiString; out AValue: TValue): Boolean;
var
  node: Pointer;
begin
  node := GetNode(AKey, False);
  Result := TTrieNode<TValue>(node^).HasValue;
  if (Result) then begin
    AValue := TTrieNode<TValue>(node^).Value;
  end;
end;

// TTrieDictionary<TValue>

constructor TTrieDictionary<TValue>.Create(const APossibleCharacters: ISet<AnsiChar>;
                                           AInitialCapacity: Integer;
                                           ACapacityIncrement: Integer;
                                           AMaxKeyLengthForTrie: Integer);
begin
  inherited Create;
  FTrie := TTrie<TValue>.Create(APossibleCharacters,
                                Trunc(AInitialCapacity / 2),
                                ACapacityIncrement);
  FDictionary := TDictionary<AnsiString, TValue>.Create(AInitialCapacity / 2);
  FMaxKeyLengthForTrie := AMaxKeyLengthForTrie;
end;

procedure TTrieDictionary<TValue>.Add(const AKey: AnsiString; AValue: TValue);
var
  KeyLength: Integer;
begin
  KeyLength := Length(AKey);
  if (KeyLength = 1) then begin
    FArray[AKey[1]] := AValue;
  end else if (KeyLength <= FMaxKeyLengthForTrie) then begin
    FTrie.Add(AKey, AValue);
  end else begin
    FDictionary.Add(AKey, AValue);
  end;
end;

end.
