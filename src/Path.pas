unit Path;

interface

uses
  Common, Cube, GameState, Geometry, Map;

type
  tPathStatus = ( STATE_INVALID, STATE_PARTIAL, STATE_COMPLETE );

  tPathNode = class( tObject )
  private
    fLocation : tIntPoint3d;
    fDistance : integer;
    fParent : tPathNode;
    fRoutePart : boolean;
    fAirborne : boolean;
    fJumpCount : cardinal;
    fJumpDirection : tCubeSurface;
    property    RoutePart : boolean read fRoutePart write fRoutePart;
  public
    constructor Create( Parent : tPathNode; const Location : tIntPoint3d );
    property    Parent : tPathNode read fParent;
    property    Location : tIntPoint3d read fLocation;
    property    Distance : integer read fDistance;
    property    Airborne : boolean read fAirborne;
    property    JumpCount : cardinal read fJumpCount;
    property    JumpDirection : tCubeSurface read fJumpDirection;
  end;

  tPath = class( tObject )
  private
    fAllow3d : boolean;
    fAllowPartial : boolean;
    fAllowAirborneTarget : boolean;
    fAllowSwimming : boolean;
    fReferenceCount : integer;
    fEntity : tPhysicalEntity;
    fGameState : tGameState;
    fJumpLength : cardinal;
    fNodeList : tObjectList;
    fStatus : tPathStatus;
    fMaximumIterations : integer;
    property    Entity : tPhysicalEntity read fEntity;
    function    GetNode( Index : integer ) : tPathNode;
    function    GetNodeCount : integer;
    property    GameState : tGameState read fGameState;
  public
    constructor Create( Entity : tPhysicalEntity; GameState : tGameState );
    destructor  Destroy; override;
    procedure   Free;
    procedure   BuildPath( Source, Target : tPoint3d );
    function    Clone : tPath;
    property    Allow3d : boolean read fAllow3d write fAllow3d;
    property    AllowPartial : boolean read fAllowPartial write fAllowPartial;
    property    AllowAirborneTarget : boolean read fAllowAirborneTarget write fAllowAirborneTarget;
    property    AllowSwimming : boolean read fAllowSwimming write fAllowSwimming;
    property    JumpLength : cardinal read fJumpLength write fJumpLength;
    property    MaximumIterations : integer read fMaximumIterations write fMaximumIterations;
    property    Node[ Index : integer ] : tPathNode read GetNode;
    property    NodeCount : integer read GetNodeCount;
    property    Status : tPathStatus read fStatus;
  end;

implementation

uses
  Classes, Contnrs, Log, Math, SysUtils, Windows;

constructor tPath.Create( Entity : tPhysicalEntity; GameState : tGameState );
begin
  inherited Create;
  fAllowPartial := true;
  fEntity := Entity;
  fGameState := GameState;
  fReferenceCount := 1;
  fMaximumIterations := 64;
  fJumpLength := 3;
  fNodeList := Common.tObjectList.Create;
end;

destructor tPath.Destroy;
begin
  fNodeList.Free;
  inherited;
end;

procedure tPath.Free;
begin
  if Self <> nil then
  begin
    dec( fReferenceCount );
    if fReferenceCount = 0 then
      inherited Free;
  end;
end;

function tPath.Clone : tPath;
begin
  result := Self;
  inc( fReferenceCount );
end;

procedure tPath.BuildPath( Source, Target : tPoint3d );
type
  tConsiderationResult = ( CR_IMPASSABLE, CR_EARTHBOUND, CR_AIRBORNE, CR_COMPLETE );

const
  CubeSurface : array [ 0 .. 5 ] of tCubeSurface = ( CS_LEFT, CS_RIGHT, CS_FAR, CS_NEAR, CS_TOP, CS_BOTTOM );
  Direction : array [ 0 .. 5 ] of tIntPoint3d = ( ( x:-1; y:0; z:0 ), ( x:1; y:0; z:0 ), ( x:0; y:0; z:-1 ), ( x:0; y:0; z:1 ), ( x:0; y:1; z:0 ), ( x:0; y:-1; z:0 ) );
  DirectionIndex : array [ tCubeSurface ] of integer = ( 0, 1, 4, 5, 2, 3 );  // Reverse-lookup into Direction table

  SolidBlocks : array [ tCubeSurface ] of tBlockType = ( BLOCK_SOLID, BLOCK_SOLID, BLOCK_SOLID, BLOCK_SOLID, BLOCK_SOLID, BLOCK_SOLID );
  EmptyBlocks : array [ tCubeSurface ] of tBlockType = ( BLOCK_EMPTY, BLOCK_EMPTY, BLOCK_EMPTY, BLOCK_EMPTY, BLOCK_EMPTY, BLOCK_EMPTY );
  SolidBlocksExceptForTop : array [ tCubeSurface ] of tBlockType = ( BLOCK_SOLID, BLOCK_SOLID, BLOCK_EMPTY, BLOCK_SOLID, BLOCK_SOLID, BLOCK_SOLID );

  Directions2d = 3;

var
  Nodes : tList;
  OpenNodes : tStringList;
  CreatedNodes : tBucketList;
  ActiveEntities : tList;
  ptSource, ptTarget : tIntPoint3d;
  Width, Height : integer;
  AdjacentBlocks, UnderneathBlocks : tAdjacentBlocks;
  pAdjacentBlocks, pUnderneathBlocks : ^tAdjacentBlocks;
  ClosestNode : tPathNode;

function GetNodeKey( Distance : integer ) : string;
begin
  result := IntToStr( 9999999999 - Distance );
end;

// This routine makes a unique cardinal value from the 3d map co-ordinate
// Imagine the map at the centre of a large square area, starting 4096 units in. So, that's 4096 units to the left / top, 4096 for the map itself, and 4096 to the right / bottom.
// That gives ( 4096 * 3 ) ^ 2 = 150,994,944
// 9 possible y values (including -1) gives: 150,994,944 * 9 = 1,358,954,496 which fits well within even a signed 4-byte integer.
function GetLocationKey( const Location : tIntPoint3d ) : pointer;
const
  Offset = 4096;
  ZFactor = Offset * 3;
  YFactor = ZFactor * ZFactor;
begin
  with Location do
    result := pointer( ( y + 1 ) * YFactor + ( z + Offset ) * ZFactor + x + Offset );
end;

procedure PushNode( Node : tPathNode );
begin
  Nodes.Add( Node );
  OpenNodes.AddObject( GetNodeKey( Node.Distance ), Node );
end;

function PopNode : tPathNode;
var
  Count : integer;
begin
  Count := OpenNodes.Count;
  result := tPathNode( OpenNodes.Objects[ Count - 1 ] );
  OpenNodes.Delete( Count - 1 );
end;

function HasNodes : boolean;
begin
  result := OpenNodes.Count > 0;
end;

procedure FreeUnusedNodes;
var
  Idx : integer;
  Node : tPathNode;
begin
  for Idx := 0 to Nodes.Count - 1 do
  begin
    Node := tPathNode( Nodes[ Idx ] );
    if not Node.RoutePart then
      Node.Free;
  end;
end;

function Distance( const L1, L2 : tIntPoint3d ) : cardinal;
var
  x, y, z : integer;
begin
  x := L2.x - L1.x;
  z := L2.z - L1.z;
  if Allow3d then
  begin
    y := L2.y - L1.y;
    result := x * x + y * y + z * z;
  end
  else
    result := x * x + z * z;
end;

procedure BuildRoute( Node : tPathNode );
begin
  repeat
    Node.RoutePart := true;
    fNodeList.Add( Node );
    Node := Node.Parent;
  until Node = nil;
end;

procedure BuildPartialRoute;
begin
  if AllowPartial then
  begin
    fStatus := STATE_PARTIAL;
    BuildRoute( ClosestNode );
    if GameState.SharedStateData.IsLogEnabled then
      GameState.SharedStateData.Log( LOG_PATH, 'Built partial path from [%d, %d, %d]-[%d, %d, %d] (Target was [%d, %d, %d]) containing %d nodes', [ ptSource.x, ptSource.y, ptSource.z, ClosestNode.Location.x, ClosestNode.Location.y, ClosestNode.Location.z, ptTarget.x, ptTarget.y, ptTarget.z, NodeCount ] );
  end
  else
    fStatus := STATE_INVALID;
end;

procedure GetAdjacentSurfaces( Node : tPathNode );
var
  BorderBlock : tBlockType;
  Map : tMap;
  Surface : tCubeSurface;
begin
  Map := GameState.Map;
  if ( Node.Location.x < 0 ) or ( Node.Location.x >= Width ) or ( Node.Location.z < 0 ) or ( Node.Location.z >= Height ) then   // Handle cases where the path leaves the map
  begin
    Surface := CS_LEFT;   // Initialise Variable to avoid compiler warnings
    BorderBlock := BLOCK_EMPTY;
    if ( Node.Location.z >= 0 ) and ( Node.Location.z < Height ) then
    begin
      if Node.Location.x = -1 then   // Left Border
      begin
        BorderBlock := Map.Block[ 0, Node.Location.y, Node.Location.z ];
        Surface := CS_RIGHT;
      end
      else if Node.Location.x = Width then   // Right Border
      begin
        BorderBlock := Map.Block[ Width - 1, Node.Location.y, Node.Location.z ];
        Surface := CS_LEFT;
      end;
    end
    else if ( Node.Location.x >= 0 ) and ( Node.Location.x < Width ) then
    begin
      if Node.Location.z = -1 then   // Top Border
      begin
        BorderBlock := Map.Block[ Node.Location.x, Node.Location.y, 0 ];
        Surface := CS_NEAR;
      end
      else if Node.Location.z = Height then    // Bottom Border
      begin
        BorderBlock := Map.Block[ Node.Location.x, Node.Location.y, Height - 1 ];
        Surface := CS_FAR;
      end;
    end;

    if BorderBlock <> BLOCK_EMPTY then
    begin
      Move( EmptyBlocks, AdjacentBlocks, SizeOf( tAdjacentBlocks ) );
      AdjacentBlocks[ Surface ] := BorderBlock;
      pAdjacentBlocks := @AdjacentBlocks;
    end
    else
      pAdjacentBlocks := @EmptyBlocks;
    if Node.Location.y > 0 then
      pUnderneathBlocks := @EmptyBlocks
    else
      pUnderneathBlocks := @SolidBlocks;
  end
  else
  begin
    pAdjacentBlocks := @AdjacentBlocks;
    with Node.Location do
    begin
      Map.getAdjacentBlocks( x, y, z, AdjacentBlocks );
      if y > 0 then
      begin
        pUnderneathBlocks := @UnderneathBlocks;
        Map.getAdjacentBlocks( x, y - 1, z, UnderneathBlocks );
      end
      else if Allow3d then
        pUnderneathBlocks := @SolidBlocksExceptForTop
      else
        pUnderneathBlocks := @SolidBlocks;
    end;
  end;
end;

function GetBlockBeneathAirborneNode( Node : tPathNode ) : tBlockType;
begin
  with Node.Location do
    if y > 1 then
      if ( x > 0 ) and ( x < Width ) and ( z > 0 ) and ( z < Height ) then
        result := GameState.Map.Block[ x, y - 2, z ]
      else
        result := BLOCK_EMPTY
    else
      result := BLOCK_SOLID;
end;

function ConsiderDirection( Surface : tCubeSurface; Node : tPathNode; Direction : tIntPoint3d ) : tConsiderationResult;
const
  ValidBlock : array [ boolean ] of tBlockType = ( BLOCK_EMPTY, BLOCK_WATER );
var
  AIdx : integer;
  ptCursor : tIntPoint3d;
  Key : pointer;
  NewNode : tPathNode;
  Penalty : integer;
  UnderneathIsSolid : boolean;
begin
  result := CR_IMPASSABLE;
  if pAdjacentBlocks^[ Surface ] <= ValidBlock[ AllowSwimming ] then
  begin
    if pUnderneathBlocks^[ Surface ] >= BLOCK_PILLAR then
    begin
      UnderneathIsSolid := true;
      result := CR_EARTHBOUND;
    end
    else
    begin
      result := CR_AIRBORNE;
      UnderneathIsSolid := false;
    end;
    if UnderneathIsSolid or Allow3d then
    begin
      with Direction do
      begin
        ptCursor.x := Node.Location.x + x;
        ptCursor.y := Node.Location.y + y;
        ptCursor.z := Node.Location.z + z;
      end;
      Key := GetLocationKey( ptCursor );
      if not CreatedNodes.Exists( Key ) then
      begin
        NewNode := tPathNode.Create( Node, ptCursor );
        if ( ptCursor.x = ptTarget.x ) and ( ptCursor.z = ptTarget.z ) and ( not Allow3d or ( ptCursor.y = ptTarget.y ) ) then
        begin
          if UnderneathIsSolid or AllowAirborneTarget then
          begin
            BuildRoute( NewNode );
            fStatus := STATE_COMPLETE;
            if GameState.SharedStateData.IsLogEnabled then
              GameState.SharedStateData.Log( LOG_PATH, 'Built complete path from [%d, %d, %d]-[%d, %d, %d] containing %d nodes', [ ptSource.x, ptSource.y, ptSource.z, ptTarget.x, ptTarget.y, ptTarget.z, NodeCount ] );
            result := CR_COMPLETE;
          end
          else
          begin
            BuildPartialRoute;
            result := CR_COMPLETE;
          end;
          exit;
        end;

        NewNode.fDistance := Distance( ptTarget, ptCursor );

        if GameState.OccupancyMap.GetEntities( ptCursor.x, ptCursor.z, ActiveEntities, Entity ) > 0 then
        begin
          Penalty := 5;     // 5/4ths penalty
          for AIdx := 0 to ActiveEntities.Count - 1 do
            if tPhysicalEntity( ActiveEntities[ AIdx ] ).State <> STATE_MOBILE then
            begin
              Penalty := 64;    // 16/4ths penalty
              break;
            end;
          NewNode.fDistance := NewNode.fDistance * Penalty * Penalty div ( 4 * 4 );
        end;

        if not UnderneathIsSolid then
        begin
          NewNode.fAirborne := true;
          if Surface = CS_TOP then    // We are jumping
          begin
            NewNode.fJumpCount := JumpLength;
            NewNode.fJumpDirection := CS_TOP;
            NewNode.fDistance := 0;   // Starting a jump costs nothing and must be the next node popped from the stack
          end
          else if ( Surface = CS_BOTTOM ) or not Node.Airborne then    // We are falling
          begin
            NewNode.fJumpCount := High( Integer );
            NewNode.fJumpDirection := CS_BOTTOM;
            inc( NewNode.fDistance, 1 );    // Slight penalty for falling
          end
          else    // We are flying through the air...
          begin
            NewNode.fJumpCount := Node.fJumpCount - 1;
            NewNode.fJumpDirection := Surface;
            NewNode.fDistance := 0;   // Need to contemplate the entire jump
          end;
        end
        else
          CreatedNodes.Add( Key, nil );   // We don't add airborne nodes to the list of those created so that they can be jumped across from different angles.

        PushNode( NewNode );
      end;
    end;
  end;
end;

var
  Idx, Iterations : integer;
  Node : tPathNode;
  Surface : tCubeSurface;
  JumpStartDirections : set of tCubeSurface;
begin
  fStatus := STATE_INVALID;

  fNodeList.Clear;
  ptSource.x := Floor( Source.x );
  ptSource.y := Floor( Source.y );
  ptSource.z := Floor( Source.z );
  ptTarget.x := Floor( Target.x );
  ptTarget.y := Floor( Target.y );
  ptTarget.z := Floor( Target.z );

  Width := GameState.Map.Width;
  Height := GameState.Map.Height;

  if ( ( ptSource.x = ptTarget.x ) and ( ptSource.z = ptTarget.z ) and ( not Allow3d or ( ptSource.y = ptTarget.z ) ) ) or ( ptSource.y >= MAP_SIZE_COLUMN ) then
  begin
    fNodeList.Add( tPathNode.Create( nil, ptSource ) );
    fStatus := STATE_COMPLETE;
    if GameState.SharedStateData.IsLogEnabled then
      with ptSource do
        GameState.SharedStateData.Log( LOG_PATH, 'Built single node path at [%d, %d, %d]', [ x, y, z ] );
    exit;
  end;

  Nodes := tList.Create;
  try
    OpenNodes := tStringList.Create;
    try
      OpenNodes.Sorted := true;
      OpenNodes.Duplicates := dupAccept;
      CreatedNodes := tBucketList.Create;
      try
        ActiveEntities := tList.Create;
        try
          Iterations := 0;
          JumpStartDirections := [];
          ClosestNode := tPathNode.Create( nil, ptSource );
          ClosestNode.fDistance := Distance( ptSource, ptTarget );
          PushNode( ClosestNode );
          while HasNodes and ( Iterations < MaximumIterations )do
          begin
            Node := PopNode;
            if ( Node.Distance < ClosestNode.Distance ) and not Node.Airborne then      // Can't have airborne nodes being the final destination
              ClosestNode := Node;

            GetAdjacentSurfaces( Node );
            if Allow3d then
            begin
              if Node.Airborne then
              begin
                if Node.JumpDirection = CS_TOP then   // We have just started jumping, so consider each JumpStartDirection
                begin
                  for Idx := 0 to Directions2d do
                  begin
                    Surface := CubeSurface[ Idx ];
                    if ( Surface in JumpStartDirections ) and ( ConsiderDirection( CubeSurface[ Idx ], Node, Direction[ Idx ] ) = CR_COMPLETE ) then
                      exit;
                  end;
                end
                else if ( Node.JumpDirection = CS_BOTTOM ) or ( Node.JumpCount = 0 ) then   // We are falling - only consider downwards
                begin
                  if ConsiderDirection( CS_BOTTOM, Node, Direction[ DirectionIndex[ CS_BOTTOM ] ] ) = CR_COMPLETE then
                    exit;
                end
                else          // We are flying through the air - keep looking the way we are travelling
                begin
                  if ( Node.JumpCount >= JumpLength -1 ) or ( GetBlockBeneathAirborneNode( Node ) < BLOCK_PILLAR ) then  // But first look below to see whether we can land
                  begin
                    Surface := Node.JumpDirection;    // Nope - clear space below us - keep flying laterally
                    if Node.JumpCount < JumpLength - 1 then     // Don't jump and drop down to the adjacent square
                      if ConsiderDirection( CS_BOTTOM, Node, Direction[ DirectionIndex[ CS_BOTTOM ] ] ) = CR_COMPLETE then   // Look below as well as laterally
                        exit;
                  end
                  else
                    Surface := CS_BOTTOM;     // Trigger falling mode

                  if ConsiderDirection( Surface, Node, Direction[ DirectionIndex[ Surface ] ] ) = CR_COMPLETE then
                    exit;
                end;
              end
              else
              begin
                JumpStartDirections := [];
                for Idx := 0 to Directions2d do
                begin
                  Surface := CubeSurface[ Idx ];
                  case ConsiderDirection( Surface, Node, Direction[ Idx ] ) of
                    CR_AIRBORNE, CR_IMPASSABLE:
                      include( JumpStartDirections, Surface );
                    CR_COMPLETE:
                      exit;
                  end;
                end;

                if JumpStartDirections <> [] then
                  if ConsiderDirection( CS_TOP, Node, Direction[ DirectionIndex[ CS_TOP ] ] ) = CR_COMPLETE then
                    exit;
              end;
            end
            else
              for Idx := 0 to Directions2d do
                if ConsiderDirection( CubeSurface[ Idx ], Node, Direction[ Idx ] ) = CR_COMPLETE then
                  exit;
            inc( Iterations );
          end;

          BuildPartialRoute;
        finally
          ActiveEntities.Free;
        end;
      finally
        CreatedNodes.Free;
      end;
    finally
      OpenNodes.Free;
    end;
  finally
    FreeUnusedNodes;
    Nodes.Free;
  end;
end;

function tPath.GetNode( Index : integer ) : tPathNode;
begin
  result := tPathNode( fNodeList[ NodeCount - Index - 1 ] );
end;

function tPath.GetNodeCount : integer;
begin
  result := fNodeList.Count;
end;

(* tPathNode *)

constructor tPathNode.Create( Parent : tPathNode; const Location : tIntPoint3d );
begin
  inherited Create;
  fParent := Parent;
  fLocation := Location;
end;

end.
