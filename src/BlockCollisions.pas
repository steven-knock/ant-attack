unit BlockCollisions;

interface

uses
  Classes, Geometry, GameState, Common, Cube;

type
  tEntityBaseCollisionHandler = class( tEntityCollisionHandler )
  private
    fGameState : tGameState;
  protected
    BoundingBoxPoints : array [ boolean, 0 .. 7 ] of tPoint3d;
    property GameState : tGameState read fGameState;
  public
    constructor Create( GameState : tGameState );
    destructor  Destroy; override;
  end;

  tBlockCollisions = class( tEntityBaseCollisionHandler )
  private
    procedure AdjustEntityPosition( Entity : tPhysicalEntity; const HitBlock : tIntPoint3d; HitSurfaces : tCubeSurfaces );
    function  GetHitBlock( Entity : tPhysicalEntity; const Processed : array of boolean; var BlockPosition : tIntPoint3d ) : integer;
    function  GetHitSurfaces( const HitBlock : tIntPoint3d ) : tCubeSurfaces;
  public
    procedure ProcessCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d ); override;
  end;

  tInterEntityCollisions = class( tEntityBaseCollisionHandler )
  private
    Force : tPoint3d;
    EntityList : tList;
  public
    constructor Create( GameState : tGameState );
    destructor  Destroy; override;
    procedure   ProcessCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d ); override;
  end;

implementation

uses
  Math, GameSound, Map;

(* tEntityBaseCollisionHandler *)

constructor tEntityBaseCollisionHandler.Create( GameState : tGameState );
var
  Pass : boolean;
  Idx : integer;
begin
  inherited Create;
  fGameState := GameState;
  for Pass := false to true do
    for Idx := 0 to 7 do
      BoundingBoxPoints[ Pass, Idx ] := tPoint3d.Create;
end;

destructor tEntityBaseCollisionHandler.Destroy;
var
  Pass : boolean;
  Idx : integer;
begin
  for Pass := false to true do
    for Idx := 0 to 7 do
      BoundingBoxPoints[ Pass, Idx ].Free;
  inherited;
end;

(* tBlockCollisions *)

// Returns the lowest block that is closest to the entity's centre point
function tBlockCollisions.GetHitBlock( Entity : tPhysicalEntity; const Processed : array of boolean; var BlockPosition : tIntPoint3d ) : integer;
var
  Map : tMap;
  Idx : integer;
  Block : tBlockType;
  BBPoint : tPoint3d;
  CurrentBlockPosition : tIntPoint3d;
  BestY : integer;
  Distance, BestDistance : _float;
  Lower, Equal, Closer : boolean;
begin
  result := -1;
  Map := GameState.Map;
  BestDistance := -1;
  BestY := $7fff;
  for Idx := 0 to 7 do
  begin
    if not Processed[ Idx ] then
    begin
      BBPoint := BoundingBoxPoints[ true, Idx ];
      with CurrentBlockPosition do
      begin
        x := Floor( BBPoint.x );
        y := Floor( BBPoint.y );
        z := Floor( BBPoint.z );
        if Map.coordinatesInMap( x, y, z ) then
        begin
          Block := Map.Block[ x, y, z ];
          if ( Block <> BLOCK_EMPTY ) and ( Block <> BLOCK_WATER ) then
          begin
            Distance := Sqr( Entity.Location.x - x ) + Sqr( Entity.Location.z - y ) + Sqr( Entity.Location.z - z );
            Lower := y < BestY;
            Equal := y = BestY;
            Closer := ( BestDistance < 0 ) or ( Distance < BestDistance );
            if Lower or ( Equal and Closer ) then
            begin
              BlockPosition := CurrentBlockPosition;
              BestY := y;
              BestDistance := Distance;
              result := Idx;
            end;
          end;
        end;
      end;
    end;
  end;
end;

// Returns a set of the surfaces with which the entity's bounding box intersects
function tBlockCollisions.GetHitSurfaces( const HitBlock : tIntPoint3d ) : tCubeSurfaces;
var
  Idx : integer;
  SIdx : tCubeSurface;
  Pass : boolean;
  SurfaceExists : tCubeSurfaces;
  SurfaceBehind : array [ boolean ] of tCubeSurfaces;

function IsBehind : boolean;
var
  nDot, cx, cy, cz : _float;
  ptLocation : tPoint3d;
begin
  ptLocation := BoundingBoxPoints[ Pass, Idx ];
  cx := ptLocation.x - HitBlock.x - ptBoxVertex[ SIdx, 0, 0 ];
  cy := ptLocation.y - HitBlock.y - ptBoxVertex[ SIdx, 0, 1 ];
  cz := ptLocation.z - HitBlock.z - ptBoxVertex[ SIdx, 0, 2 ];
  nDot := ptBoxNormal[ SIdx, 0 ] * cx;
  nDot := nDot + ptBoxNormal[ SIdx, 1 ] * cy;
  nDot := nDot + ptBoxNormal[ SIdx, 2 ] * cz;
  result := nDot < 0;
end;

procedure PrepareAdjacentBlocks;
var
  AdjacentBlocks : tAdjacentBlocks;
  SIdx : tCubeSurface;
begin
  SurfaceExists := [];
  with HitBlock do
    GameState.Map.getAdjacentBlocks( x, y, z, AdjacentBlocks );
  for SIdx := Low( tCubeSurface ) to High( tCubeSurface ) do
    if ( AdjacentBlocks[ SIdx ] = BLOCK_EMPTY ) or ( AdjacentBlocks[ SIdx ] = BLOCK_WATER ) then
      include( SurfaceExists, SIdx );
end;

begin
  result := [];

  PrepareAdjacentBlocks;
  for Pass := false to true do
  begin
    SurfaceBehind[ Pass ] := [];
    for SIdx := Low( tCubeSurface ) to High( tCubeSurface ) do
      if SIdx in SurfaceExists then
        for Idx := 0 to 7 do
          if IsBehind then
          begin
            Include( SurfaceBehind[ Pass ], SIdx );
            break;
          end;
  end;

  for SIdx := Low( tCubeSurface ) to High( tCubeSurface ) do
    if not ( SIdx in SurfaceBehind[ false ] ) and ( SIdx in SurfaceBehind[ true ] ) then
      Include( result, SIdx );
end;

// Adjusts the position of the entity so that it no longer intersects with a surface. It is "pushed" by only one surface at a time,
// before looping round again to see whether it still intersects with the block. The TOP surface is tested first, since the player
// should be able to slide along surfaces within impendence.
procedure tBlockCollisions.AdjustEntityPosition( Entity : tPhysicalEntity; const HitBlock : tIntPoint3d; HitSurfaces : tCubeSurfaces );
const
  ADJUSTMENT = 0.0001;
  Surface : array [ 0 .. 5 ] of tCubeSurface = ( CS_TOP, CS_BOTTOM, CS_LEFT, CS_RIGHT, CS_FAR, CS_NEAR );   // Test TOP first to push entity onto blocks before any other tests
var
  Idx : integer;
  SIdx : tCubeSurface;
  BB : tBoundingBox;
begin
  BB := Entity.BoundingBox;
  for Idx := Low( Surface ) to High( Surface ) do
  begin
    SIdx := Surface[ Idx ];
    if SIdx in HitSurfaces then
    begin
      case SIdx of
        CS_TOP:
        begin
          Entity.Location.y := HitBlock.y + 1 - BB.Bottom + ADJUSTMENT;
          Entity.Velocity.y := 0;
        end;
        CS_BOTTOM:
        begin
          Entity.Location.y := HitBlock.y - BB.Top - ADJUSTMENT;
          Entity.Velocity.y := 0;
        end;
        CS_LEFT:
        begin
          Entity.Location.x := HitBlock.x - BB.Right - ADJUSTMENT;
          Entity.Velocity.x := 0;
        end;
        CS_RIGHT:
        begin
          Entity.Location.x := HitBlock.x + 1 - BB.Left + ADJUSTMENT;
          Entity.Velocity.x := 0;
        end;
        CS_FAR:
        begin
          Entity.Location.z := HitBlock.z - BB.Near - ADJUSTMENT;
          Entity.Velocity.z := 0;
        end;
        CS_NEAR:
        begin
          Entity.Location.z := HitBlock.z + 1 - BB.Far + ADJUSTMENT;
          Entity.Velocity.z := 0;
        end;
      end;
      break;
    end;
  end;
end;

procedure tBlockCollisions.ProcessCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d );
var
  BlockPosition : tIntPoint3d;
  Processed : array [ 0 .. 7 ] of boolean;
  HitBlock : integer;
  HitSurfaces : tCubeSurfaces;
  Airborne, Touching : boolean;
begin
  Airborne := true;
  Touching := false;
  FillChar( Processed, SizeOf( Processed ), 0 );

  Entity.GetBoundingBoxPoints( BoundingBoxPoints[ false ], false, LastLocation );
  repeat
    Entity.GetBoundingBoxPoints( BoundingBoxPoints[ true ] );
    HitBlock := GetHitBlock( Entity, Processed, BlockPosition );
    if HitBlock >= 0 then
    begin
      HitSurfaces := GetHitSurfaces( BlockPosition );
      if HitSurfaces <> [] then
      begin
        AdjustEntityPosition( Entity, BlockPosition, HitSurfaces );
        if CS_TOP in HitSurfaces then
          Airborne := false;
        Touching := true;
        FillChar( Processed, SizeOf( Processed ), 0 );
      end
      else
        Processed[ HitBlock ] := true;
    end;
  until ( HitBlock < 0 );

  if ( Entity.Location.y <= 0 ) and ( Entity.State <> STATE_EMERGING ) then
  begin
    Airborne := false;
    if Entity.Location.y < 0 then
    begin
      Entity.Location.y := 0;
      Entity.Velocity.y := 0;
    end;
  end;

  Entity.Airborne := Airborne;
  Entity.WasTouchingBlock := Entity.TouchingBlock;
  Entity.TouchingBlock := Touching;
end;

(* tInterEntityCollisions *)

constructor tInterEntityCollisions.Create( GameState : tGameState );
begin
  inherited;
  Force := tPoint3d.Create;
  EntityList := tList.Create;
end;

destructor tInterEntityCollisions.Destroy;
begin
  EntityList.Free;
  Force.Free;
  inherited;
end;

procedure tInterEntityCollisions.ProcessCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d );
const
  ADJUSTMENT = 0.0001;
type
  tDirection = ( BOTTOM, TOP, LEFT, RIGHT, FAR, NEAR );
  tPositions = array [ tDirection ] of _float;

procedure ApplyForce( Source, Target : tPhysicalEntity );
begin
  Force.setLocation( Source.Velocity );
  Force.scale( Source.EntityType.Mass );
  Force.scale( Source.EntityType.GetCollisionFriction( Target.EntityType ) );   // Some energy lost in the collision

  // Do not allow emerging Ants to be shoved around under ground
  if ( Source.State = STATE_EMERGING ) or ( Target.State = STATE_EMERGING ) then
  begin
    Force.x := 0;
    Force.z := 0;
  end;

  // Do not allow Ants to pull back humans when they jump - bit of a hack but improves gameplay no end
  if Source.EntityType.Human and tPlayerEntity( Source ).Jumping then
    Force.y := 0;

  Target.ApplyForce( Force );
  Force.negate;
  Source.ApplyForce( Force );
  Source.TouchingList.Add( Target );
end;

procedure PopulatePositions( BoundingBox : tBoundingBox; Location : tPoint3d; var Positions : tPositions );
begin
  Positions[ BOTTOM ] := BoundingBox.Bottom + Location.y;
  Positions[ TOP ] := BoundingBox.Top + Location.y;
  Positions[ LEFT ] := BoundingBox.Left + Location.x;
  Positions[ RIGHT ] := BoundingBox.Right + Location.x;
  Positions[ FAR ] := BoundingBox.Far + Location.z;
  Positions[ NEAR ] := BoundingBox.Near + Location.z;
end;

var
  Idx, IIdx : integer;
  PhysicalEntity : tPhysicalEntity;
  Entity_Before, Entity_After, Target : tPositions;
  Intersect : boolean;
  D1, D2 : tDirection;
  Difference : _float;
  Correction : _float;

begin
  PopulatePositions( Entity.BoundingBox, LastLocation, Entity_Before );
  PopulatePositions( Entity.BoundingBox, Entity.Location, Entity_After );

  GameState.OccupancyMap.GetEntities( Entity.GetMapRectangle, EntityList, Entity );
  for Idx := 0 to EntityList.Count - 1 do
  begin
    PhysicalEntity := EntityList[ Idx ];
    if PhysicalEntity.EntityType.Solid then
    begin
      PopulatePositions( PhysicalEntity.BoundingBox, PhysicalEntity.Location, Target );

      Intersect := ( Entity_After[ BOTTOM ] < Target[ TOP ] ) and ( Entity_After[ TOP ] > Target[ BOTTOM ] ) and
                   ( Entity_After[ LEFT ] < Target[ RIGHT ] ) and ( Entity_After[ RIGHT ] > Target[ LEFT ] ) and
                   ( Entity_After[ FAR ] < Target[ NEAR ] ) and ( Entity_After[ NEAR ] > Target[ FAR ] );
      if Intersect then
      begin
        ApplyForce( Entity, PhysicalEntity );
        ApplyForce( PhysicalEntity, Entity );

        for IIdx := 0 to 2 do
        begin
          D1 := tDirection( IIdx * 2 );
          D2 := Succ( D1 );

          Intersect := ( Entity_Before[ D1 ] < Target[ D2 ] ) and ( Entity_Before[ D2 ] > Target[ D1 ] );
          if not Intersect then
          begin
            Difference := Entity_After[ D1 ] - Entity_Before[ D1 ];
            if Difference > 0 then
              Correction := Target[ D1 ] - Entity_After[ D2 ] - ADJUSTMENT
            else  // Difference cannot be 0
              Correction := Target[ D2 ] - Entity_After[ D1 ] + ADJUSTMENT;

            with Entity do
              case IIdx of
                0:
                begin
                  Location.y := Location.y + Correction;
                  if Difference < 0 then
                    Airborne := false
                  else
                    PhysicalEntity.Airborne := false;
                  if ( PhysicalEntity.State = STATE_MOBILE ) and ( PhysicalEntity.EntityType.ParalysisThreshold > 0 ) and ( PhysicalEntity.Force.y < -PhysicalEntity.EntityType.ParalysisThreshold ) then
                    PhysicalEntity.State := STATE_PARALYSED;
                end;
                1:
                  Location.x := Location.x + Correction;
                2:
                  Location.z := Location.z + Correction;
              end;

            PopulatePositions( Entity.BoundingBox, Entity.Location, Entity_After );

            break;
          end;
        end;
      end;
    end;
  end;
end;

end.
