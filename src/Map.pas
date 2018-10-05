unit Map;

interface

uses
  Classes, Colour, Common, Cube, Geometry, Graphics, Types;

const
  MAP_SIZE_DEF      = 128;
  MAP_SIZE_MIN      = 16;
  MAP_SIZE_MAX      = 1024;
  MAP_SIZE_TITLE    = 63;
  MAP_SIZE_COLUMN   = 8;

  MAP_EXTENSION     = '.map';

  MAP_FLAG_1ST_PERSON_ONLY = 1;

  OPT_DEF_HITPOINTS = 10;
  OPT_DEF_ANT_HITPOINTS = 10;
  OPT_DEF_GRENADES  = 20;
  OPT_DEF_TIMELIMIT = 1000;
  OPT_DEF_LEVELS    = 10;

  PAL_DEF_GROUND    = $0080FFFF;
  PAL_DEF_LIGHT     = $00C0F0FF;
  PAL_DEF_WATER     = $00FFFF20;
  PAL_DEF_DARK      = $0080C0F0;
//  PAL_DEF_MEDIUM    = $00A0E0FF;

  WATER_OFFSET = 0.3;     // Distance from top of block of surface water

type
  tThingType = ( THING_SPAWN, THING_RESCUEE, THING_START, THING_ANT );

  pThingInfo = ^tThingInfo;
  tThingInfo = Record
    LevelMask : Int64;
    ThingType : tThingType;
    Position  : tIntPoint3d;
    Orientation : _float;
  End;

  tThing = Class(tObject)
  public
    Info : tThingInfo;
  End;

  tExportFormat = ( EXF_PACKED_WORD, EXF_BYTE_PER_BLOCK, EXF_WORD_PER_BLOCK, EXF_STL_TEXT, EXF_STL_BINARY );

  tRawExportOptions = record
    Title      : boolean;
    Dimensions : boolean;
  end;

  tStlExportOptions = record
    GroundPlane: boolean;
    Scale : _float;
    Area : tRect;
  end;

  tExportOptions = record
    nFormat     : tExportFormat;
    RawOptions  : tRawExportOptions;
    StlOptions  : tStlExportOptions;
  end;

  tPalette = ( PAL_GROUND, PAL_LIGHT, PAL_WATER, PAL_DARK );

  tBlockType = ( BLOCK_EMPTY, BLOCK_WATER, BLOCK_PILLAR, BLOCK_SOLID );   // 8-03

  tBlock = Word;
  pBlock = ^tBlock;

  pBlockArray = ^tBlockArray;
  tBlockArray = Array [0..MAP_SIZE_MAX * MAP_SIZE_MAX] Of tBlock;

  pAdjacentBlocks = ^tAdjacentBlocks;
  tAdjacentBlocks = array [ tCubeSurface ] of tBlockType;

  pMapHeader = ^tMapHeader;
  tMapHeader = Record
    Magic     : LongInt;
    Width     : SmallInt;
    Height    : SmallInt;
    Grenades  : SmallInt;
    HitPoints : SmallInt;
    AntHitPoints : SmallInt;
    Levels    : Byte;
    Flags     : Byte;
    ThingCount: SmallInt;
    Palette   : Array [tPalette] Of tColour;
    Title     : Array [0..MAP_SIZE_TITLE] Of Char;
  End;

  pMapLevelInfo = ^tMapLevelInfo;
  tMapLevelInfo = record
    Magic : longint;
    Level : byte;
    DrawDistance : byte;
    AntCount : byte;
    SpawnInterval : byte;
    LightPosition : tSphericalCoordinate;
    LightMapSize : integer;
  end;

  tMapLevel = class( tObject )
  private
    fLightMapData : pointer;
    function   GetLightMapSize : cardinal;
  public
    Info : tMapLevelInfo;
    procedure  ClearLightMapData;
    procedure  InvalidateLightMap;
    function   IsLightMapOutOfDate : boolean;
    procedure  SetLightMapData( Value : pointer; Size : cardinal );
    property   LightMapData : pointer read fLightMapData;
    property   LightMapSize : cardinal read GetLightMapSize;
    destructor destroy; override;
  end;

  tMap = class( tObject )
  private
    pMap : pMapHeader;
    cThingList : tObjectList;
    cLevelList : tObjectList;
    fFilename : string;
    constructor create; overload;
    function    calculateMapSize( aWidth, aHeight : Integer ) : cardinal;
    procedure   cleanUp;
    procedure   exportRawMap( const ExportFilename : string; const ExportOptions : tExportOptions );
    procedure   exportStlMap( const ExportFilename : string; const ExportOptions : tExportOptions );
    procedure   freeLightMaps;
    function    getBlock( x, y, z : integer ) : tBlockType;
    function    getBlockData : pointer;
    function    getBlockDataMap( aMapHeader : pMapHeader ) : pointer;
    function    getColumn( x, z : integer ) : tBlock;
    function    getColumnPointer( x, z : integer ) : pBlock;
    function    getHeight : integer;
    function    getLevel( Idx : integer ) : tMapLevel;
    function    getWidth : integer;
    procedure   initialiseLevels( LevelCount : integer );
    procedure   setBlock( x, y, z : integer; cBlock : tBlockType );
    procedure   setColumn( x, z : integer; cColumn : tBlock );
    procedure   loadMap;
    procedure   readMap( pMapData : pMapHeader; Size : cardinal );
  public
    constructor create( const Header : tMapHeader; BufferSize : cardinal = 0 ); overload;
    constructor create( const aFilename : string ); overload;
    destructor  destroy; override;
    function    addThing( const Thing : tThingInfo ) : tThing;
    procedure   deleteThing( Thing : tThing );
    function    coordinatesInMap( x, y, z : integer ) : boolean;
    procedure   ensureThingsAreNotObstructed;
    procedure   exportMap( const ExportFilename : string; const ExportOptions : tExportOptions );
    procedure   getAdjacentBlocks( x, y, z : integer; var AdjacentBlocks : tAdjacentBlocks );
    procedure   getThings( ThingList : tList ); overload;
    procedure   getThings( ThingType : tThingType; Level : integer; ThingList : tList ); overload;
    function    interpolateLight( Index, Steps : integer; const InitialPosition, FinalPosition : tSphericalCoordinate ) : tSphericalCoordinate;
    procedure   invalidateLightMaps;
    function    isPointInWater( const Point : tPoint3d ) : boolean;
    function    isFlagSet( Flag : integer ) : boolean;
    procedure   resize( NewWidth, NewHeight : integer );
    procedure   saveMap; overload;
    procedure   saveMap( const NewFilename : string ); overload;
    procedure   setFlag( Flag : integer; Value : boolean );
    property    Block[ x, y, z : integer ] : tBlockType read getBlock write setBlock;
    property    BlockData : pointer read getBlockData;
    property    Column[ x, z : integer ] : tBlock read getColumn write setColumn;
    property    Filename : string read fFilename;
    property    Header : pMapHeader read pMap;
    property    Height : integer read getHeight;
    property    Level[ Idx : integer ] : tMapLevel read getLevel;
    property    Width : integer read getWidth;
  end;

const
  BlockTypeName : array [ tBlockType ] of string = ( 'Empty', 'Water', 'Pillars', 'Cubes' );
  ThingTypeName : array [ tThingType ] of string = ( 'Spawn Point', 'Rescuee Point', 'Start Point', 'Pre-placed Ant' );

implementation

uses
  Math, SysUtils, Windows;

const
  EOL = #13#10;
  FILE_MAGIC  = $544E4158;  // XANT
  LEVEL_MAGIC = $4C56454C;  // LEVL

  DEFAULT_DRAW_DISTANCE = 80;

Function CompressRLE (Buffer : Pointer; BufferSize : LongInt; Var CompressedSize : LongInt) : Pointer;
Var
  Pass, BIdx, ZeroCount : Integer;
  BScan, CScan : pBlock;

Procedure WriteZeros;
Begin
  If Assigned(CScan) Then
  Begin
    CScan^:=0;
    Inc(CScan);
    CScan^:=ZeroCount;
    Inc(CScan);
  End
  Else
    Inc(CompressedSize,2);
End;

Begin
  Result:=Nil;
  If BufferSize > 0 Then
  Begin
    CScan:=Nil;
    CompressedSize:=0;
    For Pass:=1 To 2 Do
    Begin
      BScan:=Buffer;
      BIdx:=0;
      ZeroCount:=0;
      While BIdx < BufferSize Do
      Begin
        If (BScan^ <> 0) Or (ZeroCount = 255) Then
        Begin
          If ZeroCount <> 0 Then
            WriteZeros;
          If BScan^ <> 0 Then
          Begin
            If Assigned(CScan) Then
            Begin
              CScan^:=BScan^;
              Inc(CScan);
            End
            Else
              Inc(CompressedSize);
            ZeroCount:=0;
          End
          Else
            ZeroCount:=1;
        End
        Else
          Inc(ZeroCount);
        Inc(BScan);
        Inc(BIdx);
      End;
      If ZeroCount > 0 Then
        WriteZeros;
      If Not Assigned(CScan) Then
      Begin
        CompressedSize:=CompressedSize * SizeOf(tBlock);
        GetMem(CScan,CompressedSize);
        Result:=CScan;
      End;
    End;
  End;
End;

Procedure DecompressRLE (Compressed, Buffer : Pointer; Size : LongInt);
Var
  CScan, BScan : pBlock;
  Count : Integer;
Begin
  CScan:=Compressed;
  BScan:=Buffer;
  Size:=Size Div SizeOf(tBlock);
  While Size > 0 Do
  Begin
    If CScan^ = 0 Then
    Begin
      Inc(CScan);
      Dec(Size);
      Count:=CScan^;
      While Count > 0 Do
      Begin
        BScan^:=0;
        Inc(BScan);
        Dec(Count);
      End;
    End
    Else
    Begin
      BScan^:=CScan^;
      Inc(BScan);
    End;
    Inc(CScan);
    Dec(Size);
  End;
End;

destructor tMapLevel.destroy;
begin
  ClearLightMapData;
  inherited;
end;

procedure tMapLevel.ClearLightMapData;
begin
  SetLightMapData( nil, 0 );
end;

function tMapLevel.GetLightMapSize : cardinal;
begin
  result := Abs( Info.LightMapSize );
end;

function tMapLevel.IsLightMapOutOfDate : boolean;
begin
  result := Info.LightMapSize <= 0;
end;

procedure tMapLevel.InvalidateLightMap;
begin
  Info.LightMapSize := -Abs( Info.LightMapSize );
end;

procedure tMapLevel.SetLightMapData( Value : pointer; Size : cardinal );
begin
  if LightMapData <> nil then
  begin
    FreeMem( fLightMapData );
    fLightMapData := nil;
  end;
  fLightMapData := Value;
  if Value = nil then
    Info.LightMapSize := 0
  else
    Info.LightMapSize := Size;
end;

constructor tMap.create;
begin
  inherited;
  cThingList := tObjectList.Create;
  cLevelList := tObjectList.Create;
end;

constructor tMap.create( const Header : tMapHeader; BufferSize : cardinal );
begin
  create;
  if BufferSize = 0 then
  begin
    pMap := allocMem( calculateMapSize( Header.Width, Header.Height ) );
    Move( Header, pMap^, SizeOf( tMapHeader ) );
    initialiseLevels( Header.Levels );
  end
  else
    ReadMap( @Header, BufferSize );
end;

constructor tMap.create( const aFilename : string );
begin
  create;
  fFilename := aFilename;
  LoadMap;
end;

destructor tMap.destroy;
begin
  cleanUp;
  cThingList.Free;
  cLevelList.Free;
  inherited;
end;

function tMap.addThing( const Thing : tThingInfo ) : tThing;
begin
  result := tThing.Create;
  result.Info := Thing;
  cThingList.Add( result );
end;

function tMap.calculateMapSize( aWidth, aHeight : Integer ) : cardinal;
begin
  result := ( aWidth * aHeight * SizeOf( tBlock ) ) + SizeOf( tMapHeader );
end;

procedure tMap.cleanUp;
begin
  cThingList.Clear;
  cLevelList.Clear;
  if pMap <> nil then
  begin
    FreeMem( pMap );
    pMap := nil;
  end;
end;

procedure tMap.deleteThing( Thing : tThing );
begin
  if cThingList.Remove( Thing ) < 0 then
    Thing.Free;
end;

procedure tMap.exportRawMap( const ExportFilename : string; const ExportOptions : tExportOptions );
var
  hFile : File;
  x, y, z, nMapSize, nBlockSize, nOffset, nColumn, nBlock : integer;
  pBuffer : pointer;
  pMapData : pBlockArray;
  pBScan : ^byte;
  pWScan : ^word;
  Width, Height : integer;
begin
  AssignFile( hFile, ExportFilename );
  try
    Rewrite( hFile, 1 );
    Width := pMap^.Width;
    Height := pMap^.Height;
    if ExportOptions.RawOptions.Title then
    begin
      nOffset := StrLen( pMap^.Title );
      FillChar( pMap^.Title[ nOffset ], sizeof( pMap^.Title ) - nOffset, 0 );
      BlockWrite( hFile, pMap^.Title, sizeof( pMap^.Title ) );
    end;
    if ExportOptions.RawOptions.Dimensions then
    begin
      BlockWrite( hFile, Width, sizeof( Width ) );
      BlockWrite( hFile, Height, sizeof( Height ) );
    end;
    pMapData := BlockData;
    nMapSize := Width * Height;
    if ExportOptions.nFormat <> EXF_PACKED_WORD then
    begin
      if ExportOptions.nFormat = EXF_BYTE_PER_BLOCK then nBlockSize := sizeof( byte ) else nBlockSize := sizeof( word );
      nMapSize := nMapSize * 8 * nBlockSize;
      GetMem( pBuffer, nMapSize );
      try
        pBScan := pBuffer;
        pWScan := pBuffer;
        nOffset := 0;
        for z := 1 to Height do
          for x := 1 to Width do
          begin
            nColumn := pMapData^[ nOffset ];
            for y := 0 to 7 do
            begin
              nBlock := ( nColumn and ( 3 shl ( y * 2 ) ) ) shr ( y * 2 );
              if ExportOptions.nFormat = EXF_BYTE_PER_BLOCK then
              begin
                pBScan^ := byte( nBlock );
                inc( pBScan );
              end
              else
              begin
                pWScan^ := word( nBlock );
                inc( pWScan );
              end;
            end;
            inc( nOffset );
          end;
        BlockWrite( hFile, pBuffer^, nMapSize );
      finally
        FreeMem( pBuffer );
      end;
    end
    else
      BlockWrite( hFile, pMapData^, nMapSize * sizeof( tBlock ) );
  finally
    CloseFile( hFile );
  end;
end;

procedure tMap.exportStlMap( const ExportFilename : string; const ExportOptions : tExportOptions );
var
  Binary : boolean;

// Alternative version that simply uses two triangles to draw the entire ground plane
procedure WriteGroundPlane( const hFile : TextFile );
begin
  WriteLN( hFile, 'facet normal 0 0 0' );
  WriteLN( hFile, #9, 'outer loop' );
  WriteLN( hFile, #9, #9, 'vertex ', pMap^.Width, ' ', pMap^.Height, ' 0' );
  WriteLN( hFile, #9, #9, 'vertex 0 ', pMap^.Height, ' 0' );
  WriteLN( hFile, #9, #9, 'vertex 0 0 0' );
  WriteLN( hFile, #9, 'endloop' );
  WriteLN( hFile, 'endfacet' );
  WriteLN( hFile, 'facet normal 0 0 0' );
  WriteLN( hFile, #9, 'outer loop' );
  WriteLN( hFile, #9, #9, 'vertex 0 0 0' );
  WriteLN( hFile, #9, #9, 'vertex ', pMap^.Width, ' 0 0' );
  WriteLN( hFile, #9, #9, 'vertex ', pMap^.Width, ' ', pMap^.Height, ' 0' );
  WriteLN( hFile, #9, 'endloop' );
  WriteLN( hFile, 'endfacet' );
end;

const
  // Convertsion to right-hand coordinate system. x -> right, z -> up, y -> far
  AxisMap : array [ 0 .. 2 ] of integer = ( 0, 2, 1 );
var
  hTextFile : TextFile;
  hBinFile : tFileStream;
  x, y, z : integer;
  TriangleCount : integer;

procedure WriteSurface( yOffset : integer; const Surface : tCubeSurface );
var
  Facet : integer;
  i, v, vi : integer;
  Offset : _float;
  Value : _float;
  Vertex : array [ 0 .. 2 ] of _float;

procedure WriteTriangleStart;
var
  Normal : array [ 0 .. 2 ] of _float;
begin
  if Binary then
  begin
    FillChar( Normal, SizeOf( Normal ), #0 );
    hBinFile.Write( Normal, SizeOf( Normal ) );
  end
  else
  begin
    WriteLN( hTextFile, 'facet normal 0 0 0' );
    WriteLN( hTextFile, #9, 'outer loop' );
  end;
end;

procedure WriteTriangleEnd;
var
  AttributeCount : word;
begin
  if Binary then
  begin
    AttributeCount := 0;
    hBinFile.Write( AttributeCount, SizeOf( AttributeCount ) );
  end
  else
  begin
    WriteLN( hTextFile, #9, 'endloop' );
    WriteLN( hTextFile, 'endfacet' );
  end;
end;

procedure WriteVertex;
var
  i : integer;
begin
  if Binary then
    hBinFile.Write( Vertex, SizeOf( Vertex ) )
  else
  begin
    Write( hTextFile, #9, #9, 'vertex' );
    for i := 0 to 2 do
    begin
      Value := Vertex[ i ];
      if Value = Trunc( Value ) then
        Write( hTextFile, ' ', Trunc( Value ) )
      else
        Write( hTextFile, ' ', Value );
    end;
    WriteLN( hTextFile );
  end;
end;

begin
  for Facet := 0 to 1 do
  begin
    WriteTriangleStart;
    for v := 0 to 2 do
    begin
      vi := ( v + Facet * 2 ) and 3;
      for i := 0 to 2 do
      begin
        Value := ptBoxVertex[ Surface ][ vi, AxisMap[ i ] ];
        // Fiddling for right-hand coordinate system
        if i = 1 then
          Value := 1 - Value;
        Offset := IfThen( i = 0, x, IfThen( i = 2, y + yOffset, pMap^.Height - z - 1 ) );

        Vertex[ i ] := ( Value + Offset ) * ExportOptions.StlOptions.Scale;
      end;
      WriteVertex;
    end;
    WriteTriangleEnd;
    inc( TriangleCount );
  end;
end;

procedure WriteBlock( yOffset : integer; const AdjacentBlocks : tAdjacentBlocks );
var
  Surface : tCubeSurface;
begin
  for Surface := Low( tCubeSurface ) to high( tCubeSurface ) do
    if AdjacentBlocks[ Surface ] <> BLOCK_SOLID then
      WriteSurface( yOffset, Surface );
end;

function IfThen( Condition : boolean; TrueBlockType : tBlockType; FalseBlockType : tBlockType ) : tBlockType;
begin
  if Condition then
    result := TrueBlockType
  else
    result := FalseBlockType;
end;

procedure CreateStlFile;
begin
  if Binary then
    hBinFile := tFileStream.Create( ExportFilename, fmCreate, fmShareExclusive )
  else
  begin
    AssignFile( hTextFile, ExportFilename );
    Rewrite( hTextFile );
  end;
end;

procedure CloseStlFile;
begin
  if Binary then
    hBinFile.Free
  else
    CloseFile( hTextFile );
end;

procedure WriteFileHeader;
var
  BinaryHeader : array [ 1 .. 80 ] of byte;
begin
  if Binary then
  begin
    FillChar( BinaryHeader, SizeOf( BinaryHeader ), #0 );
    hBinFile.Write( BinaryHeader, SizeOf( BinaryHeader ) );
    hBinFile.Write( TriangleCount, SizeOf( TriangleCount ) );
  end
  else
    WriteLN( hTextFile, 'solid ', pMap^.Title );
end;

procedure WriteFileFooter;
begin
  if Binary then
  begin
    hBinFile.Seek( 80, soBeginning );
    hBinFile.Write( TriangleCount, SizeOf( TriangleCount ) );
  end
  else
    WriteLN( hTextFile, 'endsolid ', pMap^.Title );
end;

var
  Block : tBlockType;
  AdjacentBlocks : tAdjacentBlocks;
  GroundPlaneOffset : integer;

begin
  Binary := ExportOptions.nFormat = EXF_STL_BINARY;
  TriangleCount := 0;
  GroundPlaneOffset := Math.IfThen( ExportOptions.StlOptions.GroundPlane, 1, 0 );
  CreateStlFile;
  try
    WriteFileHeader;
    with ExportOptions.StlOptions do
      for z := Area.Top to Area.Bottom do
        for x := Area.Left to Area.Right do
          for y := 0 to 7 do
          begin
            Block := getBlock( x, y, z );

            if ExportOptions.StlOptions.GroundPlane and ( y = 0 ) then
            begin
              AdjacentBlocks[ CS_LEFT ] := IfThen( x = Area.Left, BLOCK_EMPTY, BLOCK_SOLID );
              AdjacentBlocks[ CS_RIGHT ] := IfThen( x = Area.Right, BLOCK_EMPTY, BLOCK_SOLID );
              AdjacentBlocks[ CS_TOP ] := Block;
              AdjacentBlocks[ CS_BOTTOM ] := BLOCK_EMPTY;
              AdjacentBlocks[ CS_FAR ] := IfThen( z = Area.Top, BLOCK_EMPTY, BLOCK_SOLID );
              AdjacentBlocks[ CS_NEAR ] := IfThen( z = Area.Bottom, BLOCK_EMPTY, BLOCK_SOLID );
              WriteBlock( 0, AdjacentBlocks );
            end;

            if Block = BLOCK_SOLID then
            begin
              getAdjacentBlocks( x, y, z, AdjacentBlocks );
              if ( y = 0 ) and not ExportOptions.StlOptions.GroundPlane then AdjacentBlocks[ CS_BOTTOM ] := BLOCK_EMPTY;
              if x = Area.Left then AdjacentBlocks[ CS_LEFT ] := BLOCK_EMPTY;
              if x = Area.Right then AdjacentBlocks[ CS_RIGHT ] := BLOCK_EMPTY;
              if z = Area.Top then AdjacentBlocks[ CS_FAR ] := BLOCK_EMPTY;
              if z = Area.Bottom then AdjacentBlocks[ CS_NEAR ] := BLOCK_EMPTY;
              WriteBlock( GroundPlaneOffset, AdjacentBlocks );
            end;
          end;
    WriteFileFooter;
  finally
    CloseStlFile;
  end;
end;

procedure tMap.freeLightMaps;
var
  Idx : integer;
begin
  for Idx := 1 to pMap^.Levels do
    Level[ Idx ].ClearLightMapData;
end;

function tMap.getBlock( x, y, z : integer ) : tBlockType;
begin
  y := y shl 1;
  result := tBlockType( ( getColumn( x, z ) and ( 3 shl y ) ) shr y );
end;

function tMap.getBlockData : pointer;
begin
  Result := getBlockdataMap( pMap );
end;

function tMap.getBlockDataMap( aMapHeader : pMapHeader ) : pointer;
begin
  Result := Pointer( LongInt( aMapHeader ) + SizeOf( tMapHeader ) );
end;

function tMap.getColumn( x, z : integer ) : tBlock;
begin
  result := getColumnPointer( x, z )^;
end;

function tMap.getColumnPointer( x, z : integer ) : pBlock;
begin
  result := getBlockData;
  inc( result, z * pMap^.Width + x );
end;

function tMap.getHeight : integer;
begin
  result := pMap^.Height;
end;

function tMap.getLevel( Idx : integer ) : tMapLevel;
begin
  if Idx > cLevelList.Count then
  begin
    result := tMapLevel.Create;
    if Idx > 1 then
      Move( getLevel( Idx - 1 ).Info, result.Info, SizeOf( tMapLevelInfo ) );
    result.Info.Magic := LEVEL_MAGIC;
    result.Info.Level := Idx;
    result.Info.LightMapSize := 0;
    cLevelList.Add( result );
  end
  else
    result := tMapLevel( cLevelList[ Idx - 1 ] );
end;

function tMap.getWidth : integer;
begin
  result := pMap^.Width;
end;

procedure tMap.initialiseLevels( LevelCount : integer );
var
  Idx : integer;
  LevelInfo : tMapLevelInfo;
  NewLevel : tMapLevel;
  Light : array [ boolean ] of tSphericalCoordinate;
begin
  cLevelList.Clear;
  Light[ false ].Latitude := DegToRad( -30.2 );
  Light[ false ].Longitude := DegToRad( -70 );
  Light[ true ].Latitude := DegToRad( -30.2 );
  Light[ true ].Longitude := DegToRad( 70 );
  for Idx := 1 to LevelCount do
  begin
    with LevelInfo do
    begin
      Magic := LEVEL_MAGIC;
      Level := Idx;
      AntCount := 4 + 11 * Idx div LevelCount;
      SpawnInterval := 5 - 4 * Idx div LevelCount;
      DrawDistance := DEFAULT_DRAW_DISTANCE - 40 * Idx div LevelCount;
      LightPosition := interpolateLight( Idx, LevelCount, Light[ false ], Light[ true ] );
      LightMapSize := 0;
      NewLevel := tMapLevel.Create;
      cLevelList.Add( NewLevel );
      NewLevel.Info := LevelInfo;
    end;
  end;
end;

procedure tMap.invalidateLightMaps;
var
  Idx : integer;
begin
  for Idx := 1 to pMap^.Levels do
    Level[ Idx ].InvalidateLightMap;
end;

procedure tMap.setBlock( x, y, z : integer; cBlock : tBlockType );
var
  pColumn : pBlock;
begin
  y := y shl 1;
  pColumn := getColumnPointer( x, z );
  pColumn^ := ( pColumn^ and not ( 3 shl y ) ) or ( integer( cBlock ) shl y );
end;

procedure tMap.setColumn( x, z : integer; cColumn : tBlock );
begin
  getColumnPointer( x, z )^ := cColumn;
end;

function tMap.coordinatesInMap( x, y, z : integer ) : boolean;
begin
  result := ( x >= 0 ) and ( x < Width ) and ( y >= 0 ) and ( y < MAP_SIZE_COLUMN ) and ( z >= 0 ) and ( z < Height );
end;

procedure tMap.ensureThingsAreNotObstructed;
var
  Idx : integer;
  Thing : tThing;
begin
  for Idx := 0 to cThingList.Count - 1 do
  begin
    Thing := tThing( cThingList[ Idx ] );
    with Thing.Info.Position do
      Block[ x, y, z ] := BLOCK_EMPTY;
  end;
end;

procedure tMap.exportMap( const ExportFilename : string; const ExportOptions : tExportOptions );
begin
  if ( ExportOptions.nFormat = EXF_STL_TEXT ) or ( ExportOptions.nFormat = EXF_STL_BINARY ) then
    exportStlMap( ExportFilename, ExportOptions )
  else
    exportRawMap( ExportFilename, ExportOptions );
end;

procedure tMap.readMap( pMapData : pMapHeader; Size : cardinal );
var
  pScan : pByte;
  Offset : cardinal;

Procedure LoadThings;
Var
  Idx, Step : Integer;
  NewThing : tThing;
Begin
  Step := SizeOf( tThingInfo );
  For Idx:=1 To pMapData^.ThingCount Do
  Begin
    NewThing:=tThing.Create;
    Try
      Move( pThingInfo( pScan )^, NewThing.Info, Step );
      cThingList.Add(NewThing);
      inc( Offset, Step );
      inc( pScan, Step );
    Except
      NewThing.Free;
      Raise;
    End;
  End;
End;

procedure LoadLevels;
var
  Idx, Step : integer;
  LevelInfo : tMapLevelInfo;
  NewLevel : tMapLevel;
begin
  Move( pScan^, LevelInfo, SizeOf( LevelInfo.Magic ) );
  if LevelInfo.Magic = LEVEL_MAGIC then
  begin
    Step := SizeOf( tMapLevelInfo );
    for Idx := 1 to pMapData^.Levels do
    begin
      NewLevel := tMapLevel.Create;
      try
        Move( pMapLevelInfo( pScan )^, NewLevel.Info, Step );
        cLevelList.Add( NewLevel );
        if NewLevel.Info.DrawDistance = 0 then
          NewLevel.Info.DrawDistance := DEFAULT_DRAW_DISTANCE;
        inc( Offset, Step );
        inc( pScan, Step );
      except
        NewLevel.Free;
        raise;
      end;
    end;
  end
  else
    InitialiseLevels( pMapData^.Levels );
end;

procedure LoadLightMaps;
var
  Idx : integer;
  MapLevel : tMapLevel;
  LightMapData : pointer;
  LightMapSize : cardinal;
  OutOfDateLightMap : boolean;
begin
  for Idx := 1 to pMapData^.Levels do
  begin
    MapLevel := Level[ Idx ];
    LightMapSize := MapLevel.LightMapSize;
    if LightMapSize > 0 then
    begin
      OutOfDateLightMap := MapLevel.IsLightMapOutOfDate;
      GetMem( LightMapData, LightMapSize );
      MapLevel.SetLightMapData( LightMapData, MapLevel.LightMapSize );
      if OutOfDateLightMap then
        MapLevel.InvalidateLightMap;
      Move( pScan^, LightMapData^, LightMapSize );
      inc( Offset, LightMapSize );
      inc( pScan, LightMapSize );
    end;
  end;
end;

var
  CompressedSize : cardinal;

begin
  if ( pMapData^.Magic = FILE_MAGIC ) and ( Size > SizeOf( tMapHeader ) ) then
  begin
    CleanUp;

    pScan := pointer( pMapData );
    Offset := SizeOf( tMapHeader );
    inc( pScan, Offset );

    LoadThings;
    LoadLevels;
    LoadLightMaps;

    CompressedSize := Size - Offset;
    GetMem( pMap, CalculateMapSize( pMapData^.Width, pMapData^.Height ) );
    try
      DecompressRLE( pScan, BlockData, CompressedSize );
      Move( pMapData^, pMap^, SizeOf( tMapHeader ) );
    except
      FreeMem( pMap );
      pMap := nil;
      raise;
    end;
  end
  else
    raise eInOutError.Create( 'Invalid File Format' );
end;

procedure tMap.loadMap;
Var
  MapFile : File;
  FileBuffer : Pointer;
  Size : cardinal;

Begin
  FileMode:=0;
  AssignFile(MapFile,fFilename);
  try
    Reset(MapFile,1);
    try
      Size := FileSize( MapFile );
      GetMem( FileBuffer, Size );
      try
        BlockRead( MapFile, FileBuffer^, Size );
        readMap( FileBuffer, Size );
      finally
        FreeMem(FileBuffer);
      end;
    finally
      CloseFile(MapFile);
    end;
  except
    On E : Exception Do
      raise eInOutError.create( 'Error Loading Map ' + fFilename + EOL + EOL + E.Message );
  End;
End;

procedure tMap.getAdjacentBlocks( x, y, z : integer; var AdjacentBlocks : tAdjacentBlocks );
var
  pBlockData : pBlockArray;
  cBlock : tBlock;
  cMask : cardinal;   // Not tBlock so that the shift doesn't produce a RangeCheckError when y >= 8
  nOffset, nShift, nLShift : integer;
begin
  pBlockData := getBlockData;
  nOffset := z * Width + x;
  cBlock := pBlockData^[ nOffset ];
  nShift := y * 2;
  cMask := 3 shl nShift;

  FillChar( AdjacentBlocks, SizeOf( AdjacentBlocks ), 0 );
  if x > 0 then AdjacentBlocks[ CS_LEFT ] := tBlockType( ( pBlockData^[ nOffset - 1 ] and cMask ) shr nShift );               // Left
  if x < Width - 1 then AdjacentBlocks[ CS_RIGHT ] := tBlockType( ( pBlockData^[ nOffset + 1 ] and cMask ) shr nShift );      // Right
  nLShift := ( y + 1 ) * 2;
  if y < 7 then AdjacentBlocks[ CS_TOP ] := tBlockType( ( cBlock and ( 3 shl nLShift ) ) shr nLShift );                       // Top
  nLShift := ( y - 1 ) * 2;
  if y > 0 then AdjacentBlocks[ CS_BOTTOM ] := tBlockType( ( cBlock and ( 3 shl nLShift ) ) shr nLShift )                     // Bottom
    else AdjacentBlocks[ CS_BOTTOM ] := BLOCK_SOLID;
  if z > 0 then AdjacentBlocks[ CS_FAR ] := tBlockType( ( pBlockData^[ nOffset - Width ] and cMask ) shr nShift );            // Far
  if z < Height - 1 then AdjacentBlocks[ CS_NEAR ] := tBlockType( ( pBlockData^[ nOffset + Width ] and cMask ) shr nShift );  // Near
end;

procedure tMap.getThings( ThingList : tList );
begin
  ThingList.Clear;
  ThingList.Assign( cThingList );
end;

procedure tMap.getThings( ThingType : tThingType; Level : integer; ThingList : tList );
var
  Idx : integer;
  LevelMask : int64;
  cThing : tThing;
begin
  ThingList.Clear;
  LevelMask := 1;
  LevelMask := LevelMask shl ( Level - 1 );
  for Idx := 0 to cThingList.Count - 1 do
  begin
    cThing := tThing( cThingList[ Idx ] );
    if ( ( cThing.Info.LevelMask and LevelMask ) = LevelMask ) and ( cThing.Info.ThingType = ThingType ) then
      ThingList.Add( cThing );
  end;
end;

function tMap.interpolateLight( Index, Steps : integer; const InitialPosition, FinalPosition : tSphericalCoordinate ) : tSphericalCoordinate;
var
  Step : tSphericalCoordinate;
begin
  if Steps > 1 then
  begin
    Step.Latitude := ( FinalPosition.Latitude - InitialPosition.Latitude ) / ( Steps - 1 );
    Step.Longitude := ( FinalPosition.Longitude - InitialPosition.Longitude ) / ( Steps - 1 );
    result.Latitude := InitialPosition.Latitude + ( Step.Latitude * ( Index - 1 ) );
    result.Longitude := InitialPosition.Longitude + ( Step.Longitude * ( Index - 1 ) );
  end
  else
    result := InitialPosition;
end;

function tMap.isPointInWater( const Point : tPoint3d ) : boolean;
var
  x, y, z :  integer;
begin
  result := false;
  x := floor( Point.x );
  y := floor( Point.y );
  z := floor( Point.z );
  if coordinatesInMap( x, y, z ) and ( Block[ x, y, z ] = BLOCK_WATER ) then
    result := ( ( Point.y - y ) <= ( 1 - WATER_OFFSET ) ) or ( ( y < MAP_SIZE_COLUMN - 1 ) and ( Block[ x, y + 1, z ] = BLOCK_WATER ) );
end;

function tMap.isFlagSet( Flag : integer ) : boolean;
begin
  result := ( Header^.Flags and Flag ) <> 0;
end;

procedure tMap.resize( NewWidth, NewHeight : integer );
Var
  NewMap : pMapHeader;
  NewMapYScan, NewMapXScan, OldMapYScan, OldMapXScan : pBlock;
  X,Y : Integer;
  Extent : tPoint;
Begin
  If ( Width <> NewWidth ) Or ( Height <> NewHeight ) Then
  Begin
    NewMap:=Nil;
    Try
      FreeLightMaps;
      NewMap:=AllocMem(CalculateMapSize(NewWidth,NewHeight));
      Move(pMap,NewMap^,SizeOf(tMapHeader));
      NewMap^.Width := NewWidth;
      NewMap^.Height := NewHeight;
      If NewWidth > Width Then
        Extent.X:=Width
      Else
        Extent.X:=NewWidth;
      If NewHeight > Height Then
        Extent.Y:=Height
      Else
        Extent.Y:=NewHeight;
      NewMapYScan:=GetBlockDataMap(NewMap);
      OldMapYScan:=GetBlockData;
      For Y:=1 To Extent.Y Do
      Begin
        NewMapXScan:=NewMapYScan;
        OldMapXScan:=OldMapYScan;
        For X:=1 To Extent.X Do
        Begin
          NewMapXScan^:=OldMapXScan^;
          Inc(NewMapXScan);
          Inc(OldMapXScan);
        End;
        Inc(NewMapYScan,NewWidth);
        Inc(OldMapYScan,Width);
      End;
      FreeMem(pMap);
      pMap:=NewMap;
    Except
      If Assigned(NewMap) Then
        FreeMem(NewMap);
      Raise;
    End;
  End;
End;

procedure tMap.saveMap;
begin
  saveMap( fFilename );
end;

Procedure tMap.saveMap( Const NewFilename : String );
Var
  MapFile : File;
  FileBuffer : Pointer;
  CompressedSize : LongInt;

Procedure WriteThings;
Var
  Idx : Integer;
Begin
  For Idx := 0 To cThingList.Count - 1 Do
    BlockWrite( MapFile, tThing( cThingList[ Idx ] ).Info, SizeOf( tThingInfo ) );
End;

procedure WriteLevels;
var
  Idx : integer;
begin
  for Idx := 1 to pMap^.Levels do
    BlockWrite( MapFile, Level[ Idx ].Info, SizeOf( tMapLevelInfo ) );
end;

procedure WriteLightMaps;
var
  Idx : integer;
  MapLevel : tMapLevel;
begin
  for Idx := 1 to pMap^.Levels do
  begin
    MapLevel := Level[ Idx ];
    if MapLevel.LightMapSize > 0 then
      BlockWrite( MapFile, MapLevel.LightMapData^, MapLevel.LightMapSize );
  end;
end;

Begin
  AssignFile(MapFile,NewFilename);
  Try
    Rewrite(MapFile,1);
    Try
      FileBuffer:=CompressRLE(BlockData,pMap^.Width * pMap^.Height,CompressedSize);
      Try
        pMap^.Magic:=FILE_MAGIC;
        pMap^.ThingCount:=cThingList.Count;
        BlockWrite(MapFile,pMap^,SizeOf(tMapHeader));
        WriteThings;
        WriteLevels;
        WriteLightMaps;
        BlockWrite(MapFile,FileBuffer^,CompressedSize);
        fFilename := NewFilename;
      Finally
        FreeMem(FileBuffer);
      End;
    Finally
      CloseFile(MapFile);
    End;
  Except
    On E : Exception Do
      raise eInOutError.create( 'Error Saving Map ' + NewFilename + EOL + EOL + E.Message );
  End;
End;

procedure tMap.setFlag( Flag : integer; Value : boolean );
begin
  if Value then
    Header^.Flags := Header^.Flags or Flag
  else
    Header^.Flags := Header^.Flags and not Flag;
end;

end.
