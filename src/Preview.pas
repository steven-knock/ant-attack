unit Preview;

interface

Uses
  Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  Renderer, Windows, RenderedForm, Map, Common, Scene;

type
  tMovementMode = ( MM_CAMERA, MM_LIGHT );

  tfrmPreview = Class(tRenderedForm)
    pnlRender: TPanel;
    tmrRender: TTimer;
    pbxRender: TPaintBox;
    pnlText: TPanel;
    lblLights: TLabel;
    lblTextures: TLabel;
    lblFog: TLabel;
    lblLightsSh: TLabel;
    lblTexturesSh: TLabel;
    lblFogSh: TLabel;
    lblFOV: TLabel;
    lblFOVSh: TLabel;
    lblFar: TLabel;
    lblFarSh: TLabel;
    lblStatus: TLabel;
    lblStatusSh: TLabel;
    lblMipMappingSh: TLabel;
    lblMipMapping: TLabel;
    lblInfoSh: TLabel;
    lblInfo: TLabel;
    lblShadowSh: TLabel;
    lblShadow: TLabel;
    lblSunSh: TLabel;
    lblSun: TLabel;
    dlgOpenScene: TOpenDialog;
    procedure FormActivate( Sender : tObject );
    procedure FormClose( Sender : tObject; var Action : tCloseAction );
    procedure FormCloseQuery( Sender : tObject; var CanClose : boolean );
    procedure FormDeactivate( Sender : tObject );
    procedure FormKeyDown( Sender : tObject; var Key : Word; Shift : tShiftState );
    procedure FormMouseMove( Sender : tObject; Shift : tShiftState; X, Y : integer );
    procedure FormMouseUp( Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : integer );
    procedure FormResize(Sender: TObject);
    procedure pbxRenderMouseDown( Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : integer );
    procedure pbxRenderPaint( Sender : tObject );
    procedure tmrRenderTimer( Sender : tObject );
  private
    Scene : tScene;
    ShowDimensions : cardinal;
    DefaultFogThreshold : cardinal;
    PerformanceFrequency : int64;
    ptAngle : tFloatPoint2d;
    ptMousePos : tPoint;
    nMovementMode : tMovementMode;
    ptLight : tSphericalCoordinate;
    sFarDistance, sFOV, sStatus, sSun, sShadow : string;
    procedure render;
    procedure updateText;
  public
    constructor create( aOwner : tComponent; aMap : tMap ); reintroduce;
    destructor destroy; override;
    procedure  updateCaption; override;
  end;

var
  frmPreview : tfrmPreview;

implementation

uses
  Geometry;

{$R *.DFM}

(* tFrmPreview *)

(* Constructor *)

constructor tfrmPreview.create( aOwner : tComponent; aMap : tMap );

procedure PrepareForMeasurement;
begin
  with Renderer.Camera do
  begin
    setLocation( 0, MAP_SIZE_COLUMN, 0 );

    ptAngle.x := 225;
    ptAngle.y := -22.5;

    Orientation.rotateX( -ptAngle.y * PI / 180 );
    Orientation.rotateY( -ptAngle.x * PI / 180 );
  end;
end;

begin
  inherited create( aOwner );
  Scene := tScene.Create;
  QueryPerformanceFrequency( PerformanceFrequency );
  Renderer.RenderStatus.cControl := pnlRender;
  Renderer.RenderStatus.nLightMap := LM_LOW;
  Renderer.RenderStatus.nFarDistance := 80;
  Renderer.RenderStatus.bCacheVisibility := false;
  Renderer.GameInformation := Scene.Information;
  DefaultFogThreshold := Renderer.RenderStatus.nFog;
  Renderer.LightMapManager.AutoGenerate := true;
  Map := aMap;
  sFarDistance := lblFar.Caption;
  sFOV := lblFOV.Caption;
  sStatus := lblStatus.Caption;
  sSun := lblSun.Caption;
  sShadow := lblShadow.Caption;
  Left := 0;
  Top := 0;
  ptLight.Latitude := 32 * PI / 180;
  ptLight.Longitude := ptLight.Latitude;
  PrepareForMeasurement;
end;

(* Events *)

procedure tfrmPreview.FormActivate(Sender: TObject);
begin
  tmrRender.Interval := 50;
end;

procedure tfrmPreview.FormClose( Sender : tObject; var Action : tCloseAction );
begin
  Action := caFree;
end;

procedure tfrmPreview.FormCloseQuery( Sender : tObject; var CanClose : boolean );
begin
  CanClose := true;
end;

procedure tfrmPreview.FormDeactivate( Sender : tObject );
begin
  tmrRender.Interval := 500;
end;

procedure tfrmPreview.FormKeyDown( Sender : tObject; var Key : Word; Shift : tShiftState );
const
  KeyMapping : array [ 1 .. 4, 1 .. 2 ] of Word = ( ( Ord( 'A' ), VK_LEFT ), ( Ord( 'D' ), VK_RIGHT ), ( Ord( 'W' ), VK_UP ), ( Ord( 'S' ), VK_DOWN ) );
  Speed : array [ boolean ] of _float = ( 1.0, 0.2 );
var
  ptMovement : tPoint3d;
  cCamera : tViewpoint;
  nScale : _float;
  Idx : integer;
  VirtualKey : Word;
begin
  VirtualKey := Key;
  for Idx := Low( KeyMapping ) to High( KeyMapping ) do
    if VirtualKey = KeyMapping[ Idx, 1 ] then
      VirtualKey := KeyMapping[ Idx, 2 ];
  if ( VirtualKey = VK_UP ) or ( VirtualKey = VK_DOWN ) or ( VirtualKey = VK_LEFT ) or ( VirtualKey = VK_RIGHT ) then
  begin
    if ( VirtualKey = VK_UP ) or ( VirtualKey = VK_DOWN ) then
      ptMovement := tPoint3d.create( 0, 0, 1 )
    else
      ptMovement := tPoint3d.create( 1, 0, 0 );
    try
      ptMovement.rotateX( -ptAngle.y * PI / 180 );
      ptMovement.rotateY( -ptAngle.x * PI / 180 );
      if ( VirtualKey = VK_DOWN ) or ( VirtualKey = VK_LEFT ) then
        ptMovement.negate;
      ptMovement.z := -ptMovement.z;
      ptMovement.scale( Speed[ ssShift in Shift ] );
      cCamera := Renderer.Camera;
      cCamera.translate( ptMovement );
      nScale := Renderer.RenderStatus.nScale * 2;
      if cCamera.y <= nScale then cCamera.y := nScale;
      if cCamera.y >= 96 then cCamera.y := 96;
    finally
      ptMovement.free;
    end;
  end
  else
    with Renderer.RenderStatus do
      case VirtualKey of
        VK_F1:
          bLighting := not bLighting;
        VK_F2:
          bTexturing := not bTexturing;
        VK_F3:
          if nFog > 0 then
            nFog := 0
          else
            nFog := DefaultFogThreshold;
        VK_F4:
          bMipMap := not bMipMap;
        VK_F5:
        begin
          if nLightMap = High( tLightMapMode ) then
            nLightMap := Low( tLightMapMode )
          else
            nLightMap := Succ( nLightMap );
          if nLightMap <> LM_NONE then
            Renderer.LightMapManager.initialise( Map );
        end;
        VK_F10:
          if ( [ ssShift, ssCtrl ] = Shift ) and dlgOpenScene.Execute then
          begin
            Scene.Load( dlgOpenScene.FileName );
            ptLight := Scene.Sun;
          end;
        VK_HOME:
          if nFarDistance > 5 then nFarDistance := nFarDistance - 1;
        VK_END:
          if nFarDistance < 256 then nFarDistance := nFarDistance + 1;
        VK_PRIOR:
          if nFOV > 20 then nFOV := nFOV - 1;
        VK_NEXT:
          if nFOV < 120 then nFOV := nFOV + 1;
      end;
end;

procedure tfrmPreview.FormMouseMove( Sender : tObject; Shift : tShiftState; X, Y : integer );
var
  ptDelta : tPoint;
  cCamera : tViewpoint;
begin
  if getCapture = Handle then
  begin
    ptDelta.x := ptMousePos.x - x;
    ptDelta.y := ptMousePos.y - y;

    if nMovementMode = MM_CAMERA then
    begin
      ptAngle.x := ptAngle.x + ptDelta.x;
      ptAngle.y := ptAngle.y + ptDelta.y;
      cCamera := Renderer.Camera;
      cCamera.Orientation.reset;
      cCamera.Orientation.rotateX( -ptAngle.y * PI / 180 );
      cCamera.Orientation.rotateY( -ptAngle.x * PI / 180 );
    end
    else
    begin
      ptLight.Longitude := ptLight.Longitude - ptDelta.x * PI / 180;
      ptLight.Latitude := ptLight.Latitude - ptDelta.y * PI / 180;
    end;
    ptMousePos := point( x, y );
  end;
end;

procedure tfrmPreview.FormMouseUp( Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : integer );
begin
  releaseCapture;
end;

procedure tfrmPreview.FormResize(Sender: TObject);
begin
  if frmPreview <> nil then   // This method can be triggered when closing a maximised window. This check ensures that we don't have a "NullPointerException".
  begin
    ShowDimensions := GetTickCount + 2000;
    updateCaption;
  end;
end;

procedure tfrmPreview.pbxRenderMouseDown( Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : integer );
begin
  if ( ssLeft in Shift ) or ( ssRight in Shift ) then
  begin
    setCapture( handle );
    ptMousePos := screenToClient( pbxRender.clientToScreen( point( x, y ) ) );
    if ssLeft in Shift then nMovementMode := MM_CAMERA else nMovementMode := MM_LIGHT;
  end;
end;

procedure tfrmPreview.pbxRenderPaint( Sender : tObject );
begin
  render;
end;

procedure tfrmPreview.tmrRenderTimer( Sender : tObject );
begin
  render;
  updateCaption;
end;

(* Private Methods *)

procedure tfrmPreview.render;
begin
  Renderer.LightMapManager.setLightSphericalPosition( ptLight );
  Renderer.render;
  updateText;
end;

procedure tfrmPreview.updateCaption;
begin
  inherited;
  if ShowDimensions > GetTickCount then
    Caption := Caption + Format( ' [%d, %d]', [ pbxRender.Width, pbxRender.Height ] );
end;

procedure tfrmPreview.updateText;
const
  LightMapMode : array [ tLightMapMode ] of string = ( 'Off', 'Low', 'High' );

procedure setText( Ctrl, CtrlSh : tLabel; const sMsg : string );
begin
  Ctrl.Caption := sMsg;
  CtrlSh.Caption := sMsg;
end;

begin
  with Renderer.RenderStatus do
  begin
    setText( lblFar, lblFarSh, format( sFarDistance, [ floatToStr( nFarDistance ) ] ) );
    setText( lblFOV, lblFOVSh, format( sFOV, [ floatToStr( nFOV ) ] ) );
    setText( lblStatus, lblStatusSh, format( sStatus, [ intToStr( nPolyCount ), FloatToStrF( PerformanceFrequency / nTime, ffFixed, 10, 2 ) ] ) );
    setText( lblSun, lblSunSh, format( sSun, [ singleToStr( WrapFloat( ptLight.Latitude * 180 / PI, -180, 360 ) ), singleToStr( WrapFloat( ptLight.Longitude * 180 / PI, -180, 360 ) ) ] ) );
    setText( lblShadow, lblShadowSh, format( sShadow, [ LightMapMode[ nLightMap ] ] ) );
  end;
end;

(* Destructor *)

destructor tfrmPreview.destroy;
begin
  frmPreview := nil;
  Scene.Free;
  inherited;
end;

end.
