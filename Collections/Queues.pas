unit Queues;
    
interface

uses
  CollectionInterfaces;

type
  TConcurrentQueueItem<TValue> = class
  private
    FValue: TValue;
    FNext:  TConcurrentQueueItem<TValue>;

    constructor Create(const AValue: TValue);
  end;

  ///<summary>Queue for use with multiple reader- and writer-threads without locking.</summary>
  TConcurrentQueue<TValue> = class(TInterfacedObject, IQueue<TValue>)
  private
    FHead:  TConcurrentQueueItem<TValue>;
    FTail:  TConcurrentQueueItem<TValue>;
    FCount: Integer;

    function GetCount: Integer;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure Enqueue(const AValue: TValue);
    function TryDequeue(out AValue: TValue): Boolean;

    property Count: Integer read FCount;
  end;


implementation

uses
  Windows;

// TConcurrentQueueItem<TValue>

constructor TConcurrentQueueItem<TValue>.Create(const AValue: TValue);
begin
  inherited Create;
  FValue := AValue;
end;

// TConcurrentQueue<TValue>

constructor TConcurrentQueue<TValue>.Create;
begin
  inherited Create;
  FTail := TConcurrentQueueItem<TValue>.Create(Default(TValue));
  FHead := FTail;
end;

destructor TConcurrentQueue<TValue>.Destroy;
begin
  Clear;
  FTail.Free;
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

procedure TConcurrentQueue<TValue>.Enqueue(const AValue: TValue);
var
  CurrentTail:  TConcurrentQueueItem<TValue>;
  NewTail:      TConcurrentQueueItem<TValue>;
  PreviousTail: TConcurrentQueueItem<TValue>;
begin
  NewTail := TConcurrentQueueItem<TValue>.Create(AValue);
  repeat
    CurrentTail  := FTail;
    PreviousTail := InterlockedCompareExchangePointer(Pointer(FTail), NewTail, CurrentTail);
  until (PreviousTail = CurrentTail);
  PreviousTail.FNext := NewTail;
  //
  // Incrementing FCount releases the new tail making it possible to dequeue
  //
  InterlockedIncrement(FCount);
end;

function TConcurrentQueue<TValue>.TryDequeue(out AValue: TValue): Boolean;
var
  CurrentCount:  Integer;
  NewCount:      Integer;
  PreviousCount: Integer;
  CurrentHead:   TConcurrentQueueItem<TValue>;
  NewHead:       TConcurrentQueueItem<TValue>;
  PreviousHead:  TConcurrentQueueItem<TValue>;
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
      NewHead      := FHead.FNext;
      PreviousHead := InterlockedCompareExchangePointer(Pointer(FHead), NewHead, CurrentHead);
    until (PreviousHead = CurrentHead);
    //
    // There can be only thread that successfully swaps in NewHead, so this
    // thread is entitled to use NewHead's FValue and free PreviousHead.
    //
    AValue := NewHead.FValue;
    PreviousHead.Free;
  end;
end;


end.