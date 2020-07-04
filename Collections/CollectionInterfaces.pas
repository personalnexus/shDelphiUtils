unit CollectionInterfaces;

interface

type
  IEnumerator<T> = interface(IInterface)
    function GetCurrent: T;
    function MoveNext: Boolean;
    property Current: T read GetCurrent;
  end;

  IEnumerable<T> = interface(IInterface)
    function GetEnumerator(): IEnumerator<T>;
  end;

  IQueue<T> = interface(IInterface)
    function GetCount: Integer;

    procedure Enqueue(const AValue: T);
    function TryDequeue(out AValue: T): Boolean;

    property Count: Integer read GetCount;
  end;

  ISet<T> = interface(IEnumerable<T>)
    function GetCount: Integer;

    procedure Add(const AValue: T);
    function Contains(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;

    property Count: Integer read GetCount;
  end;

implementation

end.
