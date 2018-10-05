unit Raycaster;

interface

uses
  Map, Geometry;

type
  tRaycaster = class( tObject )
  private
    cUnitStep : tPoint3d;
    cStep : tPoint3d;
    cRayNormal : tPoint3d;
    cCursor : tPoint3d;
  public
    constructor create;
    destructor  destroy; override;
    function    traceRay( cMap : tMap; Start, Finish : tPoint3d; Intersection : tPoint3d = nil; StopOnSolid : boolean = true ) : boolean;
  end;

implementation

uses
  Math;

constructor tRaycaster.create;
begin
  inherited;
  cUnitStep := tPoint3d.Create;
  cStep := tPoint3d.Create;
  cRayNormal := tPoint3d.Create;
  cCursor := tPoint3d.Create;
end;

destructor tRaycaster.destroy;
begin
  cCursor.Free;
  cRayNormal.Free;
  cStep.Free;
  cUnitStep.Free;
  inherited;
end;

function tRaycaster.traceRay( cMap : tMap; Start, Finish : tPoint3d; Intersection : tPoint3d; StopOnSolid : boolean ) : boolean;
type
  tEdge = record
    x, z : integer;
    Horizontal : boolean;
  end;

const
  EPSILON = 0.001;

  NONTANT_VISIBILITY : array [ 0 .. 8, 0 .. 8 ] of boolean = (
    ( true, true, true, true, false, false, true, false, false ),       // Top-left
    ( true, true, true, false, false, false, false, false, false ),     // Top
    ( true, true, true, false, false, true, false, false, true ),       // Top-right
    ( true, false, false, true, false, false, true, false, false ),     // Left
    ( false, false, false, false, false, false, false, false, false ),  // Centre
    ( false, false, true, false, false, true, false, false, true ),     // Right
    ( true, false, false, true, false, false, true, true, true ),       // Bottom-left
    ( false, false, false, false, false, false, true, true, true ),     // Bottom
    ( false, false, true, false, false, true, true, true, true )        // Bottom-right
  );

  EDGES : array [ 0 .. 3 ] of tEdge = (
    ( x:0; z:0; Horizontal:true ),
    ( x:1; z:0; Horizontal:false ),
    ( x:0; z:1; Horizontal:true ),
    ( x:0; z:0; Horizontal:false )
  );

var
  Difference : _float;
  StepFactor : _float;
  pBlockData : pBlockArray;
  Block : tBlock;
  x, y, z : integer;
  xo, yo, zo : integer;
  w, h : integer;
  Steps : integer;
  Axis : integer;
  DoAxis, ReachTarget : boolean;
  CurrentIntersection : _float;
  ClosestIntersection : _float;
  StartNontant, FinishNontant : integer;

function CalculateNontant( Point : tPoint3d ) : integer;
begin
  if Point.x < 0 then
    result := 0
  else if Point.x >= w then
    result := 2
  else
    result := 1;

  if Point.z >= h then
    inc( result, 6 )
  else if Point.z >= 0 then
    inc( result, 3 );
end;

function PrepareXTrace : boolean;
begin
  result := false;
  Difference := Finish.x - Start.x;
  if Abs( Difference ) > EPSILON then
  begin
    Steps := Trunc( Finish.x ) - Trunc( Start.x );
    if Difference < 0 then
    begin
      cUnitStep.x := -1;
      xo := -1;
      Steps := -Steps;
    end
    else
      cUnitStep.x := 1;

    if ( Sign( Start.x ) <> Sign( Finish.x ) ) and ( Start.x <> 0 ) and ( Finish.x <> 0 ) then
      inc( Steps );

    if Sign( Start.x ) <> Sign( cUnitStep.x ) then
      cStep.x := Floor( Start.x ) - Start.x
    else
      cStep.x := Ceil( Start.x ) - Start.x;
    StepFactor := cStep.x / cRayNormal.x;
    cStep.y := cRayNormal.y * StepFactor;
    cStep.z := cRayNormal.z * StepFactor;

    StepFactor := cUnitStep.x / cRayNormal.x;
    cUnitStep.y := cRayNormal.y * StepFactor;
    cUnitStep.z := cRayNormal.z * StepFactor;
    result := true;
  end;
end;

function PrepareYTrace : boolean;
begin
  result := false;
  Difference := Finish.y - Start.y;
  if Abs( Difference ) > EPSILON then
  begin
    Steps := Trunc( Finish.y ) - Trunc( Start.y );
    if Difference < 0 then
    begin
      cUnitStep.y := -1;
      yo := -1;
      Steps := -Steps;
    end
    else
      cUnitStep.y := 1;

    if ( Sign( Start.y ) <> Sign( Finish.y ) ) and ( Start.y <> 0 ) and ( Finish.y <> 0 ) then
      inc( Steps );

    if Sign( Start.y ) <> Sign( cUnitStep.y ) then
      cStep.y := Floor( Start.y ) - Start.y
    else
      cStep.y := Ceil( Start.y ) - Start.y;
    StepFactor := cStep.y / cRayNormal.y;
    cStep.x := cRayNormal.x * StepFactor;
    cStep.z := cRayNormal.z * StepFactor;

    StepFactor := cUnitStep.y / cRayNormal.y;
    cUnitStep.x := cRayNormal.x * StepFactor;
    cUnitStep.z := cRayNormal.z * StepFactor;
    result := true;
  end;
end;

function PrepareZTrace : boolean;
begin
  result := false;
  Difference := Finish.z - Start.z;
  if Abs( Difference ) > EPSILON then
  begin
    Steps := Trunc( Finish.z ) - Trunc( Start.z );
    if Difference < 0 then
    begin
      cUnitStep.z := -1;
      zo := -1;
      Steps := -Steps;
    end
    else
      cUnitStep.z := 1;

    if ( Sign( Start.z ) <> Sign( Finish.z ) ) and ( Start.z <> 0 ) and ( Finish.z <> 0 ) then
      inc( Steps );

    if Sign( Start.z ) <> Sign( cUnitStep.z ) then
      cStep.z := Floor( Start.z ) - Start.z
    else
      cStep.z := Ceil( Start.z ) - Start.z;
    StepFactor := cStep.z / cRayNormal.z;
    cStep.x := cRayNormal.x * StepFactor;
    cStep.y := cRayNormal.y * StepFactor;

    StepFactor := cUnitStep.z / cRayNormal.z;
    cUnitStep.x := cRayNormal.x * StepFactor;
    cUnitStep.y := cRayNormal.y * StepFactor;
    result := true;
  end;
end;

function CalculateEdgeIntersection( const Edge : tEdge; Intersection : tPoint3d ) : boolean;
var
  e, i : _float;
begin
  result := false;
  if Edge.Horizontal then
  begin
    e := Edge.z * h - Start.z;
    i := Start.x + ( e * cRayNormal.x / cRayNormal.z );
    if ( i >= 0 ) and ( i < w ) then
    begin
      Intersection.setLocation( i, Start.y + ( e * cRayNormal.y / cRayNormal.z ), Edge.z * h );
      result := true;
    end;
  end
  else
  begin
    e := Edge.x * w - Start.x;
    i := Start.z + ( e * cRayNormal.z / cRayNormal.x );
    if ( i >= 0 ) and ( i < h ) then
    begin
      Intersection.setLocation( Edge.x * w, Start.y + ( e * cRayNormal.y / cRayNormal.x ), i );
      result := true;
    end;
  end;
end;

begin
  result := true;
  DoAxis := false;
  pBlockData := cMap.BlockData;

  cRayNormal.setLocation( Finish );
  cRayNormal.subtract( Start );
  cRayNormal.normalise;

  w := cMap.Width;
  h := cMap.Height;

  ClosestIntersection := -1;
  Intersection := nil;

  try
    StartNontant := CalculateNontant( Start );
    if StartNontant <> 4 then   // Start Point is outside of the map
    begin
      FinishNontant := CalculateNontant( Finish );
      if NONTANT_VISIBILITY[ StartNontant, FinishNontant ] then   // Start and Finish cannot be obstructed
        exit;

      Intersection := tPoint3d.Create;
      Axis := 0;
      repeat
        if CalculateEdgeIntersection( EDGES[ Axis ], Intersection ) then
          break;
        inc( Axis );
      until Axis = 4;
      if Axis = 4 then    // The line does not cross the map and must intersect
        exit;

      Start := Intersection;
    end;

    for Axis := 1 to 3 do
    begin
      xo := 0;
      yo := 0;
      zo := 0;
      case Axis of
        1:
          DoAxis := PrepareXTrace;
        2:
          DoAxis := PrepareYTrace;
        3:
          DoAxis := PrepareZTrace;
      end;

      if not DoAxis then
        Continue;

      ReachTarget := true;
      cCursor.setLocation( Start );
      cCursor.translate( cStep );
      repeat
        x := Floor( cCursor.x ) + xo;
        y := Floor( cCursor.y ) + yo;
        z := Floor( cCursor.z ) + zo;
        if ( x >= 0 ) and ( x < w ) and ( z >= 0 ) and ( z < h ) and ( Steps > 0 ) then
        begin
          if y >= 0 then
          begin
            if y < MAP_SIZE_COLUMN then
            begin
              Block := pBlockData^[ z * w + x ];
              if ( tBlockType( ( Block shr ( y * 2 ) ) and 3 ) < BLOCK_PILLAR ) = StopOnSolid then
              begin
                cCursor.translate( cUnitStep );
                dec( Steps );
              end
              else
              begin
                ReachTarget := false;
                break;
              end;
            end
            else
              break;
          end
          else
          begin
            ReachTarget := false;
            break;
          end;
        end
        else
          break;
      until false;

      if not ReachTarget then
      begin
        result := false;
        if Intersection <> nil then
        begin
          CurrentIntersection := Start.distanceSq( cCursor );
          if ( ClosestIntersection < 0 ) or ( CurrentIntersection < ClosestIntersection ) then
          begin
            ClosestIntersection := CurrentIntersection;
            Intersection.setLocation( cCursor );
          end;
        end
        else
          break;
      end;
    end;
  finally
    Intersection.Free;
  end;
end;

end.
