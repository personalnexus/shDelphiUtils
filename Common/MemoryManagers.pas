unit MemoryManagers;

interface

const
  RecordHeaderSize = SizeOf(Pointer);

type
  TRecordBlockMemoryManager = class;

  IRecordBlock = interface(IInterface)
    ///<summary>Tries to allocate a record in this block and returns nil when
    /// the block is full</summary>
    function Allocate(MemoryManager: TRecordBlockMemoryManager): Pointer;
    ///<summary>Deallocates the record and if it was the last record in the block
    /// destroys the block</summary>
    procedure Deallocate;
  end;

  TRecordBlockMemoryManager = class(TObject)
  private
    FRecordSize:      Integer;
    FRecordsPerBlock: Integer;
    FCurrentBlock:    IRecordBlock;

    procedure MakeNewCurrentBlock;

  protected
    function _GetCurrentBlock: IRecordBlock;

  public
    constructor Create(RecordSize: Integer;
                       RecordsPerBlock: Integer);
    destructor Destroy; override;

    function Allocate: Pointer;
    procedure Deallocate(ARecord: Pointer);

    property RecordSize:      Integer read FRecordSize;
    property RecordsPerBlock: Integer read FRecordsPerBlock;
  end;

implementation

uses
  SysUtils, Windows;

type
  TRecordBlock = class(TInterfacedObject, IRecordBlock)
  private
    FBlock:           Pointer;
    FRemainingAllocations: Integer;

  public
    constructor Create(MemoryManager: TRecordBlockMemoryManager);
    destructor Destroy; override;

    function Allocate(MemoryManager: TRecordBlockMemoryManager): Pointer;
    procedure Deallocate; inline;

  end;

// TRecordBlockMemoryManager

constructor TRecordBlockMemoryManager.Create(RecordSize: Integer;
                                             RecordsPerBlock: Integer);
begin
  inherited Create;
  FRecordSize      := RecordHeaderSize + RecordSize;
  FRecordsPerBlock := RecordsPerBlock;
  MakeNewCurrentBlock;
end;

destructor TRecordBlockMemoryManager.Destroy;
begin
  FCurrentBlock := nil;
  inherited Destroy;
end;

procedure TRecordBlockMemoryManager.MakeNewCurrentBlock;
var
  CurrentBlock:  IRecordBlock;
  NewBlock:      IRecordBlock;
  PreviousBlock: Pointer;
begin
  CurrentBlock  := FCurrentBlock;
  NewBlock      := TRecordBlock.Create(Self);
  PreviousBlock := InterlockedCompareExchangePointer(Pointer(FCurrentBlock), Pointer(NewBlock), Pointer(CurrentBlock));
  if (PreviousBlock <> Pointer(CurrentBlock)) then begin
    //
    // Release our block when somebody else was faster
    //
    NewBlock._Release;
    NewBlock := nil;
  end;
end;

function TRecordBlockMemoryManager._GetCurrentBlock: IRecordBlock;
begin
  Result := FCurrentBlock;
end;

function TRecordBlockMemoryManager.Allocate: Pointer;
begin
  Result := FCurrentBlock.Allocate(Self);
  while (Result = nil) do begin
    MakeNewCurrentBlock();
    Result := FCurrentBlock.Allocate(Self);
  end;
end;

procedure TRecordBlockMemoryManager.Deallocate(ARecord: Pointer);
var
  Block: TRecordBlock;
begin
  Block := TRecordBlock(PPointer(NativeInt(ARecord) - RecordHeaderSize)^);
  Block._Release;
end;

// TRecordBlock

constructor TRecordBlock.Create(MemoryManager: TRecordBlockMemoryManager);
begin
  inherited Create;
  //
  // Create NewBlock with a +1 reference count to account for the fact that the
  // reference count will not be incremented when setting FCurrentBlock via
  // InterlockedCompareExchangePointer
  //
  _AddRef;
  FRemainingAllocations := MemoryManager.FRecordsPerBlock;
  FBlock := GetMemory(MemoryManager.FRecordsPerBlock * MemoryManager.FRecordSize);
end;

destructor TRecordBlock.Destroy;
begin
  FreeMem(FBlock);
  inherited Destroy;
end;

function TRecordBlock.Allocate(MemoryManager: TRecordBlockMemoryManager): Pointer;
var
  BlockIndex: Integer;
begin
  BlockIndex := InterlockedDecrement(FRemainingAllocations);
  if (BlockIndex < 0) then begin
    Result := nil;
  end else begin
    Result := Pointer(NativeInt(FBlock) + (BlockIndex * MemoryManager.FRecordSize));
    //
    // Store a pointer to this block ahead of the record. Since the block is a
    // reference counted interface but stored here only as a pointer, increment
    // its reference count
    //
    PPointer(Result)^ := Pointer(Self);
    Result := Pointer(NativeInt(Result) + RecordHeaderSize);
    //
    // When the last record gets allocated, prepare a new block. Because
    // FCurrentBlock no longer points to this block, the reference count
    // would have to be decremented after MakeNewCurrentBlock. But instead of
    // incrementing and then immediately decrementing the counter, we just do
    // nothing
    //
    if (BlockIndex <> 0) then begin
      _AddRef;
    end else begin
      MemoryManager.MakeNewCurrentBlock;
    end;
  end;
end;

procedure TRecordBlock.Deallocate;
begin
  Self._Release;
end;


end.
