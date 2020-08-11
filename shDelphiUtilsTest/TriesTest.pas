unit TriesTest;

interface

uses
  CollectionInterfaces,
  Sets,
  Tries,
  SysUtils;

procedure Run;


implementation

function GetLastFourCharacters(const Input: AnsiString): AnsiString;
var
  InputLength: Integer;
begin
  InputLength := Length(Input);
  if (InputLength > 4) then begin
    Result := Copy(Input, InputLength - 3, 4);
  end else begin
    Result := Input;
  end;
end;

procedure TestShortenedKeyTrie;
var
  PossibleKeyCharacters: ISet<AnsiChar>;
  Trie: IDictionary<AnsiString, Integer>;
  ActualValue: Integer;
begin
  PossibleKeyCharacters := TSet<AnsiChar>.Create(['A', 'B', 'C', 'D']);

  Trie := TShortenedKeyTrie<Integer>.Create(possibleKeyCharacters, 1, 1, GetLastFourCharacters);
  Trie.Add('1AAAA', 1);
  Trie.Add('2AAAA', 2);

  Assert(Trie.TryGetValue('1AAAA', ActualValue), '1AAAA not found in Trie');
  Assert(ActualValue = 1, 'Value for AAAA1 was ' + IntToStr(ActualValue));
  Assert(Trie.TryGetValue('2AAAA', ActualValue), '2AAAA not found in Trie');
  Assert(ActualValue = 2, 'Value for AAAA2 was ' + IntToStr(ActualValue));
  Assert(not Trie.TryGetValue('3AAAA', ActualValue), '3AAAA shoudld not have been found in Trie');

  Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed TestShortenedKeyTrie successfully');

end;


procedure Run;
begin
  TestShortenedKeyTrie;
end;

end.
