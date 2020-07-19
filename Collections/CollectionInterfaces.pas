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

  IDictionary<TKey, TValue> = interface(IInterface)
    function GetCount: Integer;

    procedure Add(const Key: TKey; const Value: TValue);
    function ContainsKey(const Key: TKey): Boolean;
    function Remove(const Key: TKey): Boolean;
    function TryGetValue(const Key: TKey; out Value: TValue): Boolean;

    property Count: Integer read GetCount;
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
