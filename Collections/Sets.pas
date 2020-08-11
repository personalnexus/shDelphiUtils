unit Sets;

interface

uses
  Generics.Collections,
  CollectionInterfaces;

type
  TSet<T> = class;

  TSetEnumerator<T> = class(TInterfacedObject, CollectionInterfaces.IEnumerator<T>)
  private
    FEnumerator: TDictionary<T, Integer>.TPairEnumerator;
  public
    constructor Create(ASet: TSet<T>);
    destructor Destroy; override;

    function GetCurrent: T;
    function MoveNext: Boolean;
    property Current: T read GetCurrent;
  end;

  ///<summary>Basic set implementation based on TDictionary.</summary>
  TSet<T> = class(TInterfacedObject, ISet<T>)
  private
    FItems:         TDictionary<T, Integer>;
    FKeyWasRemoved: Boolean;
    function GetCount: Integer;

    procedure HandleKeyNotification(Sender: TObject; const Key: T; Action: TCollectionNotification);

  public
    constructor Create; overload;
    constructor Create(Values: array of T); overload;
    destructor Destroy; override;

    procedure Add(const Value: T);
    function Contains(const Value: T): Boolean;
    function Remove(const Value: T):Boolean;

    function GetEnumerator: CollectionInterfaces.IEnumerator<T>;

    property Count: Integer read GetCount;
  end;


implementation

uses
  SysUtils;

// TSetEnumerator<T>

constructor TSetEnumerator<T>.Create(ASet: TSet<T>);
begin
  inherited Create;
  FEnumerator := ASet.FItems.GetEnumerator;
end;

destructor TSetEnumerator<T>.Destroy;
begin
  FreeAndNil(FEnumerator);
  inherited Destroy;
end;

function TSetEnumerator<T>.GetCurrent: T;
begin
  Result := FEnumerator.Current.Key;
end;

function TSetEnumerator<T>.MoveNext: Boolean;
begin
  Result := FEnumerator.MoveNext;
end;

// TSet<T>

constructor TSet<T>.Create(Values: array of T);
var
  Value: T;
begin
  Create;
  for Value in Values do begin
    Add(Value);
  end;
end;

constructor TSet<T>.Create;
begin
  inherited Create;
  FItems := TDictionary<T, Integer>.Create;
  FItems.OnKeyNotify := HandleKeyNotification;
end;

destructor TSet<T>.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TSet<T>.Add(const Value: T);
begin
  FItems.AddOrSetValue(Value, 0);
end;

function TSet<T>.Contains(const Value: T): Boolean;
begin
  Result := FItems.ContainsKey(Value);
end;

function TSet<T>.Remove(const Value: T): Boolean;
begin
  FKeyWasRemoved := False;
  FItems.Remove(Value);
  Result := FKeyWasRemoved;
end;

procedure TSet<T>.HandleKeyNotification(Sender: TObject; const Key: T; Action: TCollectionNotification);
begin
  FKeyWasRemoved := Action = cnRemoved;
end;

function TSet<T>.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TSet<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TSetEnumerator<T>.Create(Self);
end;


end.
