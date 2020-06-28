unit Sets;

interface

uses
  System.Collections.Generic,
  CollectionInterfaces;

type
  ///<summary>Basic set implementation based on TDictionary.</summary>
  TSet<T> = class(TInterfacedObject, ISet<T>)
  private
    FItems: TDictionary<T, Integer>;
    function GetCount: Integer;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(const AValue: T);
    function Contains(const AValue: T): Boolean;
    function Remove(const AValue: T):Boolean;

    property Count: Integer read GetCount;
  end;


implementation

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

procedure TSet<T>.Add(const AValue: T);
begin
  FItems.AddOrSetValue(AValue, 0);
end;

function TSet<T>.Contains(const AValue: T): Boolean;
begin
  Result := FItems.ContainsKey(AValue);
end;

function TSet<T>.Remove(const AValue: T): Boolean;
begin
  Result := FItems.Remove(AValue);
end;

function TSet<T>.GetCount: Integer;
begin
  Result := FItems.Count;
end;


end.
