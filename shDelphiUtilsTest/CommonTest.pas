unit CommonTest;

interface

procedure Run;


implementation

uses
  SysUtils, MemoryManagers, Dialogs;

type
  TRecord = record
    Value: Integer;
  end;

  PRecord = ^TRecord;

  // Gain access to protected fields for testing purposes
  TRecordBlockMemoryManagerEx = class(TRecordBlockMemoryManager);

procedure TestRecordBlockMemoryManager;
var
  Index:   Integer;
  MM:      TRecordBlockMemoryManagerEx;
  Rec:     PRecord;
  Records: array[0..100000] of PRecord;
  Block:   IRecordBlock;
  BlockPointer: Pointer;
begin
  MM := TRecordBlockMemoryManagerEx.Create(SizeOf(TRecord), 24943);
  try
    // Keep an additional reference to simulate contention on FCurrentBlock and
    // make sure the object is usable but eventually freed properly
    Block := MM._GetCurrentBlock;

    for Index := Low(Records) to High(Records) do begin
      Rec := MM.Allocate;
      Rec^.Value := Index;
      Records[Index] := Rec;
    end;

    for Index := Low(Records) to High(Records) do begin
      Rec := Records[Index];
      Assert(Rec.Value = Index);
      MM.Deallocate(Rec);
    end;

    Assert(Block.Allocate(MM) = nil);
    Block := nil;
  finally
    MM.Free;
  end;
  Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed RecordBlockMemoryManager successfully');
end;

procedure Run;
begin
  TestRecordBlockMemoryManager;
  //TODO: add multi-threaded test
end;

end.
