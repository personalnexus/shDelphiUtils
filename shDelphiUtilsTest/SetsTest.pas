unit SetsTest;

interface

procedure Run;


implementation

uses
  CollectionInterfaces,
  Sets,
  SysUtils;

procedure TestEnumerator;
var
  IntegerSet: TSet<Integer>;
  Value: Integer;
  ValueCount: Integer;
begin
  ValueCount := 0;
  IntegerSet := TSet<Integer>.Create();
  try
    IntegerSet.Add(1);
    IntegerSet.Add(1);
    for Value in IntegerSet do begin
      Inc(ValueCount);
      Assert(Value = 1);
    end;
    Assert(ValueCount = 1);
  finally
    IntegerSet.Free;
  end;
  Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed Enumerator successfully');
end;

procedure TestRemoval;
var
  IntegerSet: TSet<Integer>;
begin
  IntegerSet := TSet<Integer>.Create();
  try
    IntegerSet.Add(1);
    Assert(not IntegerSet.Remove(2), 'Remove an item not in the set');
    Assert(IntegerSet.Remove(1), 'Remove item from the set');
    Assert(not IntegerSet.Remove(1), 'Remove item from the set a second time');
  finally
    IntegerSet.Free;
  end;
  Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed TestRemoval successfully');
end;

procedure Run;
begin
  TestEnumerator;
  TestRemoval;
end;


end.
