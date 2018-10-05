unit LightMap;

interface

uses
  Cube, Map, Geometry, Raycaster, Common, Classes;

const
  LM_GROUND    = -1;
  LM_MAPSIZE   = 32;

type
  tLightMapType = ( LM_UNDEFINED, LM_MIXED, LM_LIGHT, LM_SHADE );

  tLightBitmap = cardinal;

  pLightMapPixelData = ^tLightMapPixelData;
  tLightMapPixelData = array [ 1 .. LM_MAPSIZE * LM_MAPSIZE ] of byte;

  pLightMapPacked = ^tLightMapPacked;
  tLightMapPacked = array [ 1 .. LM_MAPSIZE ] of tLightBitmap;

  pLightMap = ^tLightMap;
  tLightMap = record
    cType : tLightMapType;
    pLightMap : pLightMapPacked;
  end;

  pLightMapData = ^tLightMapData;
  tLightMapData = array [ 0 .. MAP_SIZE_COLUMN * CUBE_SURFACES - 1 ] of tLightMap;

  tSurfaceSpecification = class( tObject )
  public
    x, y, z : integer;
    cSurface : tCubeSurface;
    bWater : boolean;
    function encode( cLightMapType : tLightMapType ) : cardinal;
    function decode( encodedSpecification : cardinal ) : tLightMapType;
  end;

  tLightMapCreator = class( tObject )
  private
    fLowQuality : boolean;
    cMap : tMap;
    ptLight : tPoint3d;
    cRaycaster : tRaycaster;
    ptOrigin, ptOuterStep, ptInnerStep, ptCursor : tPoint3d;
    ScratchMap : tLightMapPacked;
    procedure   blurLightMap( pSource, pDestination : pLightMapPacked );
  public
    constructor create;
    procedure   initialise( aMap : tMap; const ptLight : tPoint3d );
    procedure   calculateLightMap( pLM : pLightMap; Surface : tSurfaceSpecification );
    destructor  destroy; override;
    property    LowQuality : boolean read fLowQuality write fLowQuality;
  end;

  tLightMapSurfaceIterator = class;

  tLightMapManager = class( tObject )
  protected
    nLightIntensity, nShadeIntensity : byte;
    bReturnSolidLightMaps : boolean;
    bAutoGenerate : boolean;
    cMap : tMap;
    pMapData : pointer;
    pGroundMapData : pointer;
    ptLight : tPoint3d;
    cLightMapCreator : tLightMapCreator;
    nMaximumComputationTime : cardinal;
    nCurrentComputationTime, nPerformanceFrequency : int64;
    MapWidth, MapHeight : integer;
    procedure   cleanUp;
    procedure   clearLightMaps;
    procedure   clearGroundLightMaps;
    procedure   freeLightMap( pLM : pLightMapData );
    procedure   generatePixelData( pLM : pLightMap; pPixelData : pLightMapPixelData; bInvert : boolean );
    function    getLightMap( Surface : tSurfaceSpecification ) : pLightMap;
    function    getLightMapData( x, z : integer ) : pLightMapData;
    function    getLowQuality : boolean;
    function    getGroundLightMap( x, z : integer ) : pLightMap;
    function    getSurfaceIndex( y : integer; cSurface : tCubeSurface ) : integer;
    procedure   setLowQuality( LowQuality : boolean );
    procedure   unpackLightMapData( Stream : tStream );
  public
    constructor create;
    procedure   initialise( aMap : tMap );
    procedure   iterateSurfaces( Iterator : tLightMapSurfaceIterator );
    function    getLightMapPixelData( Surface : tSurfaceSpecification; pPixelData : pLightMapPixelData ) : tLightMapType;
    procedure   setLightPosition( ptLight : tPoint3d );
    procedure   setLightSphericalPosition( const Position : tSphericalCoordinate );
    procedure   packLightMapData( Stream : tStream );
    procedure   prepareLevelLightMap( Level : integer; ForceBuild : boolean );
    procedure   resetComputationTime;
    destructor  destroy; override;
    property    AutoGenerate : boolean read bAutoGenerate write bAutoGenerate;
    property    LightIntensity : byte read nLightIntensity write nLightIntensity;
    property    LightPosition : tPoint3d read ptLight write setLightPosition;
    property    LowQuality : boolean read GetLowQuality write SetLowQuality;
    property    ReturnSolidLightMaps : boolean read bReturnSolidLightMaps write bReturnSolidLightMaps;
    property    ShadeIntensity : byte read nShadeIntensity write nShadeIntensity;
    property    MaximumComputationTime : cardinal read nMaximumComputationTime write nMaximumComputationTime;  // Milliseconds
  end;

  tLightMapSurfaceIterator = class( tObject )
  private
    OldMaximumComputationTime : cardinal;
    OldAutoGenerate : boolean;
    cLightMapManager : tLightMapManager;
  protected
    property    LightMapManager : tLightMapManager read cLightMapManager;
  public
    constructor Create( cLightMapManager : tLightMapManager );
    destructor  Destroy; override;
    function    visitSurface( cSurface : tSurfaceSpecification ) : boolean; virtual; abstract;
  end;

  tBuildLightMapSurfaceIterator = class( tLightMapSurfaceIterator )
  public
    function visitSurface( cSurface : tSurfaceSpecification ) : boolean; override;
  end;

  tPackLightMapSurfaceIterator = class( tLightMapSurfaceIterator )
  private
    Stream : tStream;
  public
    constructor Create( cLightMapManager : tLightMapManager; Stream : tStream );
    function visitSurface( cSurface : tSurfaceSpecification ) : boolean; override;
  end;

implementation

uses
  Windows, SysUtils;

(* tSurfaceSpecification *)

// x = 0 - 11; z = 12 - 23; y = 24 - 26; Surface = 27 - 29; LightMapType = 30 - 31

function tSurfaceSpecification.encode( cLightMapType : tLightMapType ) : cardinal;
var
  ty : cardinal;
  ts : tCubeSurface;
begin
  if y > LM_GROUND then
  begin
    ty := cardinal( y );
    ts := cSurface;
  end
  else
  begin
    ty := 0;
    ts := CS_BOTTOM;
  end;

  result := Ord( cLightMapType );
  result := result shl 3;
  result := result or cardinal( ts );
  result := result shl 3;
  result := result or ty;
  result := result shl 12;
  result := result or cardinal( z );
  result := result shl 12;
  result := result or cardinal( x );
end;

function tSurfaceSpecification.decode( encodedSpecification : cardinal ) : tLightMapType;
begin
  x := encodedSpecification and $fff;
  encodedSpecification := encodedSpecification shr 12;
  z := encodedSpecification and $fff;
  encodedSpecification := encodedSpecification shr 12;
  y := encodedSpecification and $7;
  encodedSpecification := encodedSpecification shr 3;
  cSurface := tCubeSurface( encodedSpecification and $7 );
  encodedSpecification := encodedSpecification shr 3;
  result := tLightMapType( encodedSpecification and $3 );

  if ( y = 0 ) and ( cSurface = CS_BOTTOM ) then
  begin
    y := LM_GROUND;
    cSurface := CS_TOP;
  end;
end;

(* tLightMapCreator *)

constructor tLightMapCreator.create;
begin
  inherited;
  cRaycaster := tRaycaster.create;
  ptOrigin := tPoint3d.create;
  ptOuterStep := tPoint3d.create;
  ptInnerStep := tPoint3d.create;
  ptCursor := tPoint3d.create;
end;

destructor tLightMapCreator.destroy;
begin
  ptCursor.Free;
  ptInnerStep.Free;
  ptOuterStep.Free;
  ptOrigin.Free;
  cRaycaster.Free;
  inherited;
end;

procedure tLightMapCreator.initialise( aMap : tMap; const ptLight : tPoint3d );
begin
  cMap := aMap;
  Self.ptLight := ptLight;
end;

procedure tLightMapCreator.blurLightMap( pSource, pDestination : pLightMapPacked );
const
  Weights : array [ -4 .. 4 ] of _float = ( 0.707, 1.0, 0.707, 1.0, 1.0, 1.0, 0.707, 1.0, 0.707 );

function GetValue( i, j : integer ) : _float;
var
  pScan : ^tLightBitmap;
  Mask : tLightBitmap;
begin
  pScan := pointer( pSource );
  inc( pScan, j - 1 );
  Mask := 1 shl ( i - 1 );
  if ( pScan^ and Mask ) <> 0 then
    result := 1
  else
    result := 0;
end;

procedure SetValue( i, j : integer; Value : _float );
var
  pScan : ^tLightBitmap;
  Mask : tLightBitmap;
begin
  pScan := pointer( pDestination );
  inc( pScan, ( j - 1 ) );
  Mask := 1 shl ( i - 1 );
  pScan^ := pScan^ and not Mask;
  if Value >= 0.25 then
    pScan^ := pScan^ or Mask;
end;

var
  i, j, x, y : integer;
  Value : _float;
begin
  for j := 1 to LM_MAPSIZE do
  begin
    for i := 1 to LM_MAPSIZE do
    begin
      if ( i > 1 ) and ( i < LM_MAPSIZE ) and ( j > 1 ) and ( j < LM_MAPSIZE ) then
      begin
        Value := 0;
        for y := -1 to 1 do
          for x := -1 to 1 do
            Value := Value + GetValue( i + x, j + y ) * Weights[ y * 3 + x ];
        Value := Value / 9;
      end
      else
        Value := GetValue( i, j );
      SetValue( i, j, Value );
    end;
  end;
end;

procedure tLightMapCreator.calculateLightMap( pLM : pLightMap; Surface : tSurfaceSpecification );
const
  Movement : array [ tCubeSurface, 0 .. 2, 0 .. 2 ] of integer = (
      // Offset     Outer Step    Inner Step
    ( ( 0, 1, 0 ), ( 0, -1, 0 ), ( 0, 0,  1 ) ),  // Left
    ( ( 1, 1, 1 ), ( 0, -1, 0 ), ( 0, 0, -1 ) ),  // Right
    ( ( 1, 1, 0 ), ( -1, 0, 0 ), ( 0, 0,  1 ) ),  // Top
    ( ( 0, 0, 0 ), (  1, 0, 0 ), ( 0, 0,  1 ) ),  // Bottom
    ( ( 1, 1, 0 ), ( 0, -1, 0 ), ( -1, 0, 0 ) ),  // Near
    ( ( 0, 1, 1 ), ( 0, -1, 0 ), ( 1, 0,  0 ) )   // Far
  );

  Scale = 1.0 / LM_MAPSIZE;

  SolidCount = LM_MAPSIZE * LM_MAPSIZE;

  LowQualityFactor = 4;

var
  Vector : pIntegerArray;
  i, j : integer;
  b : tLightBitmap;
  LightCount, ShadeCount : integer;
  Mask : tLightBitmap;
  pScan : ^tLightBitmap;
  Lit : boolean;
  SampleFactor : integer;

begin
  if ptLight.y < 0 then
  begin
    pLM^.cType := LM_SHADE;
    exit;
  end;

  Vector := @Movement[ Surface.cSurface, 1 ];
  ptOuterStep.setLocation( Vector^[ 0 ], Vector^[ 1 ], Vector^[ 2 ] );
  ptOuterStep.scale( Scale );

  Vector := @Movement[ Surface.cSurface, 2 ];
  ptInnerStep.setLocation( Vector^[ 0 ], Vector^[ 1 ], Vector^[ 2 ] );
  ptInnerStep.scale( Scale );

  Vector := @Movement[ Surface.cSurface, 0 ];
  ptOrigin.setLocation( ptOuterStep );
  ptOrigin.translate( ptInnerStep );
  ptOrigin.scale( 0.5 );
  ptOrigin.translate( Surface.x + Vector^[ 0 ], Surface.y + Vector^[ 1 ], Surface.z + Vector^[ 2 ] );

  if Surface.bWater then
    ptOrigin.y := ptOrigin.y - WATER_OFFSET;

  LightCount := 0;
  ShadeCount := 0;
  pScan := @ScratchMap;

  if LowQuality then
  begin
    SampleFactor := LowQualityFactor;
    Mask := 0;
    for j := 1 to LM_MAPSIZE do
    begin
      if ( j mod LowQualityFactor ) = 1 then
      begin
        Lit := false;
        Mask := 0;
        b := 1;
        ptCursor.setLocation( ptOrigin );
        for i := 1 to LM_MAPSIZE do
        begin
          if ( i mod LowQualityFactor ) = 1 then
            Lit := cRaycaster.traceRay( cMap, ptCursor, ptLight );
          if Lit then
          begin
            Mask := Mask or b;
            inc( LightCount );
          end
          else
            inc( ShadeCount );
          ptCursor.translate( ptInnerStep );
          b := b shl 1;
        end;
      end;
      ptOrigin.translate( ptOuterStep );
      pScan^ := Mask;
      inc( pScan );
    end;
  end
  else
  begin
    SampleFactor := 1;
    for j := 1 to LM_MAPSIZE do
    begin
      Mask := 0;
      b := 1;
      ptCursor.setLocation( ptOrigin );
      for i := 1 to LM_MAPSIZE do
      begin
        if cRaycaster.traceRay( cMap, ptCursor, ptLight ) then
        begin
          Mask := Mask or b;
          inc( LightCount );
        end
        else
          inc( ShadeCount );
        ptCursor.translate( ptInnerStep );
        b := b shl 1;
      end;
      ptOrigin.translate( ptOuterStep );
      pScan^ := Mask;
      inc( pScan );
    end;
  end;

  if LightCount * SampleFactor = SolidCount then
    pLM^.cType := LM_LIGHT
  else if ShadeCount * SampleFactor = SolidCount then
    pLM^.cType := LM_SHADE
  else
  begin
    pLM^.cType := LM_MIXED;
    GetMem( pLM^.pLightMap, SizeOf( ScratchMap ) );
    if LowQuality then
      BlurLightmap( @ScratchMap, pLM^.pLightMap )
    else
      Move( ScratchMap, pLM^.pLightMap^, SizeOf( ScratchMap ) );
  end;
end;

(* Constructor *)

constructor tLightMapManager.create;
begin
  inherited;
  ptLight := tPoint3d.create;
  cLightMapCreator := tLightMapCreator.create;
  nLightIntensity := 0;
  nShadeIntensity := 128;
  QueryPerformanceFrequency( nPerformanceFrequency );
  MaximumComputationTime := 100;
end;

(* Protected Methods *)

procedure tLightMapManager.cleanUp;
begin
  if pGroundMapData <> nil then
  begin
    clearGroundLightMaps;
    FreeMem( pGroundMapData );
    pGroundMapData := nil;
  end;
  if pMapData <> nil then
  begin
    clearLightMaps;
    freeMem( pMapData );
    pMapData := nil;
  end;
end;

procedure tLightMapManager.clearLightMaps;
var
  x, z : integer;
  pLM : ^pLightMapData;
begin
  pLM := pMapData;
  for z := 1 to MapHeight do
    for x := 1 to MapWidth do
    begin
      if pLM^ <> nil then
      begin
        freeLightMap( pLM^ );
        pLM^ := nil;
      end;
      inc( pLM );
    end;
end;

procedure tLightMapManager.clearGroundLightMaps;
var
  x, z : integer;
  pLM : pLightMap;
begin
  pLM := pGroundMapData;
  for z := 1 to MapHeight do
    for x := 1 to MapWidth do
    begin
      if pLM^.pLightMap <> nil then
      begin
        FreeMem( pLM^.pLightMap );
        pLM^.pLightMap := nil;
      end;
      pLM^.cType := LM_UNDEFINED;
      inc( pLM );
    end;
end;

procedure tLightMapManager.freeLightMap( pLM : pLightMapData );
var
  Idx : integer;
  pLightMap : pLightMapPacked;
begin
  for Idx := low( pLM^ ) to high( pLM^ ) do
  begin
    pLightMap := pLM^[ Idx ].pLightMap;
    if pLightMap <> nil then
      FreeMem( pLightMap );
  end;
  FreeMem( pLM );
end;

procedure tLightMapManager.generatePixelData( pLM : pLightMap; pPixelData : pLightMapPixelData; bInvert : boolean );
var
  x, y : integer;
  nIntensity, nLightIntensity, nShadeIntensity : byte;
  Intensity : array [ 0 .. 1 ] of byte;
  pScan : ^Byte;
  pLMScan : ^tLightBitmap;
  cBitmap : tLightBitmap;
begin
  if bInvert then
  begin
    nLightIntensity := 255 - Self.nLightIntensity;
    nShadeIntensity := 255 - Self.nShadeIntensity;
  end
  else
  begin
    nLightIntensity := Self.nLightIntensity;
    nShadeIntensity := Self.nShadeIntensity;
  end;

  if pLM^.cType = LM_MIXED then
  begin
    Intensity[ 0 ] := nShadeIntensity;
    Intensity[ 1 ] := nLightIntensity;
    pLMScan := Pointer( pLM^.pLightMap );
    pScan := pointer( pPixelData );
    for y := 1 to LM_MAPSIZE do
    begin
      cBitmap := pLMScan^;
      for x := 1 to LM_MAPSIZE do
      begin
        pScan^ := Intensity[ cBitmap and 1 ];
        cBitmap := cBitmap shr 1;
        inc( pScan );
      end;
      inc( pLMScan );
    end;
  end
  else
    if bReturnSolidLightMaps then
    begin
      if pLM^.cType = LM_LIGHT then
        nIntensity := nLightIntensity
      else
        nIntensity := nShadeIntensity;
      fillChar( pPixelData^, sizeOf( tLightMapPixelData ), nIntensity );
    end;
end;

function tLightMapManager.getLightMap( Surface : tSurfaceSpecification ) : pLightMap;
var
  pLM : pLightMap;
  pLMData : pLightMapData;
  nSurfaceIndex : integer;
  nTime : array [ 0 .. 1 ] of int64;
begin
  with Surface do
  begin
    if Y > LM_GROUND then
    begin
      nSurfaceIndex := getSurfaceIndex( y, cSurface );
      pLMData := getLightMapData( x, z );
      pLM := @pLMData^[ nSurfaceIndex ];
    end
    else
    begin
      pLM := getGroundLightMap( x, z );
      y := LM_GROUND;
      cSurface := CS_TOP;
    end;
    if ( pLM^.cType = LM_UNDEFINED ) and AutoGenerate then
    begin
      if ( nMaximumComputationTime = 0 ) or ( nCurrentComputationTime < ( nMaximumComputationTime * nPerformanceFrequency div 1000 ) ) then
      begin
        QueryPerformanceCounter( nTime[ 0 ] );
        cLightMapCreator.calculateLightMap( pLM, Surface );
        QueryPerformanceCounter( nTime[ 1 ] );
        inc( nCurrentComputationTime, nTime[ 1 ] - nTime[ 0 ] );
      end;
    end;
  end;
  result := pLM;
end;

function tLightMapManager.getLightMapData( x, z : integer ) : pLightMapData;
var
  pLightMapDataScan : ^pLightMapData;
begin
  pLightMapDataScan := pMapData;
  inc( pLightMapDataScan, z * cMap.Width + x );
  if pLightMapDataScan^ = nil then
    pLightMapDataScan^ := AllocMem( SizeOf( tLightMapData ) );
  result := pLightMapDataScan^;
end;

function tLightMapManager.getGroundLightMap( x, z : integer ) : pLightMap;
begin
  result := pGroundMapData;
  inc( result, z * cMap.Width + x );
end;

function tLightMapManager.getLowQuality : boolean;
begin
  result := cLightMapCreator.LowQuality;
end;

function tLightMapManager.getSurfaceIndex( y : integer; cSurface : tCubeSurface ) : integer;
begin
  result := y * CUBE_SURFACES + ord( cSurface )
end;

procedure tLightMapManager.setLowQuality( LowQuality : boolean );
begin
  cLightMapCreator.LowQuality := LowQuality;
end;

procedure tLightMapManager.unpackLightMapData( Stream : tStream );
var
  Surface : tSurfaceSpecification;
  EncodedSurface : cardinal;
  LightMapType : tLightMapType;
  pLM : pLightMap;
begin
  clearLightMaps;
  clearGroundLightMaps;
  Surface := tSurfaceSpecification.Create;
  try
    while Stream.Position < Stream.Size do
    begin
      Stream.Read( EncodedSurface, SizeOf( Cardinal ) );
      LightMapType := Surface.decode( EncodedSurface );

      if Surface.y > LM_GROUND then
        pLM := @getLightMapData( Surface.x, Surface.z )^[ getSurfaceIndex( Surface.y, Surface.cSurface ) ]
      else
        pLM := getGroundLightMap( Surface.x, Surface.z );

      pLM^.cType := LightMapType;
      if LightMapType = LM_MIXED then
      begin
        if pLM^.pLightMap = nil then
          GetMem( pLM^.pLightMap, SizeOf( tLightMapPacked ) );
        Stream.Read( pLM^.pLightMap^, SizeOf( tLightMapPacked ) );
      end;
    end;
  finally
    Surface.Free;
  end;
end;

(* Public Methods *)

procedure tLightMapManager.initialise( aMap : tMap );
begin
  cleanUp;
  cMap := aMap;
  MapWidth := cMap.Width;
  MapHeight := cMap.Height;
  pMapData := allocMem( MapWidth * MapHeight * sizeOf( pLightMapData ) );
  pGroundMapData := AllocMem( MapWidth * MapHeight * SizeOf( tLightMap ) );
end;

procedure tLightMapManager.iterateSurfaces( Iterator : tLightMapSurfaceIterator );
var
  Surface : tSurfaceSpecification;
  SurfaceLoop : tCubeSurface;
  AdjacentBlocks : tAdjacentBlocks;
  EmptyColumn : boolean;
  BlockType : tBlockType;
begin
  Surface := tSurfaceSpecification.Create;
  try
    with Surface do
      repeat
        x := 0;
        repeat
          EmptyColumn := cMap.Column[ x, z ] = 0;
          if EmptyColumn or ( cMap.Block[ x, 0, z ] < BLOCK_PILLAR ) then
          begin
            y := LM_GROUND;
            cSurface := CS_TOP;
            bWater := false;
            if not Iterator.visitSurface( Surface ) then
              exit;
          end;
          if not EmptyColumn then
          begin
            y := 0;
            repeat
              BlockType := cMap.Block[ x, y, z ];
              if BlockType = BLOCK_SOLID then
              begin
                bWater := false;
                cMap.getAdjacentBlocks( x, y, z, AdjacentBlocks );
                for SurfaceLoop := Low( tCubeSurface ) to High( tCubeSurface ) do
                  if AdjacentBlocks[ SurfaceLoop ] <> BLOCK_SOLID then
                  begin
                    cSurface := SurfaceLoop;
                    if not Iterator.visitSurface( Surface ) then
                      exit;
                  end;
              end
              else if BlockType = BLOCK_WATER then
              begin
                cMap.getAdjacentBlocks( x, y, z, AdjacentBlocks );
                if AdjacentBlocks[ CS_TOP ] <> BLOCK_WATER then
                begin
                  cSurface := CS_TOP;
                  bWater := true;
                  if not Iterator.visitSurface( Surface ) then
                    exit;
                end;
              end;
              inc( y );
            until y = MAP_SIZE_COLUMN;
          end;
          inc( x );
        until x = cMap.Width;
        inc( z );
      until z = cMap.Height;
  finally
    Surface.Free;
  end;
end;

function tLightMapManager.getLightMapPixelData( Surface : tSurfaceSpecification; pPixelData : pLightMapPixelData ) : tLightMapType;
var
  pLM : pLightMap;
begin
  pLM := getLightMap( Surface );
  if pLM^.cType <> LM_UNDEFINED then
    generatePixelData( pLM, pPixelData, Surface.bWater );
  result := pLM^.cType;
end;

procedure tLightMapManager.setLightPosition( ptLight : tPoint3d );
begin
  if not self.ptLight.equals( ptLight ) then
  begin
    self.ptLight.setLocation( ptLight );
    clearLightMaps;
    clearGroundLightMaps;
    cLightMapCreator.initialise( cMap, self.ptLight );
  end;
end;

procedure tLightMapManager.setLightSphericalPosition( const Position : tSphericalCoordinate );
var
  ptLight : tPoint3d;
begin
  ptLight := tPoint3d.create( cMap.Width / 2, 10000, cMap.Height / 2 );
  try
    ptLight.rotateZ( Position.Longitude );
    ptLight.rotateX( Position.Latitude );
    setLightPosition( ptLight );
  finally
    ptLight.Free;
  end;
end;

procedure tLightMapManager.packLightMapData( Stream : tStream );
var
  LightMapPacker : tPackLightMapSurfaceIterator;
begin
  LightMapPacker := tPackLightMapSurfaceIterator.Create( Self, Stream );
  try
    iterateSurfaces( LightMapPacker );
  finally
    LightMapPacker.Free;
  end;
end;

procedure tLightMapManager.prepareLevelLightMap( Level : integer; ForceBuild : boolean );
var
  LightMapBuilder : tBuildLightMapSurfaceIterator;
  Stream : tStream;
begin
  if ( Level > 0 ) and ( Level <= cMap.Header^.Levels ) then
  begin
    with cMap.Level[ Level ] do
    begin
      setLightSphericalPosition( Info.LightPosition );
      if LightMapData <> nil then
      begin
        Stream := tAllocatedMemoryStream.Create( LightMapData, LightMapSize );
        try
          unpackLightMapData( Stream );
        finally
          Stream.Free;
        end;
      end
      else if ForceBuild then
      begin
        LightMapBuilder := tBuildLightMapSurfaceIterator.Create( Self );
        try
          iterateSurfaces( LightMapBuilder );
        finally
          LightMapBuilder.Free;
        end;
      end;
    end;
  end;
end;

procedure tLightMapManager.resetComputationTime;
begin
  nCurrentComputationTime := 0;
end;

(* Destructor *)

destructor tLightMapManager.destroy;
begin
  cLightMapCreator.Free;
  ptLight.free;
  cleanUp;
  inherited;
end;

(* tLightMapSurfaceIterator *)

constructor tLightMapSurfaceIterator.create( cLightMapManager : tLightMapManager );
begin
  inherited Create;
  Self.cLightMapManager := cLightMapManager;
  OldMaximumComputationTime := cLightMapManager.MaximumComputationTime;
  OldAutoGenerate := cLightMapManager.AutoGenerate;
  cLightMapManager.MaximumComputationTime := 0;
  cLightMapManager.AutoGenerate := true;
end;

destructor tLightMapSurfaceIterator.destroy;
begin
  cLightMapManager.AutoGenerate := OldAutoGenerate;
  cLightMapManager.MaximumComputationTime := OldMaximumComputationTime;
  inherited;
end;

(* tBuildLightMapSurfaceIterator *)

function tBuildLightMapSurfaceIterator.visitSurface( cSurface : tSurfaceSpecification ) : boolean;
begin
  cLightMapManager.getLightMap( cSurface );
  result := true;
end;

(* tPackLightMapSurfaceIterator *)

constructor tPackLightMapSurfaceIterator.create( cLightMapManager : tLightMapManager; Stream : tStream );
begin
  inherited Create( cLightMapManager );
  Self.Stream := Stream;
end;

function tPackLightMapSurfaceIterator.visitSurface( cSurface : tSurfaceSpecification ) : boolean;
var
  pLM : pLightMap;
  SurfaceEncoded : cardinal;
begin
  pLM := cLightMapManager.getLightMap( cSurface );
  SurfaceEncoded := cSurface.encode( pLM^.cType );
  Stream.Write( SurfaceEncoded, SizeOf( SurfaceEncoded ) );
  if pLM^.cType = LM_MIXED then
    Stream.Write( pLM^.pLightMap^, SizeOf( tLightMapPacked ) );
  result := true;
end;

end.
