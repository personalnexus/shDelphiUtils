unit KeyValueListsTest;

interface

procedure Run;

implementation

uses
  KeyValueLists,
  SysUtils;

procedure TestStringKeyValueList;
var
  KeyValueList: TStringKeyValueList;
begin
  KeyValueList := TStringKeyValueList.Create;
  try
    KeyValueList.SetSortedText('Key1=Value1'#13'Key2='#10'Key3'#13#10'Key4=Value4'#10#13#10'Key5'#13#10'=Value6=6'#10#10'Key7');
    Assert(KeyValueList.Count = 7, 'map.Count=' + IntToStr(KeyValueList.Count));
    Assert(KeyValueList.Keys[0] = 'Key1', 'Keys[0]=' + string(KeyValueList.Keys[0]));
    Assert(KeyValueList.Keys[1] = 'Key2', 'Keys[1]=' + string(KeyValueList.Keys[1]));
    Assert(KeyValueList.Keys[2] = 'Key3', 'Keys[2]=' + string(KeyValueList.Keys[2]));
    Assert(KeyValueList.Keys[3] = 'Key4', 'Keys[3]=' + string(KeyValueList.Keys[3]));
    Assert(KeyValueList.Keys[4] = 'Key5', 'Keys[4]=' + string(KeyValueList.Keys[4]));
    Assert(KeyValueList.Keys[5] = '',     'Keys[5]=' + string(KeyValueList.Keys[5]));
    Assert(KeyValueList.Keys[6] = 'Key7', 'Keys[6]=' + string(KeyValueList.Keys[6]));

    Assert(KeyValueList.Values[0] = 'Value1',   'Values[0]=' + string(KeyValueList.Values[0]));
    Assert(KeyValueList.Values[1] = '',         'Values[1]=' + string(KeyValueList.Values[1]));
    Assert(KeyValueList.Values[2] = '',         'Values[2]=' + string(KeyValueList.Values[2]));
    Assert(KeyValueList.Values[3] = 'Value4',   'Values[3]=' + string(KeyValueList.Values[3]));
    Assert(KeyValueList.Values[4] = '',         'Values[4]=' + string(KeyValueList.Values[4]));
    Assert(KeyValueList.Values[5] = 'Value6=6', 'Values[5]=' + string(KeyValueList.Values[5]));
    Assert(KeyValueList.Values[6] = '',         'Values[6]=' + string(KeyValueList.Values[6]));
  finally
    KeyValueList.Free;
  end;
  Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed StringKeyValueList successfully');
end;

procedure Run;
begin
  TestStringKeyValueList;
end;

end.