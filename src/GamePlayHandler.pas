unit GamePlayHandler;

interface

uses
  Controls, Forms, Windows, ApplicationStateData, GameEngine, Geometry, HelpHandler;

type
  tGamePlayHandler = class( tApplicationStateHandler )
  private
    ptMouseRestore : tPoint;
    ptCentre : tPoint;
    bPaused : boolean;
    fGameEngine : tGameEngine;
    OriginalCursor : tCursor;
    RememberedCursor : boolean;
    HelpHandler : tHelpMessageHandler;
    Frequency, BaseTime, GameTime : int64;
    SoundReceiver : tViewpoint;
    procedure   AdvanceLevel;
    function    GetGameEngine : tGameEngine;
    function    IsPaused : boolean;
    procedure   ProcessInput;
    procedure   ProcessMouseMovement;
    procedure   ProcessPauseRequest;
    procedure   SetCentre;
    procedure   UpdateCamera;
  protected
    property    GameEngine : tGameEngine read GetGameEngine;
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    destructor  Destroy; override;
    procedure   Deactivate; override;
    procedure   Finalise; override;
    procedure   Initialise; override;
    procedure   Process; override;
  end;

implementation

uses
  Math, SysUtils, Common, PlayerInput, Messaging, SharedStateData, Renderer;

constructor tGamePlayHandler.Create( aApplicationStateData : tApplicationStateData );
begin
  inherited Create( aApplicationStateData, STATE_PLAY, [ KEY_PAUSE, KEY_ESCAPE, KEY_HELP, KEY_SELECT, KEY_PERSPECTIVE, KEY_MAP, KEY_SKIP_LEVEL, KEY_INVULNERABLE ] );
  SoundReceiver := tViewpoint.Create;
  HelpHandler := tHelpMessageHandler.Create;
  QueryPerformanceFrequency( Frequency );
end;

destructor tGamePlayHandler.Destroy;
begin
  fGameEngine.Free;
  HelpHandler.Free;
  SoundReceiver.Free;
  inherited;
end;

procedure tGamePlayHandler.Deactivate;
begin
  if not IsPaused then
    ProcessPauseRequest;
end;

procedure tGamePlayHandler.Finalise;
begin
  Deactivate;
  ApplicationStateData.Renderer.GameInformation := nil;
  FreeAndNil( fGameEngine );
end;

procedure tGamePlayHandler.Initialise;
begin
  FreeAndNil( fGameEngine );
  ApplicationStateData.ClearMessages;
  ApplicationStateData.AudioManager.StopMusic;
  fGameEngine := tGameEngine.Create( ApplicationStateData );
  GameEngine.Start;

  ApplicationStateData.Renderer.GameInformation := GameEngine.GameState.Information;
  ApplicationStateData.Renderer.RenderStatus.bCacheVisibility := not ApplicationStateData.InEditor;

  if not RememberedCursor then
  begin
    OriginalCursor := Screen.Cursor;
    RememberedCursor := true;
  end;

  HelpHandler.HelpActive := false;

  bPaused := true;
  ProcessPauseRequest;
end;

procedure tGamePlayHandler.Process;
var
  RealTime, Interval : int64;
  Iterations : integer;
  Complete : boolean;
begin
  ApplicationStateData.RenderRequired := false;
  if GameEngine.IsRunning then
  begin
    if not IsPaused then
    begin
      Interval := Trunc( GameEngine.Interval * Frequency );
      Iterations := 0;
      Complete := false;
      repeat
        QueryPerformanceCounter( RealTime );
        dec( RealTime, BaseTime );
        if ( GameTime < RealTime ) and ( Iterations < 20 ) then
        begin
          ProcessInput;
          GameEngine.Process;
          inc( GameTime, Interval );
          inc( Iterations );
        end
        else
          Complete := true;
      until Complete;
      if Iterations > 0 then
      begin
        UpdateCamera;
        ApplicationStateData.RenderRequired := true;
      end;

      if KEY_PERSPECTIVE in ApplicationStateData.KeysPressed then
        GameEngine.GameState.FirstPerson := not GameEngine.GameState.FirstPerson;
      if KEY_HELP in ApplicationStateData.KeysPressed then
        HelpHandler.ProcessHelpRequest( ApplicationStateData.MessageList );
    end;

    if KEY_PAUSE in ApplicationStateData.KeysPressed then
      ProcessPauseRequest
    else if KEY_ESCAPE in ApplicationStateData.KeysPressed then
      ApplicationStateData.State := STATE_ATTRACT
    else if KEY_SKIP_LEVEL in ApplicationStateData.KeysPressed then
      AdvanceLevel
    else if ApplicationStateData.InEditor then
    begin
      if KEY_INVULNERABLE in ApplicationStateData.KeysPressed then
        with ApplicationStateData do
          Invulnerable := not Invulnerable
      else if ( KEY_MAP in ApplicationStateData.KeysPressed ) and not IsPaused then
        with ApplicationStateData.Renderer.RenderStatus do
          bOverheadMap := not bOverheadMap;
    end;
  end
  else
    ApplicationStateData.State := STATE_ATTRACT
end;

procedure tGamePlayHandler.ProcessInput;
var
  PlayerInput : tPlayerInput;
  MovementForce : _float;
  Trajectory : _float;
  KeysPressed : tKeyCommands;
begin
  ProcessMouseMovement;

  KeysPressed := ApplicationStateData.KeysPressed;
  if not GameEngine.IsInCinematic then
  begin
    MovementForce := IfThen( KEY_WALK in KeysPressed, 0.45, 1.0 );
    PlayerInput := GameEngine.PlayerInput;
    if ( KEY_LEFT in KeysPressed ) and not ( KEY_RIGHT in KeysPressed ) then
      PlayerInput.MovePlayer( PI * 0.5, MovementForce )
    else if ( KEY_RIGHT in KeysPressed ) and not ( KEY_LEFT in KeysPressed ) then
      PlayerInput.MovePlayer( PI * -0.5, MovementForce );

    if ( KEY_UP in KeysPressed ) and not ( KEY_DOWN in KeysPressed ) then
      PlayerInput.MovePlayer( 0, MovementForce )
    else if ( KEY_DOWN in KeysPressed ) and not ( KEY_UP in KeysPressed ) then
      PlayerInput.MovePlayer( PI, MovementForce );

    if KEY_FIRE in KeysPressed then
    begin
      Trajectory := GameEngine.Camera.Latitude;
      if GameEngine.GameState.FirstPerson then
        Trajectory := Trajectory + PI / 16
      else
        Trajectory := -PI / 10;
      PlayerInput.WindUpGrenade( Trajectory );
    end;

    if KEY_JUMP in KeysPressed then
      PlayerInput.Jump( 1 );
  end
  else
  begin
    if KEY_SELECT in KeysPressed then
      GameEngine.SkipCinematic;
  end;
end;

procedure tGamePlayHandler.ProcessMouseMovement;
var
  ptMouseMovement : Windows.tPoint;
  XRadians, YRadians : _float;
begin
  ptMouseMovement := Mouse.CursorPos;
  dec( ptMouseMovement.X, ptCentre.X );
  dec( ptMouseMovement.Y, ptCentre.Y );
  if ApplicationStateData.Renderer.Configuration.InvertMouse then
    ptMouseMovement.Y := -ptMouseMovement.Y;
  SetCentre;
  if not GameEngine.IsInCinematic then
  begin
    XRadians := ptMouseMovement.X * PI / 360;
    YRadians := ptMouseMovement.Y * PI / 360;
    GameEngine.PlayerInput.RotatePlayer( -XRadians );
    GameEngine.Camera.Latitude := GameEngine.Camera.Latitude + YRadians;
  end;
end;

procedure tGamePlayHandler.ProcessPauseRequest;
begin
  if IsPaused then
  begin
    QueryPerformanceCounter( BaseTime );
    GameTime := 0;
    ptMouseRestore := Mouse.CursorPos;
    SetCaptureControl( ApplicationStateData.Form );   // This doesn't seem to work, which is why I keep the mouse at the centre of the form
    Screen.Cursor := crNone;
    SetCentre;
    GameEngine.GameState.SharedStateData.AudioManager.DigitalAudio.Resume;
    bPaused := false;
  end
  else
  begin
    if GameEngine.GameState <> nil then   // v1.0.3 - A failure during initialisation can cause a reference to a null GameEngine.GameState member during Finalisation
      GameEngine.GameState.SharedStateData.AudioManager.DigitalAudio.Pause;
    Mouse.CursorPos := ptMouseRestore;
    SetCaptureControl( nil );
    Screen.Cursor := OriginalCursor;
    bPaused := true;
  end;
end;

procedure tGamePlayHandler.AdvanceLevel;
var
  Level : integer;
begin
  Level := GameEngine.Level;
  if Level < ApplicationStateData.Map.Header^.Levels then
    GameEngine.Level := Level + 1
  else
    Initialise;
end;

function tGamePlayHandler.GetGameEngine : tGameEngine;
begin
  result := fGameEngine;
  if result = nil then
    Abort;
end;

function tGamePlayHandler.IsPaused : boolean;
begin
  result := bPaused;
end;

procedure tGamePlayHandler.SetCentre;
begin
  with ApplicationStateData.Form do
  begin
    ptCentre.X := Left + ( Width div 2 );
    ptCentre.Y := Top + ( Height div 2 );
  end;
  Mouse.CursorPos := ptCentre;
end;

procedure tGamePlayHandler.UpdateCamera;
begin
  with GameEngine.GameState.Rescuer do
  begin
    SoundReceiver.Orientation.reset;
    SoundReceiver.setLocation( Location );
    SoundReceiver.Orientation.rotateY( PI - Orientation );
  end;
  ApplicationStateData.AudioManager.DigitalAudio.SetListenerViewpoint( SoundReceiver );
  ApplicationStateData.Renderer.Camera.Assign( GameEngine.Camera );
end;

end.
