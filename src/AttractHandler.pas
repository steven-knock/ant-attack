unit AttractHandler;

interface

uses
  Common, Geometry, ApplicationStateData, SharedStateData, HelpHandler;

type
  tAttractHandler = class( tApplicationStateHandler )
  private
    fEltonMode : boolean;
    fPreviousMusicIndex : integer;
    StartTime : cardinal;
    HelpHandler : tHelpMessageHandler;
    procedure   CalculateOrbitPosition;
    procedure   CalculatePosition( t : _float; out Position : tFloatPoint2d );
    procedure   ClearNotificationMessages;
    procedure   HandleKeyEvents;
    procedure   InitiateGame( Gender : tGender );
    procedure   PlayMapTheme;
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    destructor  Destroy; override;
    procedure   Initialise; override;
    procedure   Process; override;
  end;

implementation

uses
  Windows, Math, AvailableMapList, Colour, Map, Messaging;

const
  MSG_NOTIFICATION = -1;

constructor tAttractHandler.Create( aApplicationStateData : tApplicationStateData );
begin
  inherited Create( aApplicationStateData, STATE_ATTRACT, [ KEY_SELECT, KEY_HELP, KEY_ESCAPE, KEY_BOY, KEY_GIRL, KEY_ELTON ] );
  HelpHandler := tHelpMessageHandler.Create;
  fPreviousMusicIndex := -1;
end;

destructor tAttractHandler.Destroy;
begin
  HelpHandler.Free;
  inherited;
end;

procedure tAttractHandler.CalculateOrbitPosition;
var
  ElapsedTime : _float;
  Bearing : _float;
  dx, dy : _float;
  Scale : _float;
  Position, Target : tFloatPoint2d;
begin
  ElapsedTime := ( GetTickCount - StartTime ) / 1000;

  with ApplicationStateData.Renderer.Map.Header^ do
    Scale := 1 / ( 0.5 * Max( Width, Height ) );  

  CalculatePosition( ElapsedTime * Scale, Position );
  CalculatePosition( ElapsedTime * Scale + Scale * 5, Target );    

  dx := Target.x - Position.x;
  dy := Target.y - Position.y;
  if dy = 0 then
    if dx >= 0 then
      Bearing := PI / 2
    else
      Bearing := -PI / 2
  else
    Bearing := ArcTan2( dx, -dy );

  with ApplicationStateData.Renderer.Camera do
  begin
    x := Position.x;
    y := MAP_SIZE_COLUMN + 8 + 8 * Cos( 0.15 * ElapsedTime * PI );
    z := Position.y;
    Orientation.reset;
    Orientation.rotateX( PI / 8 + PI / 8 * Cos( 0.15 * ElapsedTime * PI ) );
    Orientation.rotateY( Bearing );
  end;
end;

procedure tAttractHandler.CalculatePosition( t : _float; out Position : tFloatPoint2d );
var
  Bearing : _float;
  ptRotation : tPoint3d;
  w, h : integer;
begin
  ptRotation := tPoint3d.Create;
  try
    with ApplicationStateData.Renderer.Map.Header^ do
    begin
      w := Width div 2;
      h := Height div 2;
    end;

    Bearing := t * 4 * PI;
    ptRotation.x := Sin( Bearing );
    ptRotation.z := 0.5 - ( Cos( Bearing ) * 0.5 );

    if Frac( t ) >= 0.5 then
      ptRotation.z := -ptRotation.z;     // Second half of a phase is opposite to the first

    Bearing := t * 30 * PI / 180;        // Rotate 30 degrees every cycle
    ptRotation.rotateY( Bearing );

    ptRotation.x := ptRotation.x * ( w - 4 );   // Stay within a margin
    ptRotation.z := ptRotation.z * ( h - 4 );
    ptRotation.translate( w, 0, h );

    Position.x := ptRotation.x;
    Position.y := ptRotation.z;
  finally
    ptRotation.Free;
  end;
end;

procedure tAttractHandler.ClearNotificationMessages;
begin
  ApplicationStateData.MessageList.ClearCategory( MSG_NOTIFICATION );
end;

procedure tAttractHandler.HandleKeyEvents;
const
  EnabledText : array [ boolean ] of string = ( 'disabled', 'enabled' );
begin
  if KEY_BOY in ApplicationStateData.KeysPressed then
    InitiateGame( GENDER_MALE );
  if KEY_GIRL in ApplicationStateData.KeysPressed then
    InitiateGame( GENDER_FEMALE );
  if ( KEY_SELECT in ApplicationStateData.KeysPressed ) and ( ApplicationStateData.MapList.Count > 1 ) then
  begin
    fPreviousMusicIndex := ApplicationStateData.MapList.CurrentIndex;
    ApplicationStateData.State := STATE_CHOOSE_MAP;
  end;
  if KEY_ELTON in ApplicationStateData.KeysPressed then
  begin
    fEltonMode := not fEltonMode;
    ClearNotificationMessages;
    ApplicationStateData.MessageList.AddMessage( tMessage.Create( MSG_NOTIFICATION, 'Elton mode ' + EnabledText[ fEltonMode ], 12, 2000 ).SetAlignment( 0.5, 0 ).SetColour( COLOUR_GAME_ELTON ).SetFadeTime( 250 ) );
    ApplicationStateData.RenderRequired := true;
  end;
  if KEY_HELP in ApplicationStateData.KeysPressed then
    HelpHandler.ProcessHelpRequest( ApplicationStateData.MessageList );
  if KEY_ESCAPE in ApplicationStateData.KeysPressed then
    ApplicationStateData.State := STATE_CLOSING;
end;

procedure tAttractHandler.Initialise;
var
  Prompt : string;
begin
  Prompt := '';
  if ApplicationStateData.MapList.Count > 1 then
    Prompt := 'Press Return to choose a map. ';
  RenderMapTitle;
  ApplicationStateData.AddMessage( 'Press "B" or "G" to Start Game', 11 ).SetPosition( 0, 0.9 ).SetAlignment( 0.5, 1 ).SetColour( COLOUR_RACING_GREEN );
  ApplicationStateData.AddMessage( Prompt + 'Press F1 for help', 7.5 ).SetPosition( 0, 0.98 ).SetAlignment( 0.5, 1 ).SetColour( COLOUR_ORANGE );
  ApplicationStateData.Renderer.MapLevel := 1;
  PlayMapTheme;
  HelpHandler.HelpActive := false;
  StartTime := GetTickCount;
end;

procedure tAttractHandler.InitiateGame( Gender : tGender );
begin
  fPreviousMusicIndex := -1;
  ClearNotificationMessages;
  with ApplicationStateData do
  begin
    RescuerGender := Gender;
    if fEltonMode then
      RescueeGender := Gender
    else
      RescueeGender := tGender( 1 - Ord( Gender ) );
    State := STATE_PLAY;
  end;
end;

procedure tAttractHandler.PlayMapTheme;
var
  FileName : string;
begin
  with ApplicationStateData do
  begin
    if fPreviousMusicIndex <> MapList.CurrentIndex then
    begin
      AudioManager.StopMusic;
      FileName := MapList.MP3FileName[ MapList.CurrentIndex ];
      if ( FileName <> '' ) and not AudioManager.PlayMusicFile( FileName ) then
        ApplicationStateData.AddMessage( 'Unable to play map theme', 10, 4000 ).SetPosition( 0, 0 ).SetAlignment( 0.5, 0.5 ).SetColour( COLOUR_WARNING ).SetFadeTime( 200 );
    end;
  end;
end;

procedure tAttractHandler.Process;
begin
  HandleKeyEvents;
  CalculateOrbitPosition;
end;

end.
