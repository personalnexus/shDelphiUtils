unit Queues;
    
interface

uses
  CollectionInterfaces;

type
  TConcurrentQueueItemAllocator = function: Pointer of object;
  TConcurrentQueueItemDeallocator = procedure(Item: Pointer) of object;

  TConcurrentQueueItem<TValue> = record
    FValue: TValue;
    FNext:  Pointer;
  end;

  ///<summary>Queue for use with multiple reader- and writer-threads without locking.</summary>
  TConcurrentQueue<TValue> = class(TInterfacedObject, IQueue<TValue>)
  private
    FHead:  Pointer;
    FTail:  Pointer;
    FCount: Integer;

    function GetCount: Integer;

  private
    FAllocator:   TConcurrentQueueItemAllocator;
    FDeallocator: TConcurrentQueueItemDeallocator;

    function AllocateItem: Pointer; inline;
    procedure DeallocateItem(Item: Pointer); inline;

  public
    constructor Create;
    constructor CreateWithMemoryManager(Allocator: TConcurrentQueueItemAllocator;
                                        Deallocator: TConcurrentQueueItemDeallocator);

    destructor Destroy; override;

    procedure Clear;

    procedure Enqueue(const Value: TValue);
    function TryDequeue(out Value: TValue): Boolean;

    property Count: Integer read FCount;
  end;


implementation

uses
  Windows;

// TConcurrentQueue<TValue>

constructor TConcurrentQueue<TValue>.CreateWithMemoryManager(Allocator: TConcurrentQueueItemAllocator;
                                                             Deallocator: TConcurrentQueueItemDeallocator);
begin
  Allocator   := Allocator;
  Deallocator := Deallocator;
  Create;
end;

constructor TConcurrentQueue<TValue>.Create;
begin
  inherited Create;
  FTail := AllocateItem;
  FHead := FTail;
end;

destructor TConcurrentQueue<TValue>.Destroy;
begin
  Clear;
  DeallocateItem(FTail);
  FTail := nil;
  FHead := nil;
  inherited Destroy;
end;

function TConcurrentQueue<TValue>.GetCount: Integer;
begin
  Result := FCount;
end;

procedure TConcurrentQueue<TValue>.Clear;
var
  Value: TValue;
begin
  while (TryDequeue(Value)) do;
end;

procedure TConcurrentQueue<TValue>.Enqueue(const Value: TValue);
var
  CurrentTail:  Pointer;
  NewTail:      Pointer;
  PreviousTail: Pointer;
begin
  NewTail := AllocateItem;
  TConcurrentQueueItem<TValue>(NewTail^).FValue := Value;
  repeat
    CurrentTail  := FTail;
    PreviousTail := InterlockedCompareExchangePointer(FTail, NewTail, CurrentTail);
  until (PreviousTail = CurrentTail);
  TConcurrentQueueItem<TValue>(PreviousTail^).FNext := NewTail;
  //
  // Incrementing FCount releases the new tail making it possible to dequeue
  //
  InterlockedIncrement(FCount);
end;

function TConcurrentQueue<TValue>.TryDequeue(out Value: TValue): Boolean;
var
  CurrentCount:  Integer;
  NewCount:      Integer;
  PreviousCount: Integer;
  CurrentHead:   Pointer;
  NewHead:       Pointer;
  PreviousHead:  Pointer;
begin
  repeat
    CurrentCount := FCount;
    if (CurrentCount = 0) then begin
      PreviousCount := 0;
    end else begin
      Result        := True;
      NewCount      := CurrentCount - 1;
      PreviousCount := InterlockedCompareExchange(FCount, NewCount, CurrentCount);
    end;
  until (PreviousCount = CurrentCount);
  //
  // Only continue when we know there is an item to dequeue, because we were
  // able to decrement FCount by 1 while CurrentCount remained greater than 0.
  //
  if (CurrentCount = 0) then begin
    Result := False;
  end else begin
    Result := True;
    repeat
      CurrentHead  := FHead;
      NewHead      := TConcurrentQueueItem<TValue>(FHead^).FNext;
      PreviousHead := InterlockedCompareExchangePointer(Pointer(FHead), NewHead, CurrentHead);
    until (PreviousHead = CurrentHead);
    //
    // There can be only thread that successfully swaps in NewHead, so this
    // thread is entitled to use NewHead's FValue and deallocate PreviousHead.
    //
    Value := TConcurrentQueueItem<TValue>(NewHead^).FValue;
    DeallocateItem(PreviousHead);
  end;
end;

function TConcurrentQueue<TValue>.AllocateItem: Pointer;
begin
  if (Assigned(FAllocator)) then begin
    Result := FAllocator;
  end else begin
    GetMem(Result, SizeOf(TConcurrentQueueItem<TValue>));
  end;
end;

procedure TConcurrentQueue<TValue>.DeallocateItem(Item: Pointer);
begin
  if (Assigned(FDeallocator)) then begin
    FDeallocator(Item);
  end else begin
    FreeMem(Item, SizeOf(TConcurrentQueueItem<TValue>));
  end;
end;


end.