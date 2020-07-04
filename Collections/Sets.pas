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

  TKeyNotifyEventHandler<TKey, TValue> = class(TObject)
  private
    FDictionary:    TDictionary<TKey, TValue>;
    FOldHandler:    TCollectionNotifyEvent<TKey>;
    FKeyWasRemoved: Boolean;

    procedure HandleKeyNotification(Sender: TObject; const Item: TKey; Action: TCollectionNotification);

  public
    constructor Create(Dictionary: TDictionary<TKey, TValue>);
    destructor Destroy; override;

    property KeyWasRemoved: Boolean read FKeyWasRemoved;
  end;

  ///<summary>Basic set implementation based on TDictionary.</summary>
  TSet<T> = class(TInterfacedObject, ISet<T>)
  private
    FItems: TDictionary<T, Integer>;
    function GetCount: Integer;

  public
    constructor Create;
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

// TKeyNotifyEventHandler<TKey, TValue>

constructor TKeyNotifyEventHandler<TKey, TValue>.Create(Dictionary: TDictionary<TKey, TValue>);
begin
  inherited Create;
  FDictionary := Dictionary;
  FOldHandler := FDictionary.OnKeyNotify;
  FDictionary.OnKeyNotify := HandleKeyNotification;
end;

destructor TKeyNotifyEventHandler<TKey, TValue>.Destroy;
begin
  //TODO: check if (@FDictionary.OnKeyNotify = @Self.HandleKeyNotification)
  FDictionary.OnKeyNotify := FOldHandler;
  inherited Destroy;
end;

procedure TKeyNotifyEventHandler<TKey, TValue>.HandleKeyNotification(Sender: TObject; const Item: TKey; Action: TCollectionNotification);
begin
  FKeyWasRemoved := True;
end;

// TSet<T>

constructor TSet<T>.Create;
begin
  inherited Create;
  FItems := TDictionary<T, Integer>.Create;
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
var
  Handler: TKeyNotifyEventHandler<T, Integer>;
begin
  //
  // TDictionary.Remove does not return whether the key was actually removed,
  // so we hook the OnKeyNotify event
  //
  Handler := TKeyNotifyEventHandler<T, Integer>.Create(FItems);
  try
    FItems.Remove(Value);
    Result := Handler.KeyWasRemoved;
  finally
    Handler.Free;
  end;
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
