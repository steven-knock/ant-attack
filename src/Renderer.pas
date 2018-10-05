unit Renderer;

interface

uses
  Classes, Controls, INIFiles, GeometryGL12, OpenGL12, Common, glFont, Colour, Geometry, Cube, GameState, LightMap, Map, Messaging, Model, Registry;

type
  tLightMapMode = ( LM_NONE, LM_LOW, LM_HIGH );

  tRenderStatus = class( tObject )
  public
    cControl : tWinControl;
    bLighting : boolean;
    bTexturing : boolean;
    nFog : cardinal;      // 0 = no fog; < nFog = Exponential^2 fog; >= nFog = Linear Fog
    nFogDensity : glFloat;
    bMipMap : boolean;
    nLightMap : tLightMapMode;
    bFloor : boolean;
    bTextureFloor : boolean;
    bSun : boolean;
    bBoundingBoxes : boolean;
    bOrthographic : boolean;
    bOverheadMap : boolean;
    nScale : glFloat;
    nFOV : glFloat;
    nFarDistance : glFloat;
    nPolyCount : integer;
    nTime : cardinal;
    bCacheVisibility : boolean;
    constructor create;
    procedure   reset;
  end;

  tClipStatus = ( CLIP_OUTSIDE, CLIP_INSIDE, CLIP_INTERSECT );

  tSurfaceLightData = record
    FacesLight : boolean;
    LightIntensity : glFloat;
    ShadowIntensity : glFloat;
    ShadeIntensity : byte;
    Colour : array [ tPalette, boolean ] of tColour;   // Odd / Even, Shade / Light
  end;

  tRendererConfiguration = class( tObject )
  private
    fColourDepth : cardinal;
    fZBufferDepth : cardinal;
    fPerPixelFog : integer;
    fFullScreen : boolean;
    fWidth : cardinal;
    fHeight : cardinal;
    fInvertMouse : boolean;     // v1.0.3
    fHideStatus : boolean;      // v1.0.5
    function GetINIFile : tINIFile;
    function GetINIFilename : string;
    function GetRegistry : tRegistryINIFile;
    function IsINIFileReadOnly : boolean;
  public
    constructor Create;
    procedure   Save;
    property ColourDepth : cardinal read fColourDepth write fColourDepth;
    property ZBufferDepth : cardinal read fZBufferDepth write fZBufferDepth;
    property PerPixelFog : integer read fPerPixelFog write fPerPixelFog;
    property FullScreen : boolean read fFullScreen write fFullScreen;
    property Width : cardinal read fWidth write fWidth;
    property Height : cardinal read fHeight write fHeight;
    property InvertMouse : boolean read fInvertMouse write fInvertMouse;
    property HideStatus : boolean read fHideStatus write fHideStatus;
  end;

  tRenderer = class( tObject )
  private
    fConfiguration : tRendererConfiguration;
    cMap : tMap;
    nOpenGLId : cardinal;
    cRenderStatus : tRenderStatus;
    cCamera : tViewpoint;
    cLightMapManager : tLightMapManager;
    cGameInformation : tGameInformation;
    cMessageList : tMessageList;
    cActiveMessageList : tList;
    ptScale : tFloatPoint2d;
    ptNormalisedLight : tPoint3d;
    ptTranslatedEntityPosition : tPoint3d;
    ptPlaneTest : array [ 0 .. 7 ] of tPoint3d;
    cTemporaryBoundingBox : tBoundingBox;
    cWaterList : tList;
    cSurfaceSpec : tSurfaceSpecification;
    cFrustum : array [ tCubeSurface ] of tPlane;
    ptFrustum : array [ 0 .. 7 ] of tPoint3d;
    nNearDistance : glFloat;
    glStoneTextureID : glInt;
    glFloorTextureID : glInt;
    glShadowTextureID : glInt;
    glWaterShadowTextureID : glInt;
    glFontData : pGLFont;
    SurfaceLightData : array [ tCubeSurface ] of tSurfaceLightData;
    bCameraAssigned : boolean;
    bPerformHiddenBlockTest : boolean;
    bEvenBlock : boolean;
    fMapLevel : integer;
    GrenadeIcon : tTexture;
    VisibilityCache : pointer;
    procedure   buildFrustumPlanes;
    procedure   clearVisibilityCache;
    procedure   createGameMessages;
    function    getBoundingBoxClipStatus( const BB : tBoundingBox ) : tClipStatus;
    function    getDrawDistance : glFloat;
    function    getEntityClipStatus( const Entity : tPhysicalEntity ) : tClipStatus;
    function    getMapLevel : integer;
    procedure   prepareClipping;
    procedure   prepareVisibilityCache;
    procedure   renderEntityBoundingBox( Entity : tPhysicalEntity );
    procedure   renderEntityModel( Entity : tPhysicalEntity; Geometry : tGeometry );
    procedure   renderEntity( Entity : tPhysicalEntity );
    procedure   renderFloor;
    procedure   renderSensoryEntity( Entity : tSensoryEntity );
    procedure   renderStatusInformation;
    procedure   renderSunburst;
    procedure   renderGame;
    procedure   renderMessage( Msg : tMessage );
    procedure   renderMessages;
    procedure   renderOverheadMap;
    procedure   selectTexture( Texture : tTexture );
    procedure   setMap( aMap : tMap );
    procedure   setMapLevel( MapLevel : integer );
    procedure   unitialiseOpenGL;
  public
    constructor create;
    destructor  destroy; override;
    procedure   initialiseOpenGL;
    procedure   render;
    property    Camera : tViewpoint read cCamera;
    property    GameInformation : tGameInformation read cGameInformation write cGameInformation;
    property    LightMapManager : tLightMapManager read cLightMapManager;
    property    Map : tMap read cMap write setMap;
    property    MapLevel : integer read GetMapLevel write SetMapLevel;
    property    MessageList : tMessageList read cMessageList write cMessageList;
    property    RenderStatus : tRenderStatus read cRenderStatus;
    property    Configuration : tRendererConfiguration read fConfiguration;
  end;

implementation

uses
  Forms, Math, Graphics, glGeometry, glHelp, OpenGL, ModelBase, GameModel, Resource, Selection, SpriteModel, SysUtils, Windows;

const
  MAP_ALPHA = 128;

  MSG_GRENADE = -2;
  MSG_INFORMATION = -3;

  WATER_ALPHA = $70;

  DEFAULT_FOG_THRESHOLD = 60;

  RENDERER_CONFIGURATION = 'renderer.ini';

procedure glSet( nOption : integer; bEnabled : boolean );
begin
  if bEnabled then glEnable( nOption ) else glDisable( nOption );
end;

procedure glRotateY( nRadians : _float );
begin
  glRotate( nRadians * 180 / PI, 0, -1, 0 );
end;

constructor tRenderStatus.create;
begin
  inherited;
  reset;
end;

procedure tRenderStatus.reset;
begin
  bLighting := true;
  bTexturing := true;
  nFog := DEFAULT_FOG_THRESHOLD;
  nFogDensity := 0.01;
  bMipMap := true;
  nLightMap := LM_HIGH;
  bFloor := true;
  bTextureFloor := true;
  bSun := true;
  bBoundingBoxes := false;
  bOrthographic := false;
  nFOV := 60;
  nFarDistance := 0;
  nScale := 0.01;
  nPolyCount := 0;
  nTime := 0;
  bCacheVisibility := true;
end;

const
  SECTION = 'Renderer';

constructor tRendererConfiguration.Create;

procedure ReadSettings( Source : tCustomINIFile );
begin
  with Source do
    try
      ColourDepth := ReadInteger( SECTION, 'ColourDepth', ColourDepth );
      ZBufferDepth := ReadInteger( SECTION, 'ZBufferDepth', ZBufferDepth );
      PerPixelFog := ReadInteger( SECTION, 'PerPixelFog', PerPixelFog );
      FullScreen := ReadBool( SECTION, 'FullScreen', FullScreen );
      Width := ReadInteger( SECTION, 'Width', Width );
      Height := ReadInteger( SECTION, 'Height', Height );
      InvertMouse := ReadBool( SECTION, 'InvertMouse', InvertMouse );    // v1.0.3
      HideStatus := ReadBool( SECTION, 'HideStatus', HideStatus );        // v1.0.5
    finally
      Source.Free;
    end;
end;

begin
  inherited;
  fColourDepth := 24;
  fZBufferDepth := 24;
  fPerPixelFog := -1;   // Detect
  fFullScreen := true;
  fWidth := 0;
  fHeight := 0;
  fInvertMouse := false;
  fHideStatus := false;

  ReadSettings( GetINIFile );
  if IsINIFileReadOnly then
    ReadSettings( GetRegistry );
end;

function tRendererConfiguration.GetINIFile : tINIFile;
begin
  result := tINIFile.Create( GetINIFilename );
end;

function tRendererConfiguration.GetINIFilename : string;
begin
  result := MakeApplicationRelative( RENDERER_CONFIGURATION );
end;

function tRendererConfiguration.GetRegistry : tRegistryINIFile;
begin
  result := tRegistryIniFile.Create( 'Software\Ant Attack' );
end;

function tRendererConfiguration.IsINIFileReadOnly : boolean;
begin
  result := FileIsReadOnly( GetINIFilename );
end;

procedure tRendererConfiguration.Save;

procedure WriteSettings( Source : tCustomINIFile );
begin
  with Source do
    try
      WriteInteger( SECTION, 'ColourDepth', ColourDepth );
      WriteInteger( SECTION, 'ZBufferDepth', ZBufferDepth );
      WriteInteger( SECTION, 'PerPixelFog', PerPixelFog );
      WriteBool( SECTION, 'FullScreen', FullScreen );
      WriteInteger( SECTION, 'Width', Width );
      WriteInteger( SECTION, 'Height', Height );
      WriteBool( SECTION, 'InvertMouse', InvertMouse );    // v1.0.3
      WriteBool( SECTION, 'HideStatus', HideStatus );      // v1.0.5
    finally
      Free;
    end;
end;

begin
  if IsINIFileReadOnly then
    WriteSettings( GetRegistry )
  else
    WriteSettings( GetINIFile );
end;

constructor tRenderer.create;
var
  Idx : tCubeSurface;
  PIdx : integer;
begin
  inherited create;
  fConfiguration := tRendererConfiguration.Create;
  cRenderStatus := tRenderStatus.create;
  cCamera := tViewpoint.create;
  ptNormalisedLight := tPoint3d.create;
  ptTranslatedEntityPosition := tPoint3d.create;
  for PIdx := Low( ptPlaneTest ) to High( ptPlaneTest ) do
    ptPlaneTest[ PIdx ] := tPoint3d.Create;
  for PIdx := Low( ptFrustum ) to High( ptFrustum ) do
    ptFrustum[ PIdx ] := tPoint3d.Create;
  cTemporaryBoundingBox := tBoundingBox.create;
  cLightMapManager := tLightMapManager.create;
  cLightMapManager.LightPosition.setLocation( -4, 2, -1 );
  cActiveMessageList := tList.Create;
  cWaterList := tList.Create;
  cWaterList.Capacity := 64;
  cSurfaceSpec := tSurfaceSpecification.Create;
  for Idx := Low( cFrustum ) to High( cFrustum ) do
    cFrustum[ Idx ] := tPlane.Create;
end;

destructor tRenderer.destroy;
var
  Idx : tCubeSurface;
  PIdx : integer;
begin
  unitialiseOpenGL;
  clearVisibilityCache;
  for Idx := Low( cFrustum ) to High( cFrustum ) do
    cFrustum[ Idx ].Free;
  GrenadeIcon.Free;
  cSurfaceSpec.Free;
  cWaterList.Free;
  cActiveMessageList.Free;
  cLightMapManager.free;
  cTemporaryBoundingBox.Free;
  for PIdx := Low( ptFrustum ) to High( ptFrustum ) do
    ptFrustum[ PIdx ].Free;
  for PIdx := Low( ptPlaneTest ) to High( ptPlaneTest ) do
    ptPlaneTest[ PIdx ].Free;
  ptTranslatedEntityPosition.free;
  ptNormalisedLight.free;
  cCamera.free;
  cRenderStatus.Free;
  fConfiguration.Free;
  inherited;
end;

procedure tRenderer.buildFrustumPlanes;   // The constructed planes point inwards towards the interior of the frustum
const
  FrustumVertex : array [ tCubeSurface, 0 .. 2 ] of integer = (
    ( 6, 4, 0 ),  // LEFT
    ( 7, 3, 1 ),  // RIGHT
    ( 2, 3, 7 ),  // TOP
    ( 4, 5, 1 ),  // BOTTOM
    ( 7, 5, 4 ),  // FAR
    ( 3, 2, 0 )   // NEAR
  );
var
  Idx : integer;
  CIdx : tCubeSurface;
  nRatio : glFloat;
  nFarDistance : glFloat;
  mCamera : tMatrix;
  ptCurrent : tPoint3d;
  ptFrustumPlane : array [ 0 .. 2 ] of tPoint3d;
begin
  nFarDistance := getDrawDistance;
  nRatio := IfThen( cRenderStatus.bOrthographic, 1, nFarDistance / nNearDistance );
  mCamera := tMatrixFactory.createAxisMatrix( cCamera.Orientation );
  try
    mCamera.transpose;
    ptCurrent := tPoint3d.create;
    try
      // 1. Transform each of the corner points of the view Frustum into world space
      for Idx := 0 to 7 do
      begin
        if Idx mod 4 and 1 = 0 then ptCurrent.x := -ptScale.x else ptCurrent.x := ptScale.x;
        if Idx mod 4 < 2 then ptCurrent.y := -ptScale.y else ptCurrent.y := ptScale.y;
        if Idx >= 4 then
        begin
          ptCurrent.x := ptCurrent.x * nRatio;
          ptCurrent.y := ptCurrent.y * nRatio;
          ptCurrent.z := -nFarDistance;
        end
        else
          ptCurrent.z := -nNearDistance;
        mCamera.multiply( ptCurrent, ptCurrent );
        ptCurrent.translate( cCamera );
        ptFrustum[ Idx ].setLocation( ptCurrent );
      end;

      // 2. Create six plane objects based on the sides of the Frustum
      for CIdx := Low( cFrustum ) to High( cFrustum ) do
      begin
        for Idx := 0 to 2 do
          ptFrustumPlane[ Idx ] := ptFrustum[ FrustumVertex[ CIdx, Idx ] ];
        cFrustum[ CIdx ].assign( ptFrustumPlane );
      end;
    finally
      ptCurrent.Free;
    end;
  finally
    mCamera.Free;
  end;
end;

function tRenderer.getMapLevel : integer;
begin
  if cGameInformation <> nil then
    result := cGameInformation.Level
  else
    result := fMapLevel;
end;

procedure tRenderer.initialiseOpenGL;

procedure prepareGL;

procedure prepareLighting;
const
  cAmbientLight : array [ 0 .. 3 ] of glFloat = ( 0.0, 0.0, 0.0, 1.0 );
begin
  glEnable( GL_LIGHT0 );
  glEnable( GL_COLOR_MATERIAL );
  glLightModelFV( GL_LIGHT_MODEL_AMBIENT, @cAmbientLight );
  glColorMaterial( GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE );
end;

procedure prepareTexture;
var
  nMipIdx, nSize : integer;
begin
  glTexEnvI( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE );

  glGenTextures( 1, @glStoneTextureID );
  glBindTexture( GL_TEXTURE_2D, glStoneTextureID );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  nSize := 128;
  for nMipIdx := 0 to 7 do
  begin
    glTexImage2d( GL_TEXTURE_2D, nMipIdx, 1, nSize, nSize, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, GetBlockTexture( nMipIdx ) );
    nSize := nSize shr 1;
  end;

  glGenTextures( 1, @glFloorTextureID );
  glBindTexture( GL_TEXTURE_2D, glFloorTextureID );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  nSize := 256;
  for nMipIdx := 0 to 0 do  // Looks better without mip-mapping
  begin
    glTexImage2d( GL_TEXTURE_2D, nMipIdx, 1, nSize, nSize, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, GetFloorTexture( nMipIdx ) );
    nSize := nSize shr 1;
  end;

  glGenTextures( 1, @glShadowTextureID );
  glBindTexture( GL_TEXTURE_2D, glShadowTextureID );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  glTexImage2d( GL_TEXTURE_2D, 0, GL_ALPHA, LM_MAPSIZE, LM_MAPSIZE, 0, GL_ALPHA, GL_UNSIGNED_BYTE, nil );

  glGenTextures( 1, @glWaterShadowTextureID );
  glBindTexture( GL_TEXTURE_2D, glWaterShadowTextureID );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  glTexImage2d( GL_TEXTURE_2D, 0, 1, LM_MAPSIZE, LM_MAPSIZE, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, nil );

  glFontData := glFontCreate( GetFontStructure( 0 ) );
end;

procedure prepareFogging;
var
  Buffer : cardinal;
  FogColour : array [ 0 .. 3 ] of glFloat;
begin
  if Configuration.PerPixelFog < 0 then   // Detect
  begin
    Buffer := 0;
    FillChar( FogColour, SizeOf( FogColour ), 0 );
    glMatrixMode( GL_MODELVIEW );
    glPushMatrix;
    try
      glLoadIdentity;
      glMatrixMode( GL_PROJECTION );
      glPushMatrix;
      try
        glClearColor( 0, 0, 0, 0 );
        glClear( GL_COLOR_BUFFER_BIT );
        glLoadIdentity;
        glViewport( 0, 0, 100, 100 );
        glFrustum( -1, 1, -1, 1, 1, 10 );
        glHint( GL_FOG_HINT, GL_NICEST );
        glFogF( GL_FOG_MODE, GL_LINEAR );
        glFogF( GL_FOG_START, 5 );
        glFogF( GL_FOG_END, 10 );
        glFogFV( GL_FOG_COLOR, @FogColour );
        glEnable( GL_FOG );
        glColor4UBV( @COLOUR_WHITE );
        glBegin( GL_TRIANGLE_STRIP );
          glVertex3F( -100, -1, 100 );
          glVertex3F( -100, -1, -100 );
          glVertex3F( 100, -1, 100 );
          glVertex3F( 100, -1, -100 );
        glEnd;
        glFlush;
        glReadPixels( 50, 0, 1, 1, GL_RGB, GL_UNSIGNED_BYTE, @Buffer );
        if Buffer = 0 then
          Configuration.PerPixelFog := 0    // Per-Pixel Fog didn't work - switch to per-vertex fog
        else
          Configuration.PerPixelFog := 1;   // Per-Pixel Fog works
      finally
        glPopMatrix;
      end;
    finally
      glMatrixMode( GL_MODELVIEW );
      glPopMatrix;
    end;
  end;
end;

begin
  glClearDepth( 1.0 );
  glLineWidth( 2 );
  glDisable( GL_CULL_FACE );
  glFrontFace( GL_CW );
  glCullFace( GL_BACK );
  glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
  prepareFogging;
  prepareLighting;
  prepareTexture;
end;

var
  cPfd : tPixelFormatDescriptor;
begin
  fillChar( cPfd, sizeof( cPfd ), 0 );
  with cPfd do
  begin
    nSize := sizeof( cPfd );
    nVersion := 1;
    dwFlags := PFD_DRAW_TO_WINDOW or PFD_DOUBLEBUFFER or PFD_SUPPORT_OPENGL;
    iPixelType := PFD_TYPE_RGBA;
    cColorBits := Configuration.ColourDepth;
    cDepthBits := Configuration.ZBufferDepth;
    iLayerType := PFD_MAIN_PLANE;
  end;
  nOpenGLId := glhInitialise( cRenderStatus.cControl.Handle, cPfd );
  if not GL_VERSION_1_2 then
    raise Exception.Create( 'Ant Attack requires Open GL v1.2 or later to be installed on your computer. Later versions of Open GL are often available with the latest drivers for your graphics card.' );

  PrepareGL;
end;

procedure tRenderer.clearVisibilityCache;
begin
  if VisibilityCache <> nil then
  begin
    FreeMem( VisibilityCache );
    VisibilityCache := nil;
  end;
end;

procedure tRenderer.createGameMessages;
begin
  if GameInformation.IsAntParalysed then
    MessageList.AddMessage( tMessage.Create( MSG_INFORMATION, 'Paralysed an Ant', 12, 3000 ).SetAlignment( 0.5, 0.5 ).SetPosition( 0, 0.5 ).SetColour( COLOUR_GAME_PARALYSE ).SetFadeTime( 100 ) );
end;

(*
  Taken from http://www.artlum.com/pub/frustumculling.html.

  My original method tested whether each point was inside the frustum, but this didn't work for big bounding boxes that encompassed the frustum.
  This method checks to see whether there is at least one point inside each plane. If so, it is either INTERSECT or INSIDE.
  A further similar to my previous one then compares whether every point is within every plane. If so, it is INSIDE.
*)
function tRenderer.getBoundingBoxClipStatus( const BB : tBoundingBox ) : tClipStatus;
var
  Idx : integer;
  CIdx : tCubeSurface;
  Found : boolean;
  ptPlaneTestScan : ^tPoint3d;    // This routine is called a lot which is why we use this pointer to iterate through the array of points rather than using array notation
begin
  for CIdx := Low( cFrustum ) to High( cFrustum ) do
  begin
    Found := false;
    ptPlaneTestScan := @ptPlaneTest;
    for Idx := 0 to 7 do
    begin
      BB.getPoint( Idx, ptPlaneTestScan^ );
      if Sign( cFrustum[ CIdx ].dotProduct( ptPlaneTestScan^ ) ) > 0 then
      begin
        Found := true;
        break;
      end;
      inc( ptPlaneTestScan );
    end;
    if not Found then
      break;
  end;
  if Found then
  begin
    ptPlaneTestScan := @ptPlaneTest;
    for Idx := 0 to 7 do
    begin
      for CIdx := Low( cFrustum ) to High( cFrustum ) do
      begin
        if Sign( cFrustum[ CIdx ].dotProduct( ptPlaneTestScan^ ) ) <= 0 then
        begin
          result := CLIP_INTERSECT;
          exit;
        end;
      end;
      inc( ptPlaneTestScan );
    end;
    result := CLIP_INSIDE;
  end
  else
    result := CLIP_OUTSIDE;
end;

function tRenderer.getDrawDistance : glFloat;
begin
  if cRenderStatus.nFarDistance <> 0 then
    result := cRenderStatus.nFarDistance
  else
    result := Map.Level[ MapLevel ].Info.DrawDistance;
end;

function tRenderer.getEntityClipStatus( const Entity : tPhysicalEntity ) : tClipStatus;
begin
  with cTemporaryBoundingBox.LeftTopFar do
  begin
    setLocation( Entity.BoundingBox.LeftTopFar );
    translate( Entity.Location );
  end;
  with cTemporaryBoundingBox.RightBottomNear do
  begin
    setLocation( Entity.BoundingBox.RightBottomNear );
    translate( Entity.Location );
  end;

  result := getBoundingBoxClipStatus( cTemporaryBoundingBox );
end;

// Add a clipping plane for the floor, so that any entities emerging from it are clipped. We disable z-buffering when rendering the floor so that the shadows display without any z-fighting
procedure tRenderer.PrepareClipping;
const
  Plane : array [ 0 .. 3 ] of glDouble = ( 0, 1, 0, 0.1 ); // Slight vertical offset to prevent floor from being clipped
begin
  glClipPlane( GL_CLIP_PLANE0, @Plane );
  glDisable( GL_CLIP_PLANE0 );
end;

procedure tRenderer.prepareVisibilityCache;
var
  Size : cardinal;
begin
  if ( VisibilityCache = nil ) and cRenderStatus.bCacheVisibility then
  begin
    Size := SizeOf( Int64 ) * cMap.Width * cMap.Height;
    GetMem( VisibilityCache, Size );
    FillChar( VisibilityCache^, Size, $FF );
  end
  else if ( VisibilityCache <> nil ) and not cRenderStatus.bCacheVisibility then
    clearVisibilityCache;
end;

procedure tRenderer.renderEntityBoundingBox( Entity : tPhysicalEntity );
var
  BB : tBoundingBox;
begin
  BB := Entity.BoundingBox;

  glDisable( GL_FOG );
  glDisable( GL_TEXTURE_2D );

  glBegin( GL_LINE_STRIP );
    glColor3ub( 0, 0, 0 );
    glVertex3f( BB.Left, BB.Bottom, BB.Far );
    glVertex3f( BB.Right, BB.Bottom, BB.Far );
    glVertex3f( BB.Right, BB.Bottom, BB.Near );
    glVertex3f( BB.Left, BB.Bottom, BB.Near );
    glVertex3f( BB.Left, BB.Bottom, BB.Far );
    glVertex3f( BB.Left, BB.Top, BB.Far );
    glVertex3f( BB.Right, BB.Top, BB.Far );
    glVertex3f( BB.Right, BB.Top, BB.Near );
    glVertex3f( BB.Left, BB.Top, BB.Near );
    glVertex3f( BB.Left, BB.Top, BB.Far );
  glEnd;
  glBegin( GL_LINES );
    glVertex3f( BB.Right, BB.Bottom, BB.Far );
    glVertex3f( BB.Right, BB.Top, BB.Far );
    glColor3ub( 255, 255, 255 );
    glVertex3f( BB.Left, BB.Bottom, BB.Near );
    glVertex3f( BB.Left, BB.Top, BB.Near );
    glVertex3f( BB.Right, BB.Bottom, BB.Near );
    glVertex3f( BB.Right, BB.Top, BB.Near );
  glEnd;
end;

procedure tRenderer.renderEntityModel( Entity : tPhysicalEntity; Geometry : tGeometry );

procedure PrepareMaterial( Model : tModel; MaterialIndex : cardinal );
const
  TextureMode : array [ boolean ] of glInt = ( GL_MODULATE, GL_REPLACE );
var
  Material : tMaterial;
  Colour : tColour;
begin
  Material := Model.Material[ MaterialIndex ];
  Colour := Material.Colour;
  if Entity.EntityType.Human then
    Colour := ScaleColour( Colour, tPlayerEntity( Entity ).Visibility );
  glColor4ubv( @Colour );
  if Material.TextureIndex >= 0 then
  begin
    SelectTexture( Model.Texture[ Material.TextureIndex ] );
    glEnable( GL_TEXTURE_2D );
    glSet( GL_BLEND, Model.Texture[ Material.TextureIndex ].BitsPerPixel = 32 );
  end
  else
  begin
    glDisable( GL_TEXTURE_2D );
    glDisable( GL_BLEND );
  end;
  glTexEnvI( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, TextureMode[ Material.AlwaysIlluminate ] );
  glShadeModel( GL_SMOOTH );
end;

var
  Idx, PIdx, VIdx : integer;
  Model : tModel;
  GeometryGroup : tGeometryGroup;
  pVertexData : pModelVertex;
  pVertex : pModelVertex;
  pPrimitive : pModelPrimitive;
  pPrimitiveVertex : pModelPrimitiveVertex;
begin
  Model := Entity.EntityType.Model;
  if Geometry = nil then
  begin
    Geometry := Model.Animation[ Entity.Animation ].GetFrameGeometry( GameInformation.Time - Entity.AnimationTime );
    if Geometry = nil then      // Can be true for sprite animations that have finished
      exit;
  end;
  with Model.Translation do
    glTranslatef( x, y, z );
  if Entity.State = STATE_DEAD then
    glScale( 1, Entity.GetDecay, 1 );
  if Model is tSpriteModel then
  begin
    Model.Orientation.Assign( Camera.Orientation );
    glAlphaFunc( GL_GREATER, 0.1 );
    glEnable( GL_ALPHA_TEST );
  end
  else
    glDisable( GL_ALPHA_TEST );
  glMultMatrixf( pointer( Model.OrientationMatrix ) );
  with Model.Scale do
    glScale( x, y, z );

  for Idx := 0 to Geometry.GroupCount - 1 do
  begin
    GeometryGroup := Geometry.Group[ Idx ];

    PrepareMaterial( Model, GeometryGroup.MaterialIndex );

    pVertexData := GeometryGroup.VertexArray;
    pPrimitive := GeometryGroup.PrimitiveArray;
    for PIdx := 1 to GeometryGroup.PrimitiveCount do
    begin
      case pPrimitive^.Header.Primitive of
        PR_TRIANGLE:
          glBegin( GL_TRIANGLES );
        PR_TRIANGLE_STRIP:
          glBegin( GL_TRIANGLE_STRIP );
        PR_TRIANGLE_FAN:
          glBegin( GL_TRIANGLE_FAN );
      end;

      pPrimitiveVertex := @pPrimitive^.Vertices;
      for VIdx := 1 to pPrimitive^.Header.VertexCount do
      begin
        pVertex := pVertexData;
        inc( pVertex, pPrimitiveVertex^.VertexIndex );
        glTexCoord2fv( @pPrimitiveVertex^.Texture );
        glNormal3fv( @pVertex^.Normal );
        glVertex3fv( @pVertex^.Location );

        inc( pPrimitiveVertex );
      end;

      glEnd;

      pPrimitive := pointer( pPrimitiveVertex );
    end;
  end;
end;

procedure tRenderer.renderEntity( Entity : tPhysicalEntity );
begin
  if Entity.State <> STATE_UNUSED then
  begin
    ptTranslatedEntityPosition.setLocation( Camera );
    ptTranslatedEntityPosition.subtract( Entity.Location );
    if not Entity.EntityType.Solid or not Entity.BoundingBox.Contains( ptTranslatedEntityPosition ) then
    begin
      if getEntityClipStatus( Entity ) <> CLIP_OUTSIDE then
      begin
        glPushMatrix;
        try
          with Entity.Location do
            glTranslatef( x, y, z );
          glRotateY( -Entity.Orientation );

          if RenderStatus.bBoundingBoxes or ( Entity.EntityType.Model = nil ) then
            renderEntityBoundingBox( Entity );

          if Entity.EntityType.Model <> nil then
            renderEntityModel( Entity, nil );
        finally
          glPopMatrix;
        end;
      end;
    end;
  end;
end;

procedure tRenderer.renderSensoryEntity( Entity : tSensoryEntity );
const
  SenseColour : array [ boolean, 0 .. 2 ] of byte = (
    ( 255, 64, 255 ), ( 64, 255, 64 ) );
var
  glSphere : GLUQuadricObj;
  ColourBuffer : array [ 0 .. 3 ] of byte;
  Alpha : _float;
begin
  glPushAttrib( GL_ENABLE_BIT );
  try
    Move( SenseColour[ Entity is tSmell ], ColourBuffer, 3 );
    Alpha := Entity.GetCurrentMagnitude / ( 2 * Entity.Magnitude );
    ColourBuffer[ 3 ] := round( Alpha * 255 );

    glEnable( GL_BLEND );
    glColor4ubv( @ColourBuffer );
    glPushMatrix;

    with Entity.Location do
      glTranslatef( x, y, z );

    glSphere := gluNewQuadric;
    try
      gluQuadricDrawStyle( glSphere, GLU_FILL );
      gluSphere( glSphere, Alpha, 16, 16 );
    finally
      gluDeleteQuadric( glSphere );
    end;

    glPopMatrix;
  finally
    glPopAttrib;
  end;
end;

procedure tRenderer.renderStatusInformation;
const
  HealthGradiant : array [ 0 .. 2 ] of tColour = (
    ( r: 255; g: 0; b: 0; a:0 ),
    ( r: 255; g: 255; b: 0; a:64 ),
    ( r: 0; g: 255; b: 0; a:255 )
  );

  StaminaGradiant : array [ 0 .. 3 ] of tColour = (
    ( r: 64; g: 0; b: 0; a:0 ),
    ( r: 128; g: 0; b: 64; a:64 ),
    ( r: 255; g: 128; b: 128; a:128 ),
    ( r: 255; g: 224; b: 224; a:255 )
  );

  OxygenGradiant : array [ 0 .. 2 ] of tColour = (
    ( r: 0; g: 0; b: 64; a:0 ),
    ( r: 64; g: 192; b: 255; a:64 ),
    ( r: 64; g: 255; b: 255; a:255 )
  );

procedure RenderGradiant( x1, y1, x2, y2, Value : _float; const Gradiant : array of tColour );
var
  Idx, CIdx : integer;
  ps, pf, xs, xf : _float;
  StartColour, FinishColour : tColour;
begin
  glPushAttrib( GL_ENABLE_BIT or GL_LIGHTING_BIT );
  try
    glDisable( GL_TEXTURE_2D );
    glDisable( GL_CULL_FACE );
    glShadeModel( GL_SMOOTH );
    for Idx := 0 to High( Gradiant ) - 1 do
    begin
      StartColour := Gradiant[ Idx ];
      ps := StartColour.a / 255;
      if Value > ps then
      begin
        FinishColour := Gradiant[ Idx + 1 ];
        pf := FinishColour.a / 255;
        if Value < pf then
        begin
          for CIdx := 0 to 2 do
            FinishColour.i[ CIdx ] := Round( StartColour.i[ CIdx ] + ( FinishColour.i[ CIdx ] - StartColour.i[ CIdx ] ) * ( Value - ps ) / ( pf - ps ) );
          pf := Value;
        end;
        xs := x1 + ( x2 - x1 ) * ps;
        xf := x1 + ( x2 - x1 ) * pf;
        glBegin( GL_TRIANGLE_STRIP );
        try
          glColor3ubv( @StartColour );
          glVertex2f( xs, y2 );
          glVertex2f( xs, y1 );
          glColor3ubv( @FinishColour );
          glVertex2f( xf, y2 );
          glVertex2f( xf, y1 );
        finally
          glEnd;
        end;
      end
      else
        break;
    end;
  finally
    glPopAttrib;
  end;
end;

procedure RenderGrenades( x, y : _float; Grenades : integer );
var
  x2, y2 : _float;
begin
  if GrenadeIcon = nil then
    GrenadeIcon := tTextureBase.Create( GetIconTexture( ICON_GRENADE ) );
  SelectTexture( GrenadeIcon );

  glPushAttrib( GL_ENABLE_BIT or GL_TEXTURE_BIT );
  try
    glEnable( GL_TEXTURE_2D );
    glEnable( GL_BLEND );
    glTexEnv( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );

    glBegin( GL_TRIANGLE_STRIP );
      x2 := x + 0.05;
      y2 := y + 0.1;

      glTexCoord2f( 0, 1 );
      glVertex2f( x, y2 );
      glTexCoord2f( 0, 0 );
      glVertex2f( x, y );
      glTexCoord2f( 1, 1 );
      glVertex2f( x2, y2 );
      glTexCoord2f( 1, 0 );
      glVertex2f( x2, y );
    glEnd;

    cMessageList.ClearCategory( MSG_GRENADE );
    cMessageList.AddMessage( tMessage.Create( MSG_GRENADE, IntToStr( Grenades ), 13, 0 ).SetPosition( x2 + 0.02, y ).SetAlignment( 0, 0 ).SetColour( COLOUR_RACING_GREEN ) );
  finally
    glPopAttrib;
  end;
end;

procedure RenderParticipantStatus( Entity : tPhysicalEntity; XFactor, Health, Oxygen, Stamina : _float; Grenades : integer );
const
  LightPosition : array [ 0 .. 3 ] of glFloat = ( 0, 0, 1, 0 );
  AmbientLight : array [ 0 .. 3 ] of glFloat = ( 0.5, 0.5, 0.5, 1 );
  DiffuseLight : array [ 0 .. 3 ] of glFloat = ( 1, 1, 1, 1 );

var
  Animation : cardinal;
  AnimationTime : _float;
  BaseX : _float;
  Geometry : tGeometry;
  ScaleFactor : _float;

begin
  ScaleFactor := ptScale.x / ptScale.y;

  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity;

  glPushAttrib( GL_ENABLE_BIT or GL_LIGHTING_BIT );
  try
    glLightFV( GL_LIGHT0, GL_POSITION, @LightPosition );
    glLightFV( GL_LIGHT0, GL_AMBIENT, @AmbientLight );
    glLightFV( GL_LIGHT0, GL_DIFFUSE, @DiffuseLight );
    glDisable( GL_FOG );
    glEnable( GL_LIGHTING );
    glEnable( GL_CULL_FACE );
    glEnable( GL_DEPTH_TEST );

    glTranslate( 3 * XFactor * ScaleFactor, 2.3, -6 );

    glRotatef( 20, 1, 0, 0 );
    glRotatef( 45 * XFactor, 0, -1, 0 );
    if ( Entity.State <> STATE_QUIESCENT ) and ( Entity.State <> STATE_DEAD ) then
    begin
      Animation := ANIMATION_HUMAN_WAIT;
      AnimationTime := GameInformation.Time;
    end
    else
    begin
      Animation := Entity.Animation;
      AnimationTime := GameInformation.Time - Entity.AnimationTime;
    end;
    Geometry := Entity.EntityType.Model.Animation[ Animation ].GetFrameGeometry( AnimationTime );
    renderEntityModel( Entity, Geometry );

    glDisable( GL_LIGHTING );
    glMatrixMode( GL_PROJECTION );
    glPushMatrix;
    try
      glLoadIdentity;
      glOrtho( -1, 1, 1, -1, -1, 1 );
      glMatrixMode( GL_MODELVIEW );
      glLoadIdentity;

      if XFactor < 0 then
        BaseX := -0.95
      else
        BaseX := 0.8;
      if Health > 0 then
      begin
        RenderGradiant( BaseX, -0.6, BaseX + 0.15, -0.63, Health, HealthGradiant );
        RenderGradiant( BaseX, -0.54, BaseX + 0.15, -0.57, Stamina, StaminaGradiant );
        if Oxygen < 1 then
          RenderGradiant( BaseX, -0.48, BaseX + 0.15, -0.51, Oxygen, OxygenGradiant );
      end;
      if Grenades >= 0 then
        RenderGrenades( BaseX + 0.17, -0.78, Grenades );
    finally
      glMatrixMode( GL_PROJECTION );
      glPopMatrix;
      glMatrixMode( GL_MODELVIEW );
    end;
  finally
    glPopAttrib;
  end;
end;

begin
  if ( GameInformation <> nil ) and not Configuration.HideStatus then
  begin
    glClear( GL_DEPTH_BUFFER_BIT );
    with GameInformation do
    begin
      CreateGameMessages;
      if IsRescuerPresent then
        RenderParticipantStatus( Rescuer, -1, RescuerHealth, RescuerOxygen, RescuerStamina, RescuerGrenades );
      if IsRescueePresent then
        RenderParticipantStatus( Rescuee, 1, RescueeHealth, RescueeOxygen, RescueeStamina, -1 );
      GameInformation.ResetRenderingData;
    end;
  end;
end;

procedure tRenderer.renderFloor;
var
  Extent : glFloat;
  EnlargementFactor : glFloat;
  MinStep : glFloat;
  Step : glFloat;
  GroundColour : tColour;
  x, z, zs, x1, x2, z1, z2 : glFloat;
begin
  if cRenderStatus.bFloor then
  begin
    glPushAttrib( GL_ENABLE_BIT or GL_DEPTH_BUFFER_BIT or GL_HINT_BIT );
    try
      glEnable( GL_CULL_FACE );
      glDisable( GL_DEPTH_TEST );
      glDepthMask( GL_FALSE );
      glSet( GL_TEXTURE_2D, cRenderStatus.bTexturing and cRenderStatus.bTextureFloor );
      glBindTexture( GL_TEXTURE_2D, glFloorTextureID );

      if Configuration.PerPixelFog = 0 then     // This is for when the fog is calculated per-vertex
      begin
        Extent := getDrawDistance;
        MinStep := Max( Extent / 15, 2 );
        EnlargementFactor := Min( 1 / 0.707, Max( 1, ( 1 / 0.707 ) * ( cCamera.y / 5 ) ) );
        Step := Max( ( Extent / 2 ) - ( cCamera.y * 3 ), MinStep );
        Extent := Extent * EnlargementFactor;        // Total hack to give plenty of space around the edge. I'm too thick to calculate it properly.
      end
      else
      begin                                     // This is for when the fog is calculated per-pixel
        Extent := 2000;
        Step := 2 * Extent;
      end;

      x1 := Camera.x - Extent;
      x2 := Camera.x + Extent + STEP;
      z1 := Camera.z - Extent;
      z2 := Camera.z + Extent;

      GroundColour := ScaleColour( cMap.Header^.Palette[ PAL_GROUND ], SurfaceLightData[ CS_TOP ].LightIntensity );
      glColor3ubv( @GroundColour );
      z := z1;
      repeat
        zs := z + STEP;
        glBegin( GL_TRIANGLE_STRIP );
        x := x1;
        repeat
          glTexCoord2f( x, zs );
          glVertex3F( x, 0, zs );
          glTexCoord2f( x, z );
          glVertex3F( x, 0, z );
          x := x + STEP;
        until x >= x2;
        glEnd;
        z := z + STEP;
      until z >= z2;
      inc( RenderStatus.nPolyCount, ( 1 + Trunc( Extent * 2 ) div Trunc( STEP ) ) * ( 1 + Trunc( Extent * 2 + STEP ) div Trunc( STEP ) ) );
    finally
      glPopAttrib;
    end;
  end;
end;

procedure tRenderer.renderSunburst;
const
  STEPS = 24;
  SunColour : array [ boolean, 0 .. 2 ] of byte = (
    ( 255, 98, 21 ), ( 255, 255, 128 ) );
var
  ColourBuffer : array [ 0 .. 2, 0 .. 3 ] of glFloat;
  nFactor, nBurst : _float;
  Angle, S, C : _float;
  nMatrix : array [ 0 .. 15 ] of glFloat;
  SineTable : array [ 0 .. STEPS, 0 .. 1 ] of glFloat;
  Idx : integer;
begin
  if RenderStatus.bSun then
  begin
    glPushAttrib( GL_ENABLE_BIT or GL_COLOR_BUFFER_BIT or GL_LIGHTING_BIT );
    try
      glDisable( GL_DEPTH_TEST );
      glDisable( GL_FOG );
      glDisable( GL_TEXTURE_2D );

      nFactor := Min( Max( ptNormalisedLight.y * 2, 0 ), 1 );
      nBurst := 2 + nFactor * 6;
      for Idx := 0 to 2 do
      begin
        ColourBuffer[ 1, Idx ] := ( SunColour[ false, Idx ] + ( ( SunColour[ true, Idx ] - SunColour[ false, Idx ] ) * nFactor ) ) / 255;
        ColourBuffer[ 0, Idx ] := ColourBuffer[ 1, Idx ] * Max( ( 0.5 + nFactor ), 1 );   // Create a hot centre
      end;
      ColourBuffer[ 0, 3 ] := 1;
      ColourBuffer[ 1, 3 ] := 1;

      glPushMatrix;
      try
        glTranslatef( cCamera.x, cCamera.y, cCamera.z );
        glTranslatef( ptNormalisedLight.x * 10, ptNormalisedLight.y * 10, ptNormalisedLight.z * 10 );

        glgGetAxis( Camera.Orientation, nMatrix, false );
        glMultMatrixf( @nMatrix );

        glShadeModel( GL_SMOOTH );

        glBegin( GL_TRIANGLE_FAN );
          Angle := 0;
          nFactor := 0.4 - nFactor * 0.1;

          glColor4FV( @ColourBuffer[ 0 ] );
          glVertex2f( 0, 0 );

          glColor4FV( @ColourBuffer[ 1 ] );
          for Idx := 0 to STEPS do
          begin
            S := Sin( Angle ) * nFactor;
            C := Cos( Angle ) * nFactor;
            SineTable[ Idx, 0 ] := S;
            SineTable[ Idx, 1 ] := C;
            glVertex2f( S, C );
            Angle := Angle + 2 * PI / STEPS;
          end;
        glEnd;

        glGetFloatV( GL_FOG_COLOR, @ColourBuffer[ 2 ] );
        ColourBuffer[ 2, 3 ] := 0;
        glEnable( GL_BLEND );

        glBegin( GL_TRIANGLE_STRIP );
          for Idx := 0 to STEPS do
          begin
            S := SineTable[ Idx, 0 ];
            C := SineTable[ Idx, 1 ];
            glColor4FV( @ColourBuffer[ 1 ] );
            glVertex2F( S, C );
            glColor4FV( @ColourBuffer[ 2 ] );
            glVertex2F( S * nBurst, C * nBurst );
          end;
        glEnd;
      finally
        glPopMatrix;
      end;
    finally
      glPopAttrib;
    end;
  end;
end;

procedure tRenderer.renderGame;
var
  Idx : integer;
begin
  if cGameInformation <> nil then
  begin
    glPushAttrib( GL_ENABLE_BIT or GL_LIGHTING_BIT or GL_TEXTURE_BIT or GL_COLOR_BUFFER_BIT );
    try
      glEnable( GL_DEPTH_TEST );
      glEnable( GL_CLIP_PLANE0 );
      glEnable( GL_CULL_FACE );
      glDisable( GL_BLEND );
      glEnable( GL_LIGHTING );
      glEnable( GL_NORMALIZE );
      for Idx := 0 to GameInformation.PhysicalEntityList.Count - 1 do
        renderEntity( tPhysicalEntity( GameInformation.PhysicalEntityList[ Idx ] ) );
    finally
      glPopAttrib;
    end;
  end;


  // Testing only
{  if cGameInformation <> nil then
    for Idx := 0 to GameInformation.EntityList.Count - 1 do
      if tObject( GameInformation.EntityList[ Idx ] ) is tSensoryEntity then
        renderSensoryEntity( tSensoryEntity( GameInformation.EntityList[ Idx ] ) );}
end;

procedure tRenderer.renderMessage( Msg : tMessage );
var
  Scale : glFloat;
begin
  glPushMatrix;
  glTranslate( Msg.Position.x, Msg.Position.y, 0 );
  Scale := Msg.Size / 200;
  glScalef( Scale, Scale, Scale );
  glFontTextOut( Msg.Description, 0, 0, 0, Msg.Alignment.x, Msg.Alignment.y, Msg.CurrentColour.rgba, Msg.CurrentBackgroundColour.rgba, false );
  glPopMatrix;
end;

procedure tRenderer.renderMessages;
var
  Idx : integer;
begin
  if ( cMessageList <> nil ) and ( glFontData <> nil ) then
  begin
    glMatrixMode( GL_PROJECTION );
    glPushMatrix;
    try
      glLoadIdentity;
      glOrtho( -1, 1, 1, -1, -1, 1 );

      glMatrixMode( GL_MODELVIEW );
      glLoadIdentity;

      glPushAttrib( GL_ENABLE_BIT or GL_DEPTH_BUFFER_BIT );
      try
        glDisable( GL_DEPTH_TEST );
        glDepthMask( GL_FALSE );

        glEnable( GL_TEXTURE_2D );
        glEnable( GL_BLEND );
        glFontBegin( glFontData );

        cMessageList.GetActiveMessages( cActiveMessageList );
        for Idx := 0 to cActiveMessageList.Count - 1 do
          renderMessage( tMessage( cActiveMessageList[ Idx ] ) );

        glFontEnd;
      finally
        glPopAttrib;
      end;
    finally
      glMatrixMode( GL_PROJECTION );
      glPopMatrix;
      glMatrixMode( GL_MODELVIEW );
    end;
  end;
end;

procedure tRenderer.render;
var
  bInWater : boolean;

procedure prepareLightMap;
begin
  if cGameInformation <> nil then
    MapLevel := cGameInformation.Level;
end;

procedure setOptions;
var
  nMipMap : glInt;
begin
  glDepthFunc( GL_LESS );
  glDisable( GL_LIGHTING );
  glSet( GL_TEXTURE_2D, cRenderStatus.bTexturing );
  glSet( GL_FOG, cRenderStatus.nFog > 0 );
  glHint( GL_FOG_HINT, GL_NICEST );   // We need the fog to be calculated per-pixel for a nice shaded floor
  glDisable( GL_BLEND );
  glDisable( GL_CULL_FACE );
  glShadeModel( GL_FLAT );
  if cRenderStatus.bMipMap then nMipMap := GL_LINEAR_MIPMAP_NEAREST else nMipMap := GL_LINEAR;
  glBindTexture( GL_TEXTURE_2D, glStoneTextureID );
  glTexParameterI( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, nMipMap );
  cRenderStatus.nPolyCount := 0;
  cLightMapManager.LowQuality := ( cRenderStatus.nLightMap = LM_LOW );
end;

procedure setProjection;
var
  nFarDistance : glFloat;
  nRatio : glFloat;
begin
  with cRenderStatus.cControl do
  begin
    glViewport( 0, 0, Width, Height );
    nRatio := Width / Height;
  end;
  ptScale.y := cRenderStatus.nScale;
  ptScale.x := ptScale.y * nRatio;

  glMatrixMode( GL_PROJECTION );
  glLoadIdentity;
  nNearDistance := ptScale.y / tan( PI * cRenderStatus.nFOV / 360 );
  nFarDistance := getDrawDistance;

  if nFarDistance >= cRenderStatus.nFog then
  begin
    glFogI( GL_FOG_MODE, GL_LINEAR );
    glFogF( GL_FOG_START, nNearDistance + ( nFarDistance - nNearDistance ) * 0.8 );
    glFogF( GL_FOG_END, nFarDistance );
  end
  else
  begin
    glFogI( GL_FOG_MODE, GL_EXP2 );
    glFogF( GL_FOG_DENSITY, Sqrt( -Ln( cRenderStatus.nFogDensity ) ) / nFarDistance );
  end;

  if cRenderStatus.bOrthographic then
  begin
    nNearDistance := 0.01;
    glOrtho( -ptScale.y, ptScale.y, -ptScale.y, ptScale.y, nNearDistance, nFarDistance );
    glScale( 1, 2 * Sin( PI / 4 ), 1 );
  end
  else
    glFrustum( -ptScale.x, ptScale.x, -ptScale.y, ptScale.y, nNearDistance, nFarDistance );
  buildFrustumPlanes;
end;

procedure setCamera;
var
  mCamera : array [ 0 .. 15 ] of glFloat;
begin
  glMatrixMode( GL_MODELVIEW );
  glgGetAxis( cCamera.Orientation, mCamera );
  glLoadMatrixf( @mCamera );
  glTranslateF( -cCamera.x, -cCamera.y, -cCamera.z );
  bInWater := cMap.isPointInWater( cCamera );
end;

procedure setLight;
var
  AmbientIntensity : glFloat;
  DiffuseIntensity : glFloat;

procedure normaliseLight;
begin
  ptNormalisedLight.setLocation( LightMapManager.LightPosition );
  ptNormalisedLight.normalise;
end;

procedure setLightIntensity;
const
  BaseAmbientIntensity = 0.7;
  BaseDiffuseIntensity = 0.9;

  cSkyColour    : array [ 0 .. 5, 0 .. 3 ] of glFloat = (
    ( 0.0, 0.0, 0.0, 1.0 ),
    ( 0.0, 0.0, 0.0, 1.0 ),
    ( 0.2, 0.05, 0.0, 1.0 ),
    ( 0.0, 0.1, 0.5, 1.0 ),
    ( 0.2, 0.4, 0.8, 1.0 ),
    ( 0.4, 1.0, 1.0, 1.0 ) );

  cYTrigger     : array [ 0 .. 5 ] of glFloat = ( -1.0, -0.3, 0.08, 0.2, 0.4, 1.0 );

var
  nIdx, nSkyIdx : integer;
  nLightIntensity : glFloat;
  cActualLight : array [ 0 .. 3 ] of glFloat;

procedure DefineLight( Intensity : glFloat; LightType : glUInt );
var
  Idx : integer;
begin
  for Idx := 0 to 2 do
    cActualLight[ Idx ] := Intensity;
  glLightFV( GL_LIGHT0, LightType, @cActualLight );
end;

begin
  nLightIntensity := Min( Max( ptNormalisedLight.y * 1.2 + 0.3, 0.05 ), 1 );
  if not cRenderStatus.bLighting then nLightIntensity := 1;

  cActualLight[ 3 ] := 1.0;

  AmbientIntensity := Max( BaseAmbientIntensity * nLightIntensity - 0.25, 0 );
  DefineLight( AmbientIntensity, GL_AMBIENT );

  DiffuseIntensity := BaseDiffuseIntensity * nLightIntensity;
  DefineLight( DiffuseIntensity, GL_DIFFUSE );

  nSkyIdx := 1;
  repeat
    if ptNormalisedLight.y <= cYTrigger[ nSkyIdx ] then
    begin
      nLightIntensity := 1 / ( cYTrigger[ nSkyIdx ] - cYTrigger[ nSkyIdx - 1 ] ) * ( ptNormalisedLight.y - cYTrigger[ nSkyIdx - 1 ] );
      for nIdx := 0 to 2 do
        cActualLight[ nIdx ] := ( cSkyColour[ nSkyIdx, nIdx ] * nLightIntensity ) + ( cSkyColour[ nSkyIdx - 1, nIdx ] * ( 1.0 - nLightIntensity ) );
      nSkyIdx := 0;
    end;
    inc( nSkyIdx );
  until nSkyIdx = 1;

  glClearColor( cActualLight[ 0 ], cActualLight[ 1 ], cActualLight[ 2 ], cActualLight[ 3 ] );
  glFogFV( GL_FOG_COLOR, @cActualLight );
end;

procedure setLightPosition;
var
  cLightPosition : array [ 0 .. 3 ] of glFloat;
begin
  cLightPosition[ 0 ] := ptNormalisedLight.x;
  cLightPosition[ 1 ] := ptNormalisedLight.y;
  cLightPosition[ 2 ] := ptNormalisedLight.z;
  cLightPosition[ 3 ] := 0.0;
  glLightFV( GL_LIGHT0, GL_POSITION, @cLightPosition );
end;

procedure setLightFaces;
var
  ptNormal : tPoint3d;
  idx : tCubeSurface;
  DotProduct : glFloat;
  Illumination : glFloat;
  Palette : tPalette;
begin
  ptNormal := tPoint3d.Create;
  try
    for idx := low( tCubeSurface ) to high( tCubeSurface ) do
    begin
      ptNormal.setLocation( ptBoxNormal[ idx ] );
      DotProduct := ptNormalisedLight.dotProductSq( ptNormal );
      if not RenderStatus.bLighting then DotProduct := 1; 
      Illumination := Min( AmbientIntensity + Max( DiffuseIntensity * DotProduct, 0 ), 1 );
      with SurfaceLightData[ idx ] do
      begin
        FacesLight := DotProduct > 0;
        LightIntensity := Illumination;                         // The intensity of the light on this surface
        ShadowIntensity := AmbientIntensity;                    // The intensity of the shadows on this surface so that they are all uniformly the ambient colour
        if LightIntensity > 0 then
          ShadeIntensity := Round( 255 - ( ShadowIntensity / LightIntensity ) * 255 )       // The value used by the Light Map Manager
        else
          ShadeIntensity := 255;

        for Palette := Low( tPalette) to High( tPalette ) do
          Colour[ Palette, true ] := ScaleColour( cMap.Header^.Palette[ Palette ], LightIntensity );

        if FacesLight then
          for Palette := Low( tPalette) to High( tPalette ) do
            Colour[ Palette, false ] := ScaleColour( cMap.Header^.Palette[ PAlette ], ShadowIntensity )
        else
          for Palette := Low( tPalette) to High( tPalette ) do
            Colour[ Palette, false ] := Colour[ Palette, true ];

        Colour[ PAL_WATER, false ].a := WATER_ALPHA;
        Colour[ PAL_WATER, true ].a := WATER_ALPHA;
      end;
    end;
  finally
    ptNormal.Free;
  end;
end;

begin
  normaliseLight;
  setLightIntensity;
  setLightPosition;
  setLightFaces;
end;

procedure clearBuffers;
begin
  glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
end;

procedure renderSquareSurface;
var
  pSurfaceCoordinates : ^tSquareSurfaceCoordinates;
begin
  pSurfaceCoordinates := @ptBoxVertex[ cSurfaceSpec.cSurface ];
  glTexCoord2F( 1.0, 0 );
  glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 0, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 0, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 0, 2 ] );
  glTexCoord2F( 0, 0 );
  glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 1, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 1, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 1, 2 ] );
  glTexCoord2F( 1.0, 1.0 );
  glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 3, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 3, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 3, 2 ] );
  glTexCoord2F( 0, 1.0 );
  glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 2, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 2, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 2, 2 ] );
  inc( cRenderStatus.nPolyCount );
end;

procedure renderSquareShadow( PixelData : pointer );
begin
  glBindTexture( GL_TEXTURE_2D, glShadowTextureID );
  glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, LM_MAPSIZE, LM_MAPSIZE, GL_ALPHA, GL_UNSIGNED_BYTE, PixelData );
  glEnable( GL_BLEND );
  glColor3ub( 0, 0, 0 );
  glBegin( GL_TRIANGLE_STRIP );
    renderSquareSurface;
  glEnd;
  glDisable( GL_BLEND );
  glBindTexture( GL_TEXTURE_2D, glStoneTextureID );
end;

procedure renderSolidSquareShadow;
var
  pSurfaceCoordinates : ^tSquareSurfaceCoordinates;
begin
  pSurfaceCoordinates := @ptBoxVertex[ cSurfaceSpec.cSurface ];

  glDisable( GL_TEXTURE_2D );
  glEnable( GL_BLEND );
  glColor4ub( 0, 0, 0, cLightMapManager.ShadeIntensity );
  glBegin( GL_TRIANGLE_STRIP );
    glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 0, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 0, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 0, 2 ] );
    glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 1, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 1, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 1, 2 ] );
    glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 3, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 3, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 3, 2 ] );
    glVertex3F( cSurfaceSpec.x + pSurfaceCoordinates^[ 2, 0 ], cSurfaceSpec.y + pSurfaceCoordinates^[ 2, 1 ], cSurfaceSpec.z + pSurfaceCoordinates^[ 2, 2 ] );
    inc( cRenderStatus.nPolyCount );
  glEnd;
  glDisable( GL_BLEND );
  glSet( GL_TEXTURE_2D, cRenderStatus.bTexturing );
end;

procedure renderWater;
const
  ptNormal : array [ 0 .. 2 ] of glFloat = ( 0, 1, 0 );
  ptTexture : array [ 0 .. 3, 0 .. 1 ] of glFloat = ( ( 1.0, 0 ), ( 1.0, 1.0 ), ( 0, 0 ), ( 0, 1.0 )  );
  ptWater : array [ 0 .. 3 ] of tFloatArray = ( ( 1, 1 - WATER_OFFSET, 1 ), ( 0, 1 - WATER_OFFSET, 1 ), ( 1, 1 - WATER_OFFSET, 0 ), ( 0, 1 - WATER_OFFSET, 0 ) );
var
  Idx, VIdx, Count : integer;
  p, x, y, z : integer;
  AlwaysShade : boolean;
  LightMapType : tLightMapType;
  PixelData : tLightMapPixelData;
  WaterColour : tColour;
  Vertex : pFloatArray;
begin
  Count := cWaterList.Count;
  if bInWater or ( Count > 0 ) then
  begin
    glPushAttrib( GL_ENABLE_BIT or GL_DEPTH_BUFFER_BIT );
    try
      glDisable( GL_TEXTURE_2D );
      glEnable( GL_BLEND );
      if bInWater then
      begin
        WaterColour := cMap.Header^.Palette[ PAL_WATER ];
        WaterColour.a := WATER_ALPHA;
        glDisable( GL_DEPTH_TEST );
        glDepthMask( GL_FALSE );
        glLoadIdentity;
        glMatrixMode( GL_PROJECTION );
        glPushMatrix;
        glLoadIdentity;
        glColor4ubv( @WaterColour );
        glBegin( GL_TRIANGLE_STRIP );
          glVertex2f( -1, -1 );
          glVertex2f( -1, 1 );
          glVertex2f( 1, -1 );
          glVertex2f( 1, 1 );
        glEnd;
        glPopMatrix;
        glMatrixMode( GL_MODELVIEW );
      end
      else
      begin
        glBindTexture( GL_TEXTURE_2D, glWaterShadowTextureID );
        cLightMapManager.ShadeIntensity := SurfaceLightData[ CS_TOP ].ShadeIntensity;
        cSurfacespec.bWater := true;
        cSurfaceSpec.cSurface := CS_TOP;
        AlwaysShade := ( RenderStatus.nLightMap <> LM_NONE ) and not SurfaceLightData[ CS_TOP ].FacesLight;
        LightMapType := LM_LIGHT;

        glEnable( GL_CULL_FACE );
        glEnable( GL_DEPTH_TEST );
        for Idx := Count - 1 downto 0 do
        begin
          p := integer( cWaterList[ Idx ] );
          x := p shr 18;
          y := p and $F;
          z := ( p shr 4 ) and $3FFF;

          glNormal3fv( @ptNormal );

          if RenderStatus.nLightMap <> LM_NONE then
          begin
            if not AlwaysShade then
            begin
              cSurfaceSpec.x := x;
              cSurfaceSpec.y := y;
              cSurfaceSpec.z := z;
              LightMapType := cLightMapManager.getLightMapPixelData( cSurfaceSpec, @PixelData );
            end
            else
              LightMapType := LM_SHADE;

            if LightMapType = LM_MIXED then
            begin
              glEnable( GL_TEXTURE_2D );
              glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, LM_MAPSIZE, LM_MAPSIZE, GL_LUMINANCE, GL_UNSIGNED_BYTE, @PixelData );
            end
            else
              glDisable( GL_TEXTURE_2D );
          end;

          glColor4ubv( @SurfaceLightData[ CS_TOP ].Colour[ PAL_WATER, LightMapType <> LM_SHADE ] );

          glBegin( GL_TRIANGLE_STRIP );
          if LightMapType = LM_MIXED then
          begin
            for VIdx := 0 to 3 do
            begin
              Vertex := @ptWater[ VIdx ];
              glTexCoord2fv( @ptTexture[ VIdx ] );
              glVertex3f( x + Vertex^[ 0 ], y + Vertex^[ 1 ], z + Vertex^[ 2 ] );
            end;
          end
          else
            for VIdx := 0 to 3 do
            begin
              Vertex := @ptWater[ VIdx ];
              glVertex3f( x + Vertex^[ 0 ], y + Vertex^[ 1 ], z + Vertex^[ 2 ] );
            end;
          glEnd;

        end;
      end;
    finally
      glPopAttrib;
    end;
  end;
end;

procedure renderScene;
type
  tNode = array [ 0 .. 1 ] of tPoint;

function getNodeState( const cNode : tNode ) : tClipStatus;
begin
  with cTemporaryBoundingBox do
  begin
    Left := cNode[ 0 ].x;
    Right := cNode[ 1 ].x;
    Far := cNode[ 0 ].y;
    Near := cNode[ 1 ].y;
  end;
  result := getBoundingBoxClipStatus( cTemporaryBoundingBox );
end;

procedure renderArea( const cNode : tNode );
const
  PaletteXRef : array [ boolean ] of tPalette = ( PAL_DARK, PAL_LIGHT );

var
  pBlockData : pBlockArray;
  BlockType : tBlockType;

procedure drawSurface;

function isSurfaceSpecVisible : boolean;
begin
  with cSurfaceSpec do
    case cSurface of
      CS_LEFT:
        result := cCamera.x < x;
      CS_RIGHT:
        result := cCamera.x > x + 1;
      CS_TOP:
        result := cCamera.y > y + 1;
      CS_BOTTOM:
        result := cCamera.y < y;
      CS_FAR:
        result := cCamera.z < z;
      CS_NEAR:
        result := cCamera.z > z + 1;
    else
      result := false;    // Can't happen
    end;
end;

var
  LightMapType : tLightMapType;
  PixelData : tLightMapPixelData;
begin
  if not bPerformHiddenBlockTest or isSurfaceSpecVisible then
  begin
    if cRenderStatus.nLightMap <> LM_NONE then
      if SurfaceLightData[ cSurfaceSpec.cSurface ].FacesLight then
      begin
        cLightMapManager.ShadeIntensity := SurfaceLightData[ cSurfaceSpec.cSurface ].ShadeIntensity;
        LightMapType := cLightMapManager.getLightMapPixelData( cSurfaceSpec, @PixelData );
      end
      else
        LightMapType := LM_SHADE
    else
      LightMapType := LM_LIGHT;

    glColor4ubv( @SurfaceLightData[ cSurfaceSpec.cSurface ].Colour[ PaletteXRef[ bEvenBlock ], LightMapType <> LM_SHADE ] );
    glBegin( GL_TRIANGLE_STRIP );
      renderSquareSurface;
    glEnd;

    if LightMapType = LM_MIXED then
    begin
      glDepthFunc( GL_EQUAL );
      renderSquareShadow( @PixelData );
      glDepthFunc( GL_LESS );
    end;
  end;
end;

procedure drawPillar;

procedure DrawCylinder;
var
  Slice, Steps : integer;
  Factor, TexFactor, Angle : _float;
  ox, oy1, oy2, oz : _float;
  sx, sy, sz : _float;
begin
  glEnable( GL_LIGHTING );
  glColor4ubv( @SurfaceLightData[ CS_TOP ].Colour[ PaletteXRef[ bEvenBlock ], true ] );

  ox := cSurfaceSpec.x + 0.5;
  oy1 := cSurfaceSpec.y + 0.1;
  oy2 := cSurfaceSpec.y + 0.9;
  oz := cSurfaceSpec.z + 0.5;

  sx := ( cCamera.x - cSurfaceSpec.x + 0.5 );
  sy := ( cCamera.y - cSurfaceSpec.y + 0.5 );
  sz := ( cCamera.z - cSurfaceSpec.z + 0.5 );
  Factor := Sqrt( sx * sx + sy * sy + sz * sz );
  Steps := Round( 36 - Factor * 2 );
  if Steps < 4 then Steps := 4;
  if Steps > 32 then Steps := 32;

  Factor := 2 * PI / Steps;
  TexFactor := 0.90 / Steps;
  glBegin( GL_TRIANGLE_STRIP );
    for Slice := 0 to Steps do
    begin
      Angle := Slice * Factor;
      sx := Sin( Angle );
      sz := Cos( Angle );
      glNormal3f( sx, 0, sz );
      sx := sx * 0.15;
      sz := sz * 0.15;
      glTexCoord2f( Slice * TexFactor, 0 );
      glVertex3f( ox + sx, oy1, oz + sz );
      glTexCoord2f( Slice * TexFactor, 1 );
      glVertex3f( ox + sx, oy2, oz + sz );
    end;
  glEnd;
  glDisable( GL_LIGHTING );
  inc( cRenderStatus.nPolyCount, Steps * 2 );
end;

procedure drawPlinth( y : _float );
var
  Idx : tCubeSurface;
  pSurfaceCoordinates : ^tSquareSurfaceCoordinates;
begin
  for Idx := low( tCubeSurface ) to high( tCubeSurface ) do
  begin
    pSurfaceCoordinates := @ptBoxVertex[ Idx ];
    glColor4ubv( @SurfaceLightData[ Idx ].Colour[ PaletteXRef[ bEvenBlock ], true ] );
    glBegin( GL_TRIANGLE_STRIP );
      glTexCoord2F( 1.0, 0 );
      glVertex3F( pSurfaceCoordinates^[ 0, 0 ], y + pSurfaceCoordinates^[ 0, 1 ], pSurfaceCoordinates^[ 0, 2 ] );
      glTexCoord2F( 0, 0 );
      glVertex3F( pSurfaceCoordinates^[ 1, 0 ], y + pSurfaceCoordinates^[ 1, 1 ], pSurfaceCoordinates^[ 1, 2 ] );
      glTexCoord2F( 1.0, 1.0 );
      glVertex3F( pSurfaceCoordinates^[ 3, 0 ], y + pSurfaceCoordinates^[ 3, 1 ], pSurfaceCoordinates^[ 3, 2 ] );
      glTexCoord2F( 0, 1.0 );
      glVertex3F( pSurfaceCoordinates^[ 2, 0 ], y + pSurfaceCoordinates^[ 2, 1 ], pSurfaceCoordinates^[ 2, 2 ] );
    glEnd;
  end;
  inc( cRenderStatus.nPolyCount, CUBE_SURFACES );
end;

begin
  glPushMatrix;
  glPushAttrib( GL_ENABLE_BIT );
  try
    DrawCylinder;
    with cSurfaceSpec do
      glTranslateF( x + 0.25, y, z + 0.25 );
    glScaleF( 0.5, 0.1, 0.5 );
    DrawPlinth( 0 );
    DrawPlinth( 9 );
  finally
    glPopAttrib;
    glPopMatrix;
  end;
end;

function renderBlock : byte;
var
  AdjacentBlocks : tAdjacentBlocks;
  Idx : tCubeSurface;
begin
  result := 0;

  with cSurfaceSpec do
  begin
    Map.getAdjacentBlocks( x, y, z, AdjacentBlocks );
    bEvenBlock := ( ( x + y + z ) and 1 ) = 0;
  end;

  case BlockType of
    BLOCK_SOLID:
    begin
      bPerformHiddenBlockTest := true;
      for Idx := Low( tCubeSurface ) to high( tCubeSurface ) do
      begin
        result := result shr 1;
        if AdjacentBlocks[ Idx ] <> BLOCK_SOLID then
        begin
          cSurfaceSpec.cSurface := Idx;
          drawSurface;
          result := result or 32;
        end;
      end;
    end;
    BLOCK_PILLAR:
      drawPillar;
    BLOCK_WATER:
      if not bInWater and ( AdjacentBlocks[ CS_TOP ] <> BLOCK_WATER ) then
        with cSurfaceSpec do
          cWaterList.Add( Pointer( ( x shl 18 ) or ( z shl 4 ) or y ) );
  end;
end;

function renderFloorShadow : byte;
var
  LightMapType : tLightMapType;
  PixelData : tLightMapPixelData;
begin
  result := 0;
  if cRenderStatus.nLightMap <> LM_NONE then
  begin
    cSurfaceSpec.cSurface := CS_TOP;
    cSurfaceSpec.y := LM_GROUND;
    cLightMapManager.ShadeIntensity := SurfaceLightData[ CS_TOP ].ShadeIntensity;
    LightMapType := cLightMapManager.getLightMapPixelData( cSurfaceSpec, @PixelData );
    case LightMapType of
      LM_MIXED:
      begin
        renderSquareShadow( @PixelData );
        result := 1;
      end;
      LM_SHADE:
      begin
        renderSolidSquareShadow;
        result := 1;
      end;
    end;
  end;
end;

procedure renderBlockFast( Visibility : int64 );
var
  y : integer;
  Surface : tCubeSurface;
  Mask : int64;
begin
  bPerformHiddenBlockTest := false;

  Mask := $130C30C30C30C;               // TOP, BOTTOM & FLOOR SHADOW - 1001100001100001100001100001100001100001100001100
  with cSurfaceSpec do
  begin
    if cCamera.x < x then
      Mask := Mask or $41041041041      // LEFT   - 000001000001000001000001000001000001000001000001
    else if cCamera.x > x + 1 then
      Mask := Mask or $82082082082;     // RIGHT  - 000010000010000010000010000010000010000010000010
    if cCamera.z < z then
      Mask := Mask or $410410410410     // FAR    - 010000010000010000010000010000010000010000010000
    else if cCamera.z > z + 1 then
      Mask := Mask or $820820820820;    // NEAR   - 100000100000100000100000100000100000100000100000
  end;

  Visibility := Visibility and Mask;
  if Visibility <> 0 then
  begin
    bEvenBlock := ( ( cSurfaceSpec.x + cSurfaceSpec.z ) and 1 ) = 1;
    for y := 7 downto 0 do
    begin
      if ( Visibility and $3F ) <> 0 then
      begin
        cSurfaceSpec.y := y;
        for Surface := Low( tCubeSurface ) to High( tCubeSurface ) do
        begin
          if ( Visibility and 1 ) <> 0 then
          begin
            if ( ( Surface <> CS_TOP ) or ( cCamera.y > y + 1 ) ) and ( ( Surface <> CS_BOTTOM ) or ( cCamera.y < y ) ) then
            begin
              cSurfaceSpec.cSurface := Surface;
              drawSurface;
            end;
          end;
          Visibility := Visibility shr 1;
        end;
      end
      else
        Visibility := Visibility shr 6;
      bEvenBlock := not bEvenBlock;
    end;

    if ( Visibility and 1 ) <> 0 then
      renderFloorShadow;
  end;
end;

type
  tVisibilityCache = array [ 0 .. MAP_SIZE_MAX * MAP_SIZE_MAX - 1 ] of int64;

var
  x, y, z : integer;
  cBlock, cMask : tBlock;
  nShift, nOffset : cardinal;
  pVisibilityCache : ^tVisibilityCache;
  Visibility : int64;
  NeverCache : boolean;

begin
  pBlockData := cMap.BlockData;
  cSurfaceSpec.bWater := false;
  pVisibilityCache := VisibilityCache;
  for z := cNode[ 0 ].y to cNode[ 1 ].y - 1 do
  begin
    cSurfaceSpec.z := z;
    nOffset := z * cMap.Width + cNode[ 0 ].x;
    for x := cNode[ 0 ].x to cNode[ 1 ].x - 1 do
    begin
      cSurfaceSpec.x := x;
      cBlock := pBlockData^[ nOffset ];
      if cBlock <> 0 then
      begin
        if cRenderStatus.bCacheVisibility then
        begin
          Visibility := pVisibilityCache^[ nOffset ];
          if Visibility <> -1 then
          begin
            renderBlockFast( Visibility );
            inc( nOffset );
            continue;
          end;
        end;

        Visibility := 0;
        NeverCache := false;
        for y := 0 to 7 do
        begin
          nShift := y * 2;
          cMask := 3 shl nShift;
          BlockType := tBlockType( ( cBlock and cMask ) shr nShift );
          if ( y = 0 ) and ( BlockType < BLOCK_PILLAR ) then
            Visibility := renderFloorShadow;
          Visibility := Visibility shl 6;
          if BlockType <> BLOCK_EMPTY then
          begin
            cSurfaceSpec.y := y;
            Visibility := Visibility or renderBlock;
          end;
          NeverCache := NeverCache or ( BlockType = BLOCK_WATER ) or ( BlockType = BLOCK_PILLAR );
        end;

        if cRenderStatus.bCacheVisibility and not NeverCache then
          pVisibilityCache^[ nOffset ] := Visibility;
      end
      else
      begin
        if cRenderStatus.bCacheVisibility then
        begin
          Visibility := pVisibilityCache^[ nOffset ];
          if Visibility <> -1 then
          begin
            if Visibility = 1 then
              renderFloorShadow;
            inc( nOffset );
            continue;
          end;
        end;

        Visibility := renderFloorShadow;

        if cRenderStatus.bCacheVisibility then
          pVisibilityCache^[ nOffset ] := Visibility;
      end;
      inc( nOffset );
    end;
  end;
end;

procedure walkTree( const cRoot : tNode );
const
  CLIP_THRESHOLD = 2;
var
  cNode : tNode;
  ptDelta, ptMidpoint : tPoint;
  nNodeState : tClipStatus;
begin
  ptDelta := point( cRoot[ 1 ].x - cRoot[ 0 ].x, cRoot[ 1 ].y - cRoot[ 0 ].y );
  if ( ptDelta.x > CLIP_THRESHOLD ) or ( ptDelta.y > CLIP_THRESHOLD ) then
  begin
    nNodeState := getNodeState( cRoot );
    case nNodeState of
      CLIP_INTERSECT:
      begin
        ptMidPoint := cRoot[ 1 ];
        if ptDelta.x > 1 then ptMidPoint.x := cRoot[ 0 ].x + ptDelta.x div 2 else ptMidPoint.x := cRoot[ 1 ].x;
        if ptDelta.y > 1 then ptMidPoint.y := cRoot[ 0 ].y + ptDelta.y div 2 else ptMidPoint.y := cRoot[ 1 ].y;
        // Top Left
        cNode[ 0 ] := cRoot[ 0 ];
        cNode[ 1 ] := point( ptMidPoint.x, ptMidPoint.y );
        walkTree( cNode );
        if ptDelta.x > 1 then
        begin
          // Top Right
          cNode[ 0 ] := point( ptMidPoint.x, cRoot[ 0 ].y );
          cNode[ 1 ] := point( cRoot[ 1 ].x, ptMidPoint.y );
          walkTree( cNode );
        end;
        if ptDelta.y > 1 then
        begin
          // Bottom Left
          cNode[ 0 ] := point( cRoot[ 0 ].x, ptMidPoint.y );
          cNode[ 1 ] := point( ptMidPoint.x, cRoot[ 1 ].y );
          walkTree( cNode );
          if ptDelta.x > 1 then
          begin
            // Bottom Right
            cNode[ 0 ] := point( ptMidPoint.x, ptMidPoint.y );
            cNode[ 1 ] := cRoot[ 1 ];
            walkTree( cNode );
          end;
        end;
      end;
      CLIP_INSIDE:
        renderArea( cRoot );
    end;
  end
  else
    renderArea( cRoot );
end;

var
  cRoot : tNode;
begin
  cWaterList.Clear;
  glPushAttrib( GL_ENABLE_BIT );
  try
    glEnable( GL_DEPTH_TEST );
    glDisable( GL_CULL_FACE );
    glSet( GL_TEXTURE_2D, cRenderStatus.bTexturing );
    glSet( GL_FOG, cRenderStatus.nFog > 0 );
    glBindTexture( GL_TEXTURE_2D, glStoneTextureID );
    bPerformHiddenBlockTest := true;

    if ( VisibilityCache = nil ) = RenderStatus.bCacheVisibility then
      PrepareVisibilityCache;

    cTemporaryBoundingBox.Bottom := 0;
    cTemporaryBoundingBox.Top := MAP_SIZE_COLUMN;
    cRoot[ 0 ] := point( 0, 0 );
    cRoot[ 1 ] := point( cMap.Width, cMap.Height );
    walkTree( cRoot );
  finally
    glPopAttrib;
  end;
end;

var
  nTime : array [ 0 .. 1 ] of int64;

begin
  if cMap <> nil then
  begin
    queryPerformanceCounter( nTime[ 0 ] );
    cLightMapManager.resetComputationTime;
    prepareLightMap;
    setOptions;
    setProjection;
    setCamera;
    prepareClipping;
    setLight;
    clearBuffers;
    renderSunburst;
    renderFloor;
    renderScene;
    renderGame;
    renderWater;
    renderMessages;
    renderOverheadMap;
    renderStatusInformation;
    glhSwapBuffers( nOpenGLId );
    queryPerformanceCounter( nTime[ 1 ] );
    cRenderStatus.nTime := cardinal( nTime[ 1 ] - nTime[ 0 ] );
  end;
end;

procedure tRenderer.renderOverheadMap;

procedure Initialise;
begin
  glMatrixMode( GL_PROJECTION );
  glPushMatrix;
  glLoadIdentity;
  glOrtho( -1, 1, 1, -1, -1, 1 );

  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity;

  glPushAttrib( GL_ENABLE_BIT );
  glDisable( GL_DEPTH_TEST );
  glDisable( GL_CULL_FACE );
  glDisable( GL_TEXTURE_2D );
  glEnable( GL_BLEND );
  glDepthMask( GL_FALSE );
end;

procedure Finalise;
begin
  glPopAttrib;
  glDepthMask( GL_TRUE );

  glMatrixMode( GL_PROJECTION );
  glPopMatrix;
end;

procedure RenderSquare( x1, y1, x2, y2 : glFloat; const Colour : tColour );
begin
  glColor4ubv( @Colour );
  glVertex2f( x1, y1 );
  glVertex2f( x2, y1 );
  glVertex2f( x2, y2 );
  glVertex2f( x1, y2 );
end;

procedure RenderMap;
var
  x, z : integer;
  Idx : integer;
  Entity : tPhysicalEntity;
  xFactor, zFactor : glFloat;
  Scan : pBlock;
  Colour : tColour;
begin
  glBegin( GL_QUADS );
    xFactor := 2 / Map.Width;
    zFactor := 2 / Map.Height;
    Scan := Map.BlockData;
    for z := 0 to Map.Height - 1 do
      for x := 0 to Map.Width - 1 do
      begin
        if Scan^ <> 0 then
        begin
          Colour.rgba := EncodeBlockAsColour( Scan^ );
          Colour.a := MAP_ALPHA;

          RenderSquare( x * xFactor - 1, z * zFactor - 1, ( x + 1 ) * xFactor - 1, ( z + 1 ) * zFactor - 1, Colour );
        end;
        inc( Scan );
      end;

    if cGameInformation <> nil then
      for Idx := 0 to GameInformation.PhysicalEntityList.Count - 1 do
      begin
        Entity := tPhysicalEntity( GameInformation.PhysicalEntityList[ Idx ] );
        case Entity.EntityType.ID of
          TYPE_RESCUER:
            Colour.rgba := $40ff40;
          TYPE_RESCUEE:
            Colour.rgba := $ff80ff;
          TYPE_ANT:
            Colour.rgba := $00ffff;
          TYPE_GRENADE:
            Colour.rgba := $ffffff;
          TYPE_EXPLOSION:
            Colour.rgba := $000000;
        end;
        Colour.a := MAP_ALPHA;
        with Entity.Location, Entity.BoundingBox do
          RenderSquare( ( x - 0.4 ) * xFactor - 1, ( z - 0.4 ) * zFactor - 1, ( x + 0.4 ) * xFactor - 1, ( z + 0.4 ) * zFactor - 1, Colour );
      end;

  glEnd;
end;

begin
  if RenderStatus.bOverheadMap then
  begin
    Initialise;
    try
      renderMap;
    finally
      Finalise;
    end;
  end;
end;

procedure tRenderer.selectTexture( Texture : tTexture );
var
  TextureID : integer;
  Format : integer;
begin
  if Texture.InternalID = 0 then
  begin
    glGenTextures( 1, @TextureID );
    Texture.InternalID := TextureID;
    glBindTexture( GL_TEXTURE_2D, Texture.InternalID );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    if Texture.BitsPerPixel = 24 then
      Format := GL_RGB
    else
      Format := GL_RGBA;
    glTexImage2d( GL_TEXTURE_2D, 0, Texture.BitsPerPixel div 8, Texture.Width, Texture.Height, 0, Format, GL_UNSIGNED_BYTE, Texture.Data );
    Texture.ReleaseData;      // We don't need this anymore
  end
  else
    glBindTexture( GL_TEXTURE_2D, Texture.InternalID );
end;

procedure tRenderer.setMap( aMap : tMap );
begin
  cMap := aMap;
  cLightMapManager.initialise( cMap );
  fMapLevel := 0;
  SetMapLevel( 1 );
  if not bCameraAssigned then
  begin
    cCamera.setLocation( cMap.Width div 2, 10.0, cMap.Height div 2 );
    bCameraAssigned := true;
  end;
end;

procedure tRenderer.setMapLevel( MapLevel : integer );
begin
  if fMapLevel <> MapLevel then
  begin
    fMapLevel := MapLevel;
    cLightMapManager.prepareLevelLightMap( fMapLevel, false );
    ClearVisibilityCache;
  end;
end;

procedure tRenderer.unitialiseOpenGL;

procedure freeTexture( nTextureID : glInt );
begin
  if nTextureID <> 0 then
    glDeleteTextures( 1, @nTextureID );
end;

begin
  freeTexture( glStoneTextureID );
  freeTexture( glFloorTextureID );
  freeTexture( glShadowTextureID );
  freeTexture( glWaterShadowTextureID );
  glFontDestroy( glFontData );
  glhUninitialise( nOpenGLId );
end;

end.
