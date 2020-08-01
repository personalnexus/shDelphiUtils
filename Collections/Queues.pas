unit Queues;
    
interface

uses
  CollectionInterfaces;

var
  MarkerToFreeUpdatable: TObject;

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

  ///<summary>Default implementation without locking for IUpdatableObject{T}</summary>
  TUpdatable<T: class> = class(TObject)
  strict private
    FMostRecentUpdate: T;
  protected
    // IUpdatableObject<T>
    function GetUpdate: T;
    function ExchangeUpdate(NewUpdate: T): T;
  public
    procedure FreeIfNotQueued; virtual;
  end;

  ///<summary>Queue keeping track of only the most recent update for an object without locking.</summary>
  TMostRecentUpdateQueue<T: class> = class(TObject)
  private
    FQueue: IQueue<TUpdatable<T>>;

  public
    constructor Create; overload;
    constructor Create(InternalQueue: IQueue<TUpdatable<T>>); overload;
    destructor Destroy; override;

    procedure Enqueue(Updatable: TUpdatable<T>; NewUpdate: T);
    function TryDequeue(out Update: T): Boolean;
  end;


implementation

uses
  SysUtils, Windows;

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

// TUpdatable<T>

procedure TUpdatable<T>.FreeIfNotQueued;
var
  OldUpdate: T;
begin
  //
  // If the object is still queued, it will be freed when the marker is seen by
  // TMostRecentUpdateQueue.TryDequeue which held the last reference
  //
  OldUpdate := ExchangeUpdate(MarkerToFreeUpdatable);
  if (OldUpdate = nil) then begin
    Free;
  end else begin
    TObject(OldUpdate).Free;
  end;
end;

function TUpdatable<T>.GetUpdate: T;
begin
  Result := FMostRecentUpdate;
end;

function TUpdatable<T>.ExchangeUpdate(NewUpdate: T): T;
begin
  Result := InterlockedExchangePointer(Pointer(TObject(FMostRecentUpdate)),
                                       Pointer(TObject(NewUpdate)));
end;

// TMostRecentUpdateQueue<T>

constructor TMostRecentUpdateQueue<T>.Create();
begin
  Create(TConcurrentQueue<TUpdatable<T>>.Create);
end;

constructor TMostRecentUpdateQueue<T>.Create(InternalQueue: IQueue<TUpdatable<T>>);
begin
  inherited Create;
  FQueue := InternalQueue;
end;

destructor TMostRecentUpdateQueue<T>.Destroy;
var
  Update: T;
begin
  while (TryDequeue(Update)) do ;
  FQueue := nil;
  inherited Destroy;
end;

procedure TMostRecentUpdateQueue<T>.Enqueue(Updatable: TUpdatable<T>; NewUpdate: T);
var
  OldUpdate: TObject;
begin
  //
  // If the previous Update was something other than nil, the updatable was
  // still queued and we just replaced the update with a newer one. We have to
  // free the old one.
  //
  OldUpdate := TObject(Updatable.ExchangeUpdate(NewUpdate));
  if (OldUpdate = nil) then begin
    FQueue.Enqueue(Updatable);
  end else if (OldUpdate <> MarkerToFreeUpdatable) then begin
    OldUpdate.Free;
  end else begin
    //TODO: This should not happen. Someone enqueued an update for an object
    // that supposed to be freed.
  end;
end;

function TMostRecentUpdateQueue<T>.TryDequeue(out Update: T): Boolean;
var
  Updatable: TUpdatable<T>;
begin
  Update := nil;
  while (Update = nil) do begin
    if (not FQueue.TryDequeue(Updatable)) then begin
      Exit(False);
    end else begin
      Update := Updatable.ExchangeUpdate(nil);
      if (TObject(Update) = MarkerToFreeUpdatable) then begin
        Updatable.FreeIfNotQueued;
        Update := nil;
      end;
    end;
  end;
  Result := True;
end;


initialization
  MarkerToFreeUpdatable := TObject.Create;

finalization
  MarkerToFreeUpdatable.Free;

end.