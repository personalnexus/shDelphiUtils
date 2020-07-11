unit QueuesTest;

interface

procedure Run;

implementation

uses
  SysUtils,
  Classes,
  Windows,
  CollectionInterfaces,
  Queues,
  MemoryManagers;

var
  Queue: IQueue<Integer>;
  CompletedThreads: Integer;

const
  MESSAGE_COUNT = 10 * 1000 * 1000;
  THREAD_COUNT = 5;

procedure EnqueueAsync;
var
  Index: Integer;
begin
  for Index := 1 to MESSAGE_COUNT do begin
    Queue.Enqueue(Index);
  end;
  InterlockedIncrement(CompletedThreads);
end;

procedure DequeueAsync;
var
  Value: Integer;
  DequeueCount: Integer;
begin
  DequeueCount := 0;
  repeat
    if (Queue.TryDequeue(Value)) then begin
      Inc(DequeueCount);
    end;
  until DequeueCount = MESSAGE_COUNT;
  InterlockedIncrement(CompletedThreads);
end;

procedure TestEnqueueSingleThreaded;
var
  Value: Integer;
begin
  Queue.Enqueue(1);
  Queue.Enqueue(2);
  Assert(Queue.TryDequeue(Value), 'First TryDequeue = False');
  Assert(Value = 1, 'First dequeued value. Expected: 1. Actual: ' + IntToStr(Value));
  Assert(Queue.TryDequeue(Value), 'Second TryDequeue = False');
  Assert(Value = 2, 'Second dequeued value. Expected: 2. Actual: ' + IntToStr(Value));

  Assert(not Queue.TryDequeue(Value), 'Third TryDequeue = True');

  Queue.Enqueue(4);
  Assert(Queue.TryDequeue(Value), 'Fourth TryDequeue = False');
  Assert(Value = 4, 'Fourth dequeued value. Expected: 4. Actual: ' + IntToStr(Value));

  Queue.Enqueue(5);
  Queue.Enqueue(6);
  Assert(Queue.TryDequeue(Value), 'Fifth TryDequeue = False');
  Assert(Value = 5, 'Fifth dequeued value. Expected: 5. Actual: ' + IntToStr(Value));
  Assert(Queue.TryDequeue(Value), 'Sixth TryDequeue = False');
  Assert(Value = 6, 'Sixth dequeued value. Expected: 6. Actual: ' + IntToStr(Value));
end;

procedure TestEnqueueMultiThreaded;
var
  Threads: array[1..THREAD_COUNT] of TThread;
  ThreadIndex: Integer;
  Value: Integer;
  DequeueCount: Integer;
  Start: TDateTime;
begin
  DequeueCount := 0;
  Start := Now;
  for ThreadIndex := Low(Threads) to High(Threads) do begin
    Threads[ThreadIndex] := TThread.CreateAnonymousThread(EnqueueAsync);
    Threads[ThreadIndex].Start;
  end;

  while (CompletedThreads < 5) do begin
    Sleep(111);
  end;
  Assert(MESSAGE_COUNT * THREAD_COUNT = Queue.Count, 'Enqueue multi-threaded. ' +
         'Expected: ' + IntToStr(MESSAGE_COUNT * THREAD_COUNT) + '.' +
         'Actual: ' + IntToStr(Queue.Count));

  repeat
    if (Queue.TryDequeue(Value)) then begin
      Inc(DequeueCount);
    end else begin
      Assert(False, 'Failed to dequeue after ' + IntToStr(DequeueCount) + ' items');
    end;
  until (DequeueCount = MESSAGE_COUNT * THREAD_COUNT) or
        (Now - Start > 30 / SecsPerDay);
  Assert(DequeueCount = MESSAGE_COUNT * THREAD_COUNT,
         'Dequeue multi-threaded. ' +
         'Expected: ' + IntToStr(MESSAGE_COUNT * THREAD_COUNT) + '.' +
         'Actual: ' + IntToStr(DequeueCount));
end;

procedure TestEnqueueAndDequeueMultiThreaded;
var
  ThreadIndex: Integer;
begin
  for ThreadIndex := 1 to THREAD_COUNT do begin
    TThread.CreateAnonymousThread(DequeueAsync).Start;
    Sleep(16);
    TThread.CreateAnonymousThread(EnqueueAsync).Start;
  end;

  while (CompletedThreads < 10) do begin
    Sleep(111);
  end;
  Assert(0 = Queue.Count, 'Enqueue and dequeue multi-threaded. ' +
         'Expected: 0 messages in queue.' +
         'Actual: ' + IntToStr(Queue.Count));
end;

procedure ExecuteWithQueue(QueueProc: TProc; const ProcName: string);
var
  MemoryManager: TRecordBlockMemoryManager;
begin
  CompletedThreads := 0;
  MemoryManager := TRecordBlockMemoryManager.Create(SizeOf(TConcurrentQueueItem<Integer>), MESSAGE_COUNT * THREAD_COUNT + 1);
  try
    Queue := TConcurrentQueue<Integer>.CreateWithMemoryManager(MemoryManager.Allocate, MemoryManager.Deallocate);
    try
      QueueProc();
    finally
      Queue := nil;
    end;
    Writeln(FormatDateTime('hh:mm:ss', Now) + ' Completed ' + ProcName + ' successfully');
  finally
    MemoryManager.Free;
  end;
end;

procedure Run;
begin
  Writeln('Testing with ' + IntToStr(THREAD_COUNT * MESSAGE_COUNT) + ' messages.');
  ExecuteWithQueue(TestEnqueueSingleThreaded, 'EnqueueSingleThreaded');
  ExecuteWithQueue(TestEnqueueMultiThreaded, 'EnqueueMultiThreaded');
  ExecuteWithQueue(TestEnqueueAndDequeueMultiThreaded, 'EnqueueAndDequeueMultiThreaded');
 end;


 end.
