unit Game;

interface

uses
  ApplicationStateData, Classes, Controls, Forms, ExtCtrls, Messages, Messaging, Map, Renderer, RenderedForm, SharedStateData, Windows, StdCtrls;

type
  tfrmGame = class( tRenderedForm )
    pnlRender: TPanel;
    pbxRender: TPaintBox;
    tmrRender: TTimer;
    procedure   FormActivate( Sender : tObject );
    procedure   FormClose( Sender : tObject; var Action : tCloseAction );
    procedure   FormDeactivate( Sender : tObject );
    procedure   FormShortCut( var Msg : tWMKey; var Handled : boolean );
    procedure   FormKeyUp( Sender : tObject; var Key : word; Shift : tShiftState );
    procedure   FormMouseDown( Sender : tObject; Button : tMouseButton; Shift : tShiftState; x, y : integer );
    procedure   FormMouseUp( Sender : tObject; Button : tMouseButton; Shift : tShiftState; x, y : integer );
    procedure   pbxRenderPaint( Sender : tObject );
    procedure   tmrRenderTimer( Sender : tObject );
  private
    fApplicationStateData : tApplicationStateData;
    fCommandLine : tStringList;
    fDisplayModeChanged : boolean;
    fFullScreen : boolean;
    fState : tApplicationState;
    fStateHandler : array [ tApplicationState ] of tApplicationStateHandler;
    fKeysCurrentlyLatched : tKeyCommands;
    procedure   HandleMouseClick( Button : tMouseButton; Depressed : boolean );
    procedure   InitialiseDisplay;
    procedure   LatchKeys;
    procedure   ReadCommandLine;
    procedure   Render;
    procedure   SetState( aState : tApplicationState );
    procedure   UpdateActiveKeys( KeyCode : word; Pressed : boolean );
  protected
    procedure   WMSysCommand( var Message : tWMSysCommand ); message WM_SYSCOMMAND;
    property    State : tApplicationState read fState write SetState;
  public
    constructor Create( aOwner : tComponent ); overload; override;
    constructor Create( aOwner : tComponent; aMap : tMap; aLog : tStrings ); reintroduce; overload;
    destructor  Destroy; override;
    procedure   AfterConstruction; override;
    property    ApplicationStateData : tApplicationStateData read fApplicationStateData;
  end;

var
  frmGame : tfrmGame;

implementation

{$R *.dfm}

uses
  AttractHandler, AvailableMapList, Common, Colour, Geometry, Math, SysUtils, GameSound, Resource, PlayerInput, Introduction, ChooseMap, GamePlayHandler;

type
  tCreatingHandler = class( tApplicationStateHandler )
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    procedure   Process; override;
  end;

  tClosingHandler = class( tApplicationStateHandler )
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    procedure   Process; override;
  end;

// This function needs to be re-declared because Deplhi declares it with a var parameter, whereas it is important to pass nil to reset the display settings.
function ChangeDisplaySettingsPtr( lpDevMode : pDeviceMode; dwFlags : DWORD ) : longint; stdcall; external user32 name 'ChangeDisplaySettingsA';

(* tCreatingHandler *)

constructor tCreatingHandler.Create( aApplicationStateData : tApplicationStateData );
begin;
  inherited Create( aApplicationStateData, STATE_CREATING, [] );
end;

procedure tCreatingHandler.Process;
begin
  ApplicationStateData.State := STATE_INTRODUCTION;
end;

(* tClosingHandler *)

constructor tClosingHandler.Create( aApplicationStateData : tApplicationStateData );
begin;
  inherited Create( aApplicationStateData, STATE_CLOSING, [] );
end;

procedure tClosingHandler.Process;
begin
  ApplicationStateData.RenderRequired := false;
  ApplicationStateData.Form.Close;
end;

(* tfrmGame *)

constructor tfrmGame.Create( aOwner : tComponent );
begin
  inherited;
  fApplicationStateData := tApplicationStateData.Create( Self );
  fCommandLine := tStringList.Create;
  ReadCommandLine;

  fState := STATE_CREATING;
  fStateHandler[ STATE_CREATING ] := tCreatingHandler.Create( fApplicationStateData );
  fStateHandler[ STATE_INTRODUCTION ] := tIntroductionHandler.Create( fApplicationStateData );
  fStateHandler[ STATE_CHOOSE_MAP ] := tChooseMapHandler.Create( fApplicationStateData );
  fStateHandler[ STATE_ATTRACT ] := tAttractHandler.Create( fApplicationStateData );
  fStateHandler[ STATE_PLAY ] := tGamePlayHandler.Create( fApplicationStateData );
  fStateHandler[ STATE_CLOSING ] := tClosingHandler.Create( fApplicationStateData );

  Renderer.RenderStatus.cControl := pnlRender;
end;

constructor tfrmGame.Create( aOwner : tComponent; aMap : tMap; aLog : tStrings );
const
  MSG_NOTIFICATION = -1;

procedure CreateMessage( const Description : string; Position : _float );
begin
  fApplicationStateData.MessageList.AddMessage( tMessage.Create( MSG_NOTIFICATION, Description, 9, 5000 ) ).SetPosition( 0, Position ).SetFadeTime( 500 ).SetColour( COLOUR_WHITE );
end;

begin
  Create( aOwner );
  with fApplicationStateData do
  begin
    InEditor := true;
    LogSource := aLog;
  end;
  aLog.Clear;
  FormStyle := fsMDIChild;
  Map := aMap;
  State := STATE_PLAY;

  with fApplicationStateData.MessageList do
  begin
    CreateMessage( 'Press L to skip levels', 0.6 );
    CreateMessage( 'Press I for invulnerability', 0.75 );
    CreateMessage( 'Press M to show map', 0.9 );
  end;
end;

destructor tfrmGame.Destroy;
var
  SIdx : tApplicationState;
begin
  inherited;  // Called first so that Deactivate is trigged before rest of destructor
  for SIdx := Low( tApplicationState) to High( tApplicationState ) do
    fStateHandler[ SIdx ].Free;
  fCommandLine.Free;
  fApplicationStateData.Free;
  if fDisplayModeChanged then
  begin
    Screen.Cursor := crDefault;
    ChangeDisplaySettingsPtr( nil, 0 );
  end;
  frmGame := nil;
end;

procedure tfrmGame.FormActivate( Sender : tObject );
begin
  tmrRender.Interval := 20;
  fStateHandler[ State ].Activate;
end;

procedure tfrmGame.FormClose( Sender : tObject; var Action : tCloseAction );
begin
  tmrRender.Enabled := false;
  Action := caFree;
end;

procedure tfrmGame.FormDeactivate( Sender : tObject );
begin
  tmrRender.Interval := 200;
  fStateHandler[ State ].Deactivate;;
end;

procedure tfrmGame.FormShortCut( var Msg : tWMKey; var Handled : boolean );
begin
  UpdateActiveKeys( Msg.CharCode, true );
end;

procedure tfrmGame.FormKeyUp( Sender : tObject; var Key : word; Shift : tShiftState );
begin
  // Pause seems to have its own weird behaviour. A KeyUp is triggered almost immediately after KeyDown.
  if Key <> VK_PAUSE then
    UpdateActiveKeys( Key, false );
end;

procedure tfrmGame.FormMouseDown( Sender : tObject; Button : tMouseButton; Shift : tShiftState; x, y : integer );
begin
  HandleMouseClick( Button, true );
end;

procedure tfrmGame.FormMouseUp( Sender : tObject; Button : tMouseButton; Shift : tShiftState; x, y : integer );
begin
  HandleMouseClick( Button, false );
end;

procedure tfrmGame.pbxRenderPaint( Sender : tObject );
begin
  Render;
end;

procedure tfrmGame.tmrRenderTimer( Sender : tObject );
begin
  fApplicationStateData.RenderRequired := true;
  fApplicationStateData.State := fState;

  fStateHandler[ State ].Process;
  fApplicationStateData.AudioManager.DigitalAudio.UpdateSourceLocations;
  if fApplicationStateData.RenderRequired then
    Render;
  State := fApplicationStateData.State;
  LatchKeys;
end;

procedure tfrmGame.AfterConstruction;
var
  MapList : tAvailableMapList;
begin
  if fState = STATE_CREATING then
  begin
    MapList := ApplicationStateData.MapList;
    MapList.Refresh;
    if MapList.Count = 0 then
    begin
      Application.MessageBox( pChar( 'Could not find any map files in: ' + MapList.Path ), nil, MB_OK or MB_ICONSTOP );
      Halt;
    end;
    InitialiseDisplay;
    Map := MapList.Map[ 0 ];
  end;
  inherited;
  tmrRender.Enabled := true;
  SetState( fState );
end;

procedure tfrmGame.HandleMouseClick( Button : tMouseButton; Depressed : boolean );
var
  KeyCode : word;
begin
  case Button of
    mbLeft:
      KeyCode := VK_CONTROL;
    mbRight:
      KeyCode := VK_SPACE;
    mbMiddle:
      KeyCode := VK_TAB;
    else
      KeyCode := 0;
  end;
  if KeyCode <> 0 then
    UpdateActiveKeys( KeyCode, Depressed );
end;

procedure tfrmGame.InitialiseDisplay;

function ReadInt( const Key : string; Default : integer ) : integer;
var
  Value : string;
begin
  Value := fCommandLine.Values[ Key ];
  if Value <> '' then
    result := StrToIntDef( Value, Default )
  else
    result := Default;
end;

function MakeResolution( const Resolution : tPoint; NewWidth : integer ) : tPoint;
begin
  result.y := NewWidth * Resolution.y div Resolution.x;
  result.x := NewWidth;
end;

var
  FullScreen : integer;
  CmdWidth : integer;
  Resolution : tPoint;
  DevMode : tDevMode;
  Configuration : tRendererConfiguration;
begin
  if not ApplicationStateData.InEditor then
  begin
    Configuration := Renderer.Configuration;
    FullScreen := ReadInt( 'fullscreen', Ord( Configuration.FullScreen ) );
    Resolution := Point( Screen.Width, Screen.Height );
    if FullScreen = 0 then
      Resolution := Point( Resolution.x div 2, Resolution.y div 2 );

    if Configuration.Width > 0 then
      Resolution := MakeResolution( Resolution, Configuration.Width );
    if Configuration.Height > 0 then
      Resolution.y := Configuration.Height;

    CmdWidth := ReadInt( 'width', 0 );
    if CmdWidth > 0 then
      Resolution := MakeResolution( Resolution, CmdWidth );
    Resolution.y := ReadInt( 'height', Resolution.y );

    fDisplayModeChanged := false;
    fFullScreen := FullScreen <> 0;
    if fFullScreen then
    begin
      Left := 0;
      Top := 0;
      FillChar( DevMode, SizeOf( DevMode ), 0 );
      DevMode.dmSize := SizeOf( DevMode );
      DevMode.dmBitsPerPel := 32;
      DevMode.dmPelsWidth := Resolution.x;
      DevMode.dmPelsHeight := Resolution.y;
      DevMode.dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT;
      fDisplayModeChanged := ChangeDisplaySettingsPtr( @DevMode, CDS_FULLSCREEN ) = DISP_CHANGE_SUCCESSFUL;
      if fDisplayModeChanged then
      begin
        BorderStyle := bsNone;
        ClientWidth := Resolution.x;
        ClientHeight := Resolution.y;
        Screen.Cursor := crNone;
      end;
    end;

    if not fDisplayModeChanged then
    begin
      if Screen.Width < Resolution.x then
        Resolution.x := Screen.Width;
      if Screen.Height < Resolution.y then
        Resolution.y := Screen.Height;
      ClientWidth := Resolution.x;
      ClientHeight := Resolution.y;
      Left := ( Screen.Width div 2 ) - ( Width div 2 );
      Top := ( Screen.Height div 2 ) - ( Height div 2 );
    end;
  end;
end;

procedure tfrmGame.LatchKeys;
var
  Key : tKeyCommand;
begin
  fApplicationStateData.ExcludeKey( KEY_PAUSE );
  for Key := Low( tKeyCommand ) to High( tKeyCommand ) do
    if ( Key in fApplicationStateData.KeysPressed ) and ( Key in fStateHandler[ State ].KeysLatched ) then
    begin
      include( fKeysCurrentlyLatched, Key );
      fApplicationStateData.ExcludeKey( Key );
    end;
end;

procedure tfrmGame.ReadCommandLine;
var
  Idx : integer;
begin
  for Idx := 1 to ParamCount do
    fCommandLine.Add( ParamStr( Idx ) );
end;

procedure tfrmGame.Render;
begin
  if State <> STATE_CREATING then
    Renderer.Render;
end;

procedure tfrmGame.SetState( aState : tApplicationState );
begin
  if aState <> fState then
  begin
    if fState <> STATE_NULL then
    begin
      fStateHandler[ fState ].Finalise;
      fApplicationStateData.MessageList.Clear;
    end;
    fState := aState;
    Renderer.RenderStatus.Reset;
    if not fApplicationStateData.InEditor or ( fState = STATE_PLAY ) then
      fStateHandler[ fState ].Initialise
    else
      Close;
  end;
end;

procedure tfrmGame.UpdateActiveKeys( KeyCode : word; Pressed : boolean );
var
  Key : tKeyCommand;
begin
  case KeyCode of
    VK_LEFT, Ord( 'A' ):
      Key := KEY_LEFT;
    VK_RIGHT, Ord( 'D' ):
      Key := KEY_RIGHT;
    VK_UP, Ord( 'W' ):
      Key := KEY_UP;
    VK_DOWN, Ord( 'S' ):
      Key := KEY_DOWN;
    VK_CONTROL:
      Key := KEY_FIRE;
    VK_SPACE:
      Key := KEY_JUMP;
    VK_SHIFT:
      Key := KEY_WALK;
    VK_RETURN:
      Key := KEY_SELECT;
    VK_TAB:
      Key := KEY_PERSPECTIVE;
    VK_PAUSE:
      Key := KEY_PAUSE;
    VK_ESCAPE:
      Key := KEY_ESCAPE;
    VK_F1:
      Key := KEY_HELP;
    Ord( 'M' ):
      Key := KEY_MAP;
    Ord( 'B' ):
      Key := KEY_BOY;
    Ord( 'G' ):
      Key := KEY_GIRL;
    Ord( 'Q' ):
      Key := KEY_ELTON;
    Ord( 'L' ):
      Key := KEY_SKIP_LEVEL;
    Ord( 'I' ):
      Key := KEY_INVULNERABLE;
  else
    Key := KEY_NULL;
  end;

  if Key <> KEY_NULL then
    with fApplicationStateData do
      if Pressed then
      begin
        if not ( Key in fKeysCurrentlyLatched ) then
          fApplicationStateData.IncludeKey( Key );
      end
      else
      begin
        fApplicationStateData.ExcludeKey( Key );
        exclude( fKeysCurrentlyLatched, Key );
      end;
end;

// Disable screen saver requests when running in full-screen mode
procedure tfrmGame.WMSysCommand( var Message : tWMSysCommand );
begin
  if ( Message.CmdType <> SC_SCREENSAVE ) or not fFullScreen then
    inherited;
end;

end.
