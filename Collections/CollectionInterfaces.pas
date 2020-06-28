unit CollectionInterfaces;

interface

type
  ISet<T> = interface(IEnumerable<T>)
    function GetCount: Integer;

    procedure Add(const AValue: T);
    function Contains(const AValue: T): Boolean;
    function Remove(const AValue: T): Boolean;

    property Count: Integer read GetCount;
  end;

implementation

end.
