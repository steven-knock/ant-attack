unit GameEngine;

interface

uses
  Classes, Geometry, Map, Messaging, GameState, PlayerInput, ApplicationStateData;

type
  tGameEngine = class;

  tTrackingCamera = class( tViewpoint )
  private
    fGameEngine : tGameEngine;
    fLatitude : _float;
    fMinimumLatitude, fMaximumLatitude : _float;
    fDistance, fVerticalOffset : _float;
    fMinimumPosition : _float;
    function    GetGameState : tGameState;
  protected
    property    GameState : tGameState read GetGameState;
  public
    constructor Create( GameEngine : tGameEngine );
    procedure   Update; virtual;
    property    Latitude : _float read fLatitude write fLatitude;
    property    MinimumLatitude : _float read fMinimumLatitude write fMinimumLatitude;
    property    MaximumLatitude : _float read fMaximumLatitude write fMaximumLatitude;
    property    MinimumPosition : _float read fMinimumPosition write fMinimumPosition;
    property    OrbitDistance : _float read fDistance write fDistance;
    property    VerticalOffset : _float read fVerticalOffset write fVerticalOffset;
  end;

  tTransitionCamera = class( tTrackingCamera )
  private
    fCamera1, fCamera2 : tTrackingCamera;
    fPosition : _float;
  public
    constructor Create( GameEngine : tGameEngine; Camera1, Camera2 : tTrackingCamera );
    procedure   Update; override;
    property    Position : _float read fPosition write fPosition;
  end;

  tGameEngineProcess = ( GE_MAIN, GE_RESCUER_DEAD, GE_RESCUEE_DEAD, GE_END_OF_LEVEL, GE_END_OF_MISSION, GE_FINISHED );

  tGameEngineProcessor = class( tObject )
  private
    fGameEngine : tGameEngine;
  protected
    constructor Create( GameEngine : tGameEngine );
    property    GameEngine : tGameEngine read fGameEngine;
  public
    procedure   Finalise; virtual;
    procedure   Initialise; virtual;
    procedure   Process; virtual; abstract;
  end;

  tGameEngine = class( tObject )
  private
    fCurrentProcess : tGameEngineProcess;
    fStateData : tApplicationStateData;
    fGameState : tGameState;
    fPlayerInput : tPlayerInput;
    fFirstPersonCamera : tTrackingCamera;
    fThirdPersonCamera : tTrackingCamera;
    fTransitionCamera : tTransitionCamera;
    fCinematicCamera : tTrackingCamera;
    fInterval : _float;
    GameEngineProcessors : array [ tGameEngineProcess ] of tGameEngineProcessor;
    procedure   CleanUp;
    function    GetCamera : tTrackingCamera;
    function    GetLevel : integer;
    procedure   InitialiseCameras;
    procedure   SetCurrentProcess( CurrentProcess : tGameEngineProcess );
    procedure   SetLevel( Level : integer );
    procedure   UpdateCamera;
    property    CurrentProcess : tGameEngineProcess read fCurrentProcess write SetCurrentProcess;
  public
    constructor Create( StateData : tApplicationStateData );
    destructor  Destroy; override;
    function    IsInCinematic : boolean;
    function    IsRunning : boolean;
    procedure   Process;
    procedure   SkipCinematic;
    procedure   Start;
    property    Camera : tTrackingCamera read GetCamera;
    property    GameState : tGameState read fGameState;
    property    Interval : _float read fInterval write fInterval;
    property    Level : integer read GetLevel write SetLevel;
    property    PlayerInput : tPlayerInput read fPlayerInput;
  end;

implementation

uses
  Colour, Common, Log, Math, SharedStateData, SysUtils;

type
  tMainGameEngineProcessor = class( tGameEngineProcessor )
  private
    function  IsLevelComplete : boolean;
  public
    procedure Process; override;
  end;

  tTimedGameEngineProcessor = class( tGameEngineProcessor )
  protected
    EndTime : _float;
  public
    procedure Initialise; override;
    procedure Process; override;
  end;

  tHumanDeadGameEngineProcessor = class( tTimedGameEngineProcessor )
  private
    procedure PositionCamera;
    procedure PrepareMessages;
  protected
    procedure GetMessages( MessageList : tStringList ); virtual; abstract;
    function  GetTarget : tPoint3d; virtual; abstract;
  public
    procedure Finalise; override;
    procedure Process; override;
  end;

  tRescuerDeadGameEngineProcessor = class( tHumanDeadGameEngineProcessor )
  protected
    procedure GetMessages( MessageList : tStringList ); override;
    function  GetTarget : tPoint3d; override;
  end;

  tRescueeDeadGameEngineProcessor = class( tHumanDeadGameEngineProcessor )
  protected
    procedure GetMessages( MessageList : tStringList ); override;
    function  GetTarget : tPoint3d; override;
  end;

  tEndOfLevelGameEngineProcessor = class( tTimedGameEngineProcessor )
  private
    procedure PositionCamera;
  protected
    procedure ClearHostileEntities;
    procedure DisplayMessage; virtual;
    function  GetTransitionLifeTime : integer; virtual;
    procedure ProcessFrame; virtual;
    procedure SetRescuerOrientation; virtual;
  public
    procedure Finalise; override;
    procedure Process; override;
  end;

  tEndOfMissionGameEngineProcessor = class( tEndOfLevelGameEngineProcessor )
  private
    RescueeCount : integer;
    NextRescueeTime : _float;
    StartAngle : _float;
    DrawDistance : cardinal;
    FogDensity : _float;
    LightPosition : tSphericalCoordinate;
    procedure IntroduceRescuees;
    procedure MoveRescuer;
    procedure PositionCamera;
  protected
    procedure DisplayMessage; override;
    function  GetTransitionLifeTime : integer; override;
    procedure ProcessFrame; override;
    procedure SetRescuerOrientation; override;
  public
    procedure Finalise; override;
    procedure Initialise; override;
  end;

const
  EPSILON = 0.001;

  HUMAN_DEAD_DELAY = 5.5;

  END_OF_LEVEL_DELAY = 4;

  END_OF_MISSION_DELAY = 250;

  SUNRISE_TIME = 5;

  RESCUEE_DELAY = 4;

(* tTrackingCamera *)

constructor tTrackingCamera.Create( GameEngine : tGameEngine );
begin
  inherited Create;
  fGameEngine := GameEngine;
  Latitude := 0;
  MinimumLatitude := -PI / 3;
  MaximumLatitude := PI / 3;
  OrbitDistance := 6;
  VerticalOffset := 0.8;
  MinimumPosition := 0.5;
end;

function tTrackingCamera.GetGameState : tGameState;
begin
  result := fGameEngine.GameState;
end;

procedure tTrackingCamera.Update;
var
  MinLat : _float;
  Height : _float;
begin
  if OrbitDistance > 0 then
  begin
    Height := VerticalOffset - MinimumPosition + GameState.Rescuer.Location.y;
    if Abs( Height ) < OrbitDistance then
      MinLat := -ArcSin( Height / OrbitDistance )
    else
      MinLat := MinimumLatitude;
  end
  else
    MinLat := MinimumLatitude;

  Latitude := Max( MinLat, Min( MaximumLatitude, Latitude ) );

  setLocation( 0, VerticalOffset, OrbitDistance );
  if OrbitDistance > 0 then
  begin
    rotateX( -Latitude );
    rotateY( PI + GameState.Rescuer.Orientation );
  end;

  translate( GameState.Rescuer.Location );

  Orientation.reset;
  Orientation.rotateX( Latitude );
  Orientation.rotateY( PI - Gamestate.Rescuer.Orientation );
end;

(* tTransitionCamera *)

constructor tTransitionCamera.Create( GameEngine : tGameEngine; Camera1, Camera2 : tTrackingCamera );
begin
  inherited Create( GameEngine );
  fCamera1 := Camera1;
  fCamera2 := Camera2;
end;

procedure tTransitionCamera.Update;
var
  Idx : integer;
  IPosition : _float;
begin
  fCamera1.Update;
  fCamera2.Update;

  setLocation( fCamera2 );
  subtract( fCamera1 );
  scale( Position );
  translate( fCamera1 );

  IPosition := 1 - Position;
  for Idx := 0 to 2 do
    with Orientation.ptAxis[ Idx ] do
    begin
      x := fCamera2.Orientation.ptAxis[ Idx ].x * Position + fCamera1.Orientation.ptAxis[ Idx ].x * IPosition;
      y := fCamera2.Orientation.ptAxis[ Idx ].y * Position + fCamera1.Orientation.ptAxis[ Idx ].y * IPosition;
      z := fCamera2.Orientation.ptAxis[ Idx ].z * Position + fCamera1.Orientation.ptAxis[ Idx ].z * IPosition;
    end;

  VerticalOffset := fCamera2.VerticalOffset * Position + fCamera1.VerticalOffset * IPosition;
end;

(* tGameEngine *)

constructor tGameEngine.Create( StateData : tApplicationStateData );
begin
  inherited create;
  GameEngineProcessors[ GE_MAIN ] := tMainGameEngineProcessor.Create( Self );
  GameEngineProcessors[ GE_RESCUER_DEAD ] := tRescuerDeadGameEngineProcessor.Create( Self );
  GameEngineProcessors[ GE_RESCUEE_DEAD ] := tRescueeDeadGameEngineProcessor.Create( Self );
  GameEngineProcessors[ GE_END_OF_LEVEL ] := tEndOfLevelGameEngineProcessor.Create( Self );
  GameEngineProcessors[ GE_END_OF_MISSION ] := tEndOfMissionGameEngineProcessor.Create( Self );
  fStateData := StateData;
  fPlayerInput := tPlayerInput.Create;
  fFirstPersonCamera := tTrackingCamera.Create( Self );
  fFirstPersonCamera.OrbitDistance := 0;
  fThirdPersonCamera := tTrackingCamera.Create( Self );
  fTransitionCamera := tTransitionCamera.Create( Self, fFirstPersonCamera, fThirdPersonCamera );
  fCinematicCamera := tTrackingCamera.Create( Self );
  fInterval := 1.0 / 50;
end;

destructor tGameEngine.Destroy;
var
  Processor : tGameEngineProcess;
begin
  for Processor := Low( tGameEngineProcess ) to High( tGameEngineProcess ) do
    GameEngineProcessors[ Processor ].Free;
  CleanUp;
  fPlayerInput.Free;
  fFirstPersonCamera.Free;
  fThirdPersonCamera.Free;
  fTransitionCamera.Free;
  fCinematicCamera.Free;
  inherited;
end;

procedure tGameEngine.CleanUp;
begin
  FreeAndNil( fGameState );
end;

function tGameEngine.GetCamera : tTrackingCamera;
begin
  if CurrentProcess = GE_MAIN then
    if ( fTransitionCamera.Position <= EPSILON ) or ( fTransitionCamera.Position >= 1 - EPSILON ) then
      if fGameState.FirstPerson then
        result := fFirstPersonCamera
      else
        result := fThirdPersonCamera
    else
      result := fTransitionCamera
  else
    result := fCinematicCamera;
end;

function tGameEngine.GetLevel : integer;
begin
  result := GameState.Level;
end;

procedure tGameEngine.InitialiseCameras;
begin
  fTransitionCamera.Position := 0;
  fFirstPersonCamera.Latitude := 0;
  fThirdPersonCamera.Latitude := 0;
end;

procedure tGameEngine.SetCurrentProcess( CurrentProcess : tGameEngineProcess );
begin
  if CurrentProcess <> fCurrentProcess then
  begin
    fCurrentProcess := CurrentProcess;
    if GameEngineProcessors[ CurrentProcess ] <> nil then
      GameEngineProcessors[ CurrentProcess ].Initialise;
  end;
end;

procedure tGameEngine.SetLevel( Level : integer );
begin
  GameState.Level := Level;
  CurrentProcess := GE_MAIN;
  InitialiseCameras;
end;

(* This routine advances the Transition Camera, if necessary. It also keeps all the cameras in sync so that the transitions between them are
   smooth and the user is not looking in odd or unexpected directions that would be remembered by the previous camera instance *)
procedure tGameEngine.UpdateCamera;
var
  TransitionSpeed : _float;
begin
  TransitionSpeed := 2 * Interval;
  if fGameState.FirstPerson then
  begin
    fFirstPersonCamera.VerticalOffset := GameState.Rescuer.EntityType.EyeOffset;
    if fTransitionCamera.Position > EPSILON then
    begin
      fFirstPersonCamera.Latitude := fTransitionCamera.Latitude;
      fTransitionCamera.Position := fTransitionCamera.Position - TransitionSpeed;
    end
    else
    begin
      fThirdPersonCamera.Latitude := fFirstPersonCamera.Latitude;
      fTransitionCamera.Latitude := 0;
    end;
  end
  else
  begin
    if fTransitionCamera.Position < 1 - EPSILON then
    begin
      fThirdPersonCamera.Latitude := fTransitionCamera.Latitude;
      fTransitionCamera.Position := fTransitionCamera.Position + TransitionSpeed;
    end
    else
    begin
      fFirstPersonCamera.Latitude := fThirdPersonCamera.Latitude;
      fTransitionCamera.Latitude := 0;
    end;
  end;
  Camera.Update;
end;

function tGameEngine.IsInCinematic : boolean;
begin
  result := ( CurrentProcess <> GE_MAIN ) and IsRunning;
end;

function tGameEngine.IsRunning : boolean;
begin
  result := ( GameState <> nil ) and ( CurrentProcess <> GE_FINISHED );
end;

procedure tGameEngine.Process;
begin
  if IsRunning then
    GameEngineProcessors[ CurrentProcess ].Process;
end;

procedure tGameEngine.SkipCinematic;
begin
  if IsInCinematic then
    GameEngineProcessors[ CurrentProcess ].Finalise;
end;

procedure tGameEngine.Start;
begin
  CleanUp;
  CurrentProcess := GE_MAIN;
  Randomize;
  fStateData.Log( LOG_GAME, 'Starting Game: %s', [ fStateData.Map.Header^.Title ] );
  fGameState := tGameState.Create( fStateData, PlayerInput );
  InitialiseCameras;
end;

(* tGameEngineProcessor *)

constructor tGameEngineProcessor.Create( GameEngine : tGameEngine );
begin
  inherited Create;
  fGameEngine := GameEngine;
end;

procedure tGameEngineProcessor.Finalise; 
begin
end;

procedure tGameEngineProcessor.Initialise;
begin
  GameEngine.fStateData.ClearMessages;
end;

(* tMainGameEngineProcessor *)

function tMainGameEngineProcessor.IsLevelComplete : boolean;
begin
  with GameEngine.GameState do
    result := not IsEntityInMap( Rescuer ) and ( Rescuer.State = STATE_MOBILE ) and ( ( Rescuee = nil ) or ( not IsEntityInMap( Rescuee ) and ( Rescuee.State = STATE_MOBILE ) ) );
end;

procedure tMainGameEngineProcessor.Process;
begin
  with GameEngine do
  begin
    GameState.Rescuer.Orientation := GameState.Rescuer.Orientation + PlayerInput.RotationAngle;
    GameState.ProcessEntities( Interval );
    UpdateCamera;
    PlayerInput.Reset;

    if IsLevelComplete then
    begin
      fCinematicCamera.assign( Camera );    // The next frame will display with the Cinematic Camera, so we initialise it here to avoid any flicker before the other processors get a chance to initialise it
      if GameState.Level = fStateData.Map.Header^.Levels then
        GameEngine.CurrentProcess := GE_END_OF_MISSION
      else
        GameEngine.CurrentProcess := GE_END_OF_LEVEL;
    end
    else if GameState.Rescuer.State = STATE_DEAD then
      GameEngine.CurrentProcess := GE_RESCUER_DEAD
    else if ( GameState.Rescuee <> nil ) and ( GameState.Rescuee.State = STATE_DEAD ) then
      GameEngine.CurrentProcess := GE_RESCUEE_DEAD;
  end;
end;

(* tTimedGameEngineProcessor *)

procedure tTimedGameEngineProcessor.Initialise;
begin
  inherited;
  EndTime := 0;
end;

procedure tTimedGameEngineProcessor.Process;
begin
  inherited;
  if GameEngine.GameState.Time >= EndTime then
    Finalise;
end;

(* tHumanDeadGameEngineProcessor *)

procedure tHumanDeadGameEngineProcessor.Finalise;
begin
  inherited;
  with GameEngine do
  begin
    CurrentProcess := GE_MAIN;
    InitialiseCameras;
    GameState.InitialiseLevel;
    fStateData.AddMessage( 'Try Again', 16, 4000 ).SetPosition( 0, 0.6 ).SetFadeTime( 250 ).SetColour( COLOUR_WHITE );
  end;
end;

procedure tHumanDeadGameEngineProcessor.PositionCamera;
var
  TimeElapsed : _float;
begin
  with GameEngine, Camera do
  begin
    TimeElapsed := GameState.Time - EndTime + HUMAN_DEAD_DELAY;
    setLocation( GetTarget );
    translate( 0, 1 + TimeElapsed * 4, 0 );
    Orientation.reset;
    Orientation.rotateX( PI / 2 );
    Orientation.rotateY( TimeElapsed * PI / 2 );
  end;
end;

procedure tHumanDeadGameEngineProcessor.PrepareMessages;
var
  Idx : integer;
  y : _float;
  MessageList : tStringList;
begin
  MessageList := tStringList.Create;
  try
    GetMessages( MessageList );
    y := -0.6;
    for Idx := 0 to MessageList.Count - 1 do
    begin
      GameEngine.fStateData.AddMessage( MessageList[ Idx ], 14, Round( 1000 * HUMAN_DEAD_DELAY ) ).SetPosition( 0, y ).SetFadeTime( Round( 200 * HUMAN_DEAD_DELAY ) ).SetColour( COLOUR_RED );
      y := y + 0.2;
    end;
  finally
    MessageList.Free;
  end;
end;

procedure tHumanDeadGameEngineProcessor.Process;
begin
  with GameEngine do
  begin
    if EndTime = 0 then
    begin
      PrepareMessages;
      EndTime := GameState.Time + HUMAN_DEAD_DELAY;
    end;

    PlayerInput.Reset;
    PositionCamera;
    GameState.ProcessEntities( Interval );
  end;
  inherited;
end;

(* tRescuerDeadGameEngineProcessor *)

procedure tRescuerDeadGameEngineProcessor.GetMessages( MessageList : tStringList );
begin
  case GameEngine.GameState.Rescuer.LastDamageCause of
    TYPE_ANT:
      MessageList.Add( 'Eaten Alive!' );
    TYPE_EXPLOSION:
      MessageList.Add( 'You blew yourself up!' );
  else
    MessageList.Add( 'Drowned!' );
  end;
end;

function tRescuerDeadGameEngineProcessor.GetTarget : tPoint3d;
begin
  result := GameEngine.GameState.Rescuer.Location;
end;

(* tRescueeDeadGameEngineProcessor *)

procedure tRescueeDeadGameEngineProcessor.GetMessages( MessageList : tStringList );
begin
  case GameEngine.GameState.Rescuee.LastDamageCause of
    TYPE_ANT:
      MessageList.Add( '"They got me!"' );
    TYPE_EXPLOSION:
    begin
      MessageList.Add( '"How could you,' );
      MessageList.Add( 'after all we''ve' );
      MessageList.Add( 'been through together?"' );
    end;
  else
    MessageList.Add( '"I can''t breath!"' );
  end;
end;

function tRescueeDeadGameEngineProcessor.GetTarget : tPoint3d;
begin
  result := GameEngine.GameState.Rescuee.Location;
end;

(* tEndOfLevelGameEngineProcessor *)

const
  ESCAPE_DELAY = 2.5;

procedure tEndOfLevelGameEngineProcessor.ClearHostileEntities;
var
  Idx : integer;
  Entity : tEntity;
begin
  with GameEngine.GameState, PhysicalEntityList do
    for Idx := Count - 1 downto 0 do
    begin
      Entity := tEntity( Items[ Idx ] );
      if ( Entity.EntityType.ID = TYPE_GRENADE ) or ( Entity.EntityType.ID = TYPE_EXPLOSION ) then
        RemoveEntity( Entity );
    end;
end;

procedure tEndOfLevelGameEngineProcessor.DisplayMessage;
var
  MessageDelay, MessageFade : integer;
begin
  MessageDelay := 1000 * END_OF_LEVEL_DELAY;
  MessageFade := MessageDelay div 4;
  GameEngine.fStateData.AddMessage( 'Congratulations', 17, MessageDelay ).SetPosition( 0, -0.6 ).SetFadeTime( MessageFade ).SetColour( COLOUR_WHITE );
  GameEngine.fStateData.AddMessage( 'Level Complete', 12, MessageDelay ).SetPosition( 0, -0.3 ).SetFadeTime( MessageFade ).SetColour( COLOUR_WHITE );
end;

procedure tEndOfLevelGameEngineProcessor.Finalise;
begin
  with GameEngine do
  begin
    CurrentProcess := GE_MAIN;
    Level := Level + 1;
    InitialiseCameras;
  end;
end;

function tEndOfLevelGameEngineProcessor.GetTransitionLifeTime : integer;
begin
  result := END_OF_LEVEL_DELAY;
end;

procedure tEndOfLevelGameEngineProcessor.PositionCamera;
var
  ElapsedTime : _float;
begin
  with GameEngine, Camera do
  begin
    ElapsedTime := GameState.Time + GetTransitionLifeTime - EndTime;
    OrbitDistance := fThirdPersonCamera.OrbitDistance + 12 * ElapsedTime;
    Latitude := PI / 16  + ( ElapsedTime * PI / 180 );
    Update;
  end;
end;

procedure tEndOfLevelGameEngineProcessor.Process;
begin
  with GameEngine do
  begin
    PlayerInput.Reset;
    if GameState.Rescuer.State <> STATE_ESCAPED then
    begin
      GameState.Rescuer.State := STATE_ESCAPED;
      EndTime := GameState.Time + GetTransitionLifeTime;
      ClearHostileEntities;
      SetRescuerOrientation;
      DisplayMessage;
    end;

    ProcessFrame;
  end;
  inherited;
end;

procedure tEndOfLevelGameEngineProcessor.ProcessFrame;
begin
  with GameEngine do
  begin
    PositionCamera;
    GameState.ProcessEntities( Interval );
  end;
end;

procedure tEndOfLevelGameEngineProcessor.SetRescuerOrientation;
begin
  with GameEngine.GameState, Rescuer, Location do
    if x < 0 then
      Orientation := -PI / 2
    else if x >= Map.Width then
      Orientation := PI / 2
    else if z < 0 then
      Orientation := PI
    else
      Orientation := 0;
end;

(* tEndOfMissionGameEngineProcessor *)

procedure tEndOfMissionGameEngineProcessor.DisplayMessage;
const
  Hero : array [ tGender ] of string = ( 'Hero', 'Heroine' );
var
  MessageDelay, MessageFade : integer;
begin
  MessageDelay := 1000 * END_OF_MISSION_DELAY;
  MessageFade := 750;
  GameEngine.fStateData.AddMessage( 'Mission', 26, MessageDelay ).SetPosition( 0, -0.9 ).SetFadeTime( MessageFade ).SetColour( COLOUR_WHITE );
  GameEngine.fStateData.AddMessage( 'Complete', 26, MessageDelay ).SetPosition( 0, -0.6 ).SetFadeTime( MessageFade ).SetColour( COLOUR_WHITE );
  GameEngine.fStateData.AddMessage( 'What a ' + Hero[ GameEngine.GameState.Rescuer.Gender ] + '!', 14, MessageDelay ).SetPosition( 0, 0.8 ).SetFadeTime( MessageFade ).SetColour( COLOUR_WHITE );
end;

procedure tEndOfMissionGameEngineProcessor.Finalise;
begin
  GameEngine.CurrentProcess := GE_FINISHED;
end;

procedure tEndOfMissionGameEngineProcessor.Initialise;
begin
  inherited;
  with GameEngine, fStateData.Renderer, GameState.Map.Level[ GameEngine.Level ] do
  begin
    DrawDistance := Info.DrawDistance;
    FogDensity := RenderStatus.nFogDensity;
    LightPosition := Info.LightPosition;
  end;
end;

function tEndOfMissionGameEngineProcessor.GetTransitionLifeTime : integer;
begin
  result := END_OF_MISSION_DELAY;
end;

procedure tEndOfMissionGameEngineProcessor.IntroduceRescuees;
var
  Location : tPoint3d;
begin
  with GameEngine do
  begin
    if RescueeCount < GameEngine.fStateData.Map.Header^.Levels then
    begin
      if GameState.Time > NextRescueeTime then
      begin
        Location := tPoint3d.Create( Camera );
        try
          Location.y := 0;
          GameState.AddPlayer( TYPE_RESCUEE, Location );
          inc( RescueeCount );
          NextRescueeTime := GameState.Time + RESCUEE_DELAY;
        finally
          Location.Free;
        end;
      end;
    end;
  end;
end;

procedure tEndOfMissionGameEngineProcessor.MoveRescuer;

function GetDifference( A1, A2 : _float ) : _float;
begin
  result := A2 - A1;
  if result > PI then
    result := result - 2 * PI
  else if result < -PI then
    result := result + 2 * PI;
end;

const
  Angle : array [ 0 .. 7 ] of _float = ( 0, PI / 2, PI, -PI / 2, 0, -PI / 2, PI, PI / 2 );
var
  ElapsedTime : _float;
  Orientation : _float;
  InterpolateTime : _float;
  A1, A2 : _float;
  Idx1, Idx2 : integer;
begin
  ElapsedTime := GameEngine.GameState.Time + GetTransitionLifeTime - EndTime - ESCAPE_DELAY;
  if ElapsedTime >= 0 then
  begin
    InterpolateTime := ( GameEngine.fThirdPersonCamera.OrbitDistance * 0.1 ) + 0.4;
    Idx1 := Trunc( ElapsedTime / InterpolateTime );
    ElapsedTime := ( ElapsedTime - ( Idx1 * InterpolateTime ) ) / InterpolateTime;    // Elapsed time now becomes a value between 0 and 1
    Idx1 := Idx1 mod Length( Angle );
    Idx2 := ( Idx1 + 1 ) mod Length( Angle );
    A1 := Angle[ Idx1 ];
    A2 := Angle[ Idx2 ];
    Orientation := A1 + ElapsedTime * GetDifference( A1, A2 );
    GameEngine.GameState.Rescuer.Orientation := StartAngle + Orientation;
  end;
end;

procedure tEndOfMissionGameEngineProcessor.PositionCamera;
var
  ElapsedTime : _float;
  ptLight : tSphericalCoordinate;
  DrawDistanceTarget : cardinal;
begin
  with GameEngine do
  begin
    ElapsedTime := GameState.Time + GetTransitionLifeTime - EndTime;
    if ElapsedTime < ESCAPE_DELAY then
    begin
      Camera.OrbitDistance := fThirdPersonCamera.OrbitDistance + 3 * ElapsedTime;
      Camera.Latitude := PI / 16  + ( ElapsedTime * PI / 180 );
      Camera.Update;
    end
    else
    begin
      ElapsedTime := ElapsedTime - ESCAPE_DELAY;
      if ElapsedTime > SUNRISE_TIME then
        ElapsedTime := SUNRISE_TIME;

      with GameEngine.fStateData.Renderer do
      begin
        DrawDistanceTarget := RenderStatus.nFog - 1;
        if DrawDistance < DrawDistanceTarget then
          RenderStatus.nFarDistance := Round( DrawDistance + ( ( DrawDistanceTarget - DrawDistance ) * ElapsedTime / SUNRISE_TIME ) );

        ElapsedTime := 1 - ( ElapsedTime / SUNRISE_TIME );
        ptLight.Latitude := LightPosition.Latitude * ElapsedTime;
        ptLight.Longitude := LightPosition.Longitude * ElapsedTime;
        LightMapManager.setLightSphericalPosition( ptLight );

        if DrawDistance < DrawDistanceTarget then
          RenderStatus.nFogDensity := ( FogDensity * ElapsedTime ) + 0.0001;
      end;
    end;
  end;
end;

procedure tEndOfMissionGameEngineProcessor.ProcessFrame;
begin
  with GameEngine do
  begin
    Camera.OrbitDistance := Camera.distance( GameState.Rescuer.Location );
    PositionCamera;
    MoveRescuer;
    IntroduceRescuees;
    GameState.ProcessEntities( Interval );
  end;
end;

procedure tEndOfMissionGameEngineProcessor.SetRescuerOrientation;
begin
  inherited;
  StartAngle := GameEngine.GameState.Rescuer.Orientation;
  RescueeCount := 1;
  NextRescueeTime := GameEngine.GameState.Time + ESCAPE_DELAY + RESCUEE_DELAY;
end;

end.
