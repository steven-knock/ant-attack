unit Occupancy;

interface

uses
  Classes, Contnrs, Types, Geometry, GameState;

type
  tEntityOccupancyMap = class( tOccupancyMap )
  private
    Memory : pointer;
    MemorySize : cardinal;
    Size : cardinal;
    Capacity : cardinal;
    PositionMap : tBucketList;
    function    GetCoordinateKey( x, z : integer ) : pointer;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   AddEntity( Entity : tPhysicalEntity ); override;
    procedure   Clear; override;
    function    GetEntities( x, z : integer; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; override;
    function    GetEntities( Origin : tPoint3d; Radius : _float; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; override;
    function    GetEntities( const Rect : tRect; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; override;
  end;

implementation

uses
  Math;

const
  Granularity = 64;
  Offset = 16384;
  EndOfLink = High( cardinal );

type
  pEntityLink = ^tEntityLink;
  tEntityLink = record
    Entity : tPhysicalEntity;
    NextLink : cardinal;
  end;

  pEntityLinkArray = ^tEntityLinkArray;
  tEntityLinkArray = array [ 0 .. 32767 ] of tEntityLink;

constructor tEntityOccupancyMap.Create;
begin
  inherited;
  PositionMap := tBucketList.Create;
end;

destructor tEntityOccupancyMap.Destroy;
begin
  if Memory <> nil then
    FreeMem( Memory );
  PositionMap.Free;
  inherited;
end;

function tEntityOccupancyMap.GetCoordinateKey( x, z : integer ) : pointer;
begin
  inc( x, Offset );
  inc( z, Offset );
  result := pointer( z * 32768 + x );
end;

procedure tEntityOccupancyMap.AddEntity( Entity : tPhysicalEntity );

function Allocate( RequiredSize : cardinal; out Index : cardinal ) : pEntityLink;
var
  NewMemory : pointer;
  NewMemorySize : cardinal;
begin
  inc( RequiredSize, Size );
  if RequiredSize > Capacity then
  begin
    Capacity := ( ( RequiredSize div Granularity ) + 1 ) * Granularity;
    NewMemorySize := Capacity * SizeOf( tEntityLink );
    GetMem( NewMemory, NewMemorySize );
    if Memory <> nil then
    begin
      Move( Memory^, NewMemory^, MemorySize );
      FreeMem( Memory );
    end;
    Memory := NewMemory;
    MemorySize := NewMemorySize;
  end;
  result := Memory;
  inc( result, Size );
  Index := Size;
  Size := RequiredSize;
end;

var
  Rect : tRect;
  RequiredSize : cardinal;
  pScan, pLink : pEntityLink;
  x, z : integer;
  ScanIndex, LinkIndex : cardinal;
  Key : pointer;
begin
  if Entity.EntityType.Solid then
  begin
    Rect := Entity.GetMapRectangle;
    RequiredSize := ( Rect.Right - Rect.Left + 1 ) * ( Rect.Bottom - Rect.Top + 1 );
    pScan := Allocate( RequiredSize, ScanIndex );
    for z := Rect.Top to Rect.Bottom do
      for x := Rect.Left to Rect.Right do
      begin
        pScan^.Entity := Entity;
        Key := GetCoordinateKey( x, z );
        if PositionMap.Find( Key, pointer( LinkIndex ) ) then
        begin
          pLink := Memory;
          inc( pLink, LinkIndex );
          pScan^.NextLink := pLink^.NextLink;
          pLink^.NextLink := ScanIndex;
        end
        else
        begin
          pScan^.NextLink := EndOfLink;
          PositionMap.Add( Key, pointer( ScanIndex ) );
        end;
        inc( pScan );
        inc( ScanIndex );
      end;
  end;
end;

procedure tEntityOccupancyMap.Clear;
begin
  PositionMap.Clear;
  Size := 0;
end;

function tEntityOccupancyMap.GetEntities( x, z : integer; EntityList : tList; IgnoreEntity : tPhysicalEntity ) : integer;
var
  Key : pointer;
  Index : cardinal;
  pLink : pEntityLink;
  Entity : tPhysicalEntity;
begin
  result := 0;
  if EntityList <> nil then
    EntityList.Clear;
  Key := GetCoordinateKey( x, z );
  if PositionMap.Find( Key, pointer( Index ) ) then
  begin
    repeat
      pLink := @pEntityLinkArray( Memory )^[ Index ];
      Entity := pLink^.Entity;
      if Entity <> IgnoreEntity then
      begin
        if EntityList <> nil then
          EntityList.Add( Entity );
        inc( result );
      end;
      Index := pLink^.NextLink;
    until Index = EndOfLink;
  end;
end;

// Code duplicated from GetEntities( Rect, ... ) with the addition of the Rect preparation and the Distance check
function tEntityOccupancyMap.GetEntities( Origin : tPoint3d; Radius : _float; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer;
var
  Rect : tRect;
  RadiusSq : _float;
  mx, mz : integer;
  Index : cardinal;
  Key : pointer;
  pLink : pEntityLink;
  Entity : tPhysicalEntity;
  LookFirst : boolean;
begin
  Rect.Left := Floor( Origin.x - Radius );
  Rect.Top := Floor( Origin.z - Radius );
  Rect.Right := Floor( Origin.x + Radius );
  Rect.Bottom := Floor( Origin.z + Radius );
  RadiusSq := Radius * Radius;

  result := 0;
  if EntityList <> nil then
    EntityList.Clear;
  LookFirst := false;
  for mz := Rect.Top to Rect.Bottom do
    for mx := Rect.Left to Rect.Right do
    begin
      Key := GetCoordinateKey( mx, mz );
      if PositionMap.Find( Key, pointer( Index ) ) then
      begin
        repeat
          pLink := @pEntityLinkArray( Memory )^[ Index ];
          Entity := pLink^.Entity;

          // Distance calculation and check
          if ( Entity <> IgnoreEntity ) and ( Origin.distanceSq( Entity.Location ) <= RadiusSq ) and ( not LookFirst or ( EntityList.IndexOf( Entity ) < 0 ) ) then
          begin
            if EntityList <> nil then
              EntityList.Add( Entity );
            inc( result );
          end;
          Index := pLink^.NextLink;
        until Index = EndOfLink;
      end;
      LookFirst := true;
    end;
end;

function tEntityOccupancyMap.GetEntities( const Rect : tRect; EntityList : tList; IgnoreEntity : tPhysicalEntity ) : integer;
var
  mx, mz : integer;
  Index : cardinal;
  Key : pointer;
  pLink : pEntityLink;
  Entity : tPhysicalEntity;
  LookFirst : boolean;
begin
  result := 0;
  if EntityList <> nil then
    EntityList.Clear;
  LookFirst := false;
  for mz := Rect.Top to Rect.Bottom do
    for mx := Rect.Left to Rect.Right do
    begin
      Key := GetCoordinateKey( mx, mz );
      if PositionMap.Find( Key, pointer( Index ) ) then
      begin
        repeat
          pLink := @pEntityLinkArray( Memory )^[ Index ];
          Entity := pLink^.Entity;
          if ( Entity <> IgnoreEntity ) and ( not LookFirst or ( EntityList.IndexOf( Entity ) < 0 ) ) then
          begin
            if EntityList <> nil then
              EntityList.Add( Entity );
            inc( result );
          end;
          Index := pLink^.NextLink;
        until Index = EndOfLink;
      end;
      LookFirst := true;
    end;
end;

end.
