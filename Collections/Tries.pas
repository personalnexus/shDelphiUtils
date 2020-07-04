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

    procedure Add(const Key: AnsiString; Value: TValue);
    function ContainsKey(const Key: AnsiString): Boolean;
    function Remove(const Key: AnsiString): Boolean;
    function TryGetValue(const Key: AnsiString; out Value: TValue): Boolean;

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
    constructor Create(const PossibleCharacters: ISet<AnsiChar>;
                       InitialCapacity: Integer;
                       CapacityIncrement: Integer;
                       MaxKeyLengthForTrie: Integer);
    //TODO: destructor Destroy; override;

    procedure Add(const Key: AnsiString; Value: TValue);
    //TODO: function ContainsKey(const Key: AnsiString): Boolean;
    //TODO: function Remove(const Key: AnsiString): Boolean;
    //TODO: function TryGetValue(const Key: AnsiString; out Value: TValue): Boolean;

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

function TTrie<TValue>.GetNode(const Key: AnsiString; CreateIfMissing: Boolean): Pointer;
var
  NodeIndex: Integer;
  Character: AnsiChar;
  CharacterCode: Integer;
  IndexIndex: Integer;
begin
  nodeIndex := 0;
  for Character in Key do begin
    characterCode := Ord(character);
    // Step 1: get the index of where in the indexes array the index into nodes is found
    indexIndex := (nodeIndex * FPossibleCharacterCount) + FKeyIndexByCharacterCode[characterCode];
    // Step 2: get the index of the node in FNodes
    nodeIndex := FNodeIndexes[indexIndex];
    if (nodeIndex = 0) then begin
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

// TTrie<TValue> - Functionality

procedure TTrie<TValue>.Add(const Key: AnsiString; Value: TValue);
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
  node: Pointer;
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
  FMaxKeyLengthForTrie := MaxKeyLengthForTrie;
end;

procedure TTrieDictionary<TValue>.Add(const Key: AnsiString; Value: TValue);
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
end;


end.
