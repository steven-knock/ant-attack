unit Introduction;

interface

uses
  ApplicationStateData, Map;

type
  tIntroductionHandler = class( tApplicationStateHandler )
  private
    fIntroMap : tMap;
    fCurrentMap : tMap;
    StartTime : cardinal;
    AddedTitles : boolean;
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    destructor  Destroy; override;
    procedure   Finalise; override;
    procedure   Initialise; override;
    procedure   Process; override;
  end;

implementation

uses
  Colour, Common, Geometry, Resource, Windows, Renderer, Messaging, SharedStateData;

const
  MP3_INTRODUCTION = 'introduction.mp3';

constructor tIntroductionHandler.Create( aApplicationStateData : tApplicationStateData );
var
  MapHunk : pResourceHunk;
begin
  inherited Create( aApplicationStateData, STATE_INTRODUCTION, [ KEY_SELECT ] );
  MapHunk := GetIntroductionMap( 0 );
  fIntroMap := tMap.Create( pMapHeader( MapHunk.Data )^, MapHunk^.Size );
end;

destructor tIntroductionHandler.Destroy;
begin
  fIntroMap.Free;
  inherited;
end;

procedure tIntroductionHandler.Finalise;
begin
  ApplicationStateData.AudioManager.StopMusic;
  ApplicationStateData.Renderer.Map := fCurrentMap;
end;

procedure tIntroductionHandler.Initialise;
begin
  with ApplicationStateData.Renderer do
  begin
    fCurrentMap := Map;
    Map := fIntroMap;
    with RenderStatus do
    begin
      nFog := 255;    // We want to use Exponential fog even with a long draw distance
      nFOV := 90;
    end;
  end;
  AddedTitles := false;
  StartTime := GetTickCount;
  ApplicationStateData.AudioManager.PlayMusicFile( MakeApplicationRelative( MP3_INTRODUCTION ) );
end;

procedure tIntroductionHandler.Process;
const
  INITIAL_PHASE_DURATION = 15000;
  INTRODUCTION_DURATION = 50000;
  FADE_DURATION = 4000;

function CreateMessage( Message : string; Size, x, y : _float ) : tMessage;
begin
  result := ApplicationStateData.AddMessage( Message, Size, 45000 ).SetPosition( x, y ).SetAlignment( 0.5, 0 ).SetFadeTime( 1000 ).SetColour( COLOUR_CREDIT_MODEL );
end;

var
  ElapsedTime : cardinal;
  Angle, Progress : _float;
  LightPosition : tSphericalCoordinate;
begin
  ElapsedTime := GetTickCount - StartTime;
  if [] = ApplicationStateData.KeysPressed then
  begin
    with ApplicationStateData.Renderer do
    begin
      Progress := ElapsedTime / INITIAL_PHASE_DURATION;
      if ElapsedTime < INITIAL_PHASE_DURATION then
      begin
        Angle := ( PI / 2 ) * Progress;
        RenderStatus.nFarDistance := 60 + Angle * 30;
        Camera.SetLocation( Map.Width div 2, 1, 50 - Angle * 18 );
        Camera.Orientation.Reset;
        Camera.Orientation.RotateX( -Angle / 20 );
      end
      else if ElapsedTime < INTRODUCTION_DURATION then
      begin
        Angle := Sin( ( Progress - 1 ) * 2 * PI ) * ( PI / 180 );
        Camera.Orientation.Reset;
        Camera.Orientation.RotateX( -PI * 0.025 );
        Camera.Orientation.RotateY( Angle );
      end
      else if ElapsedTime < INTRODUCTION_DURATION + FADE_DURATION then
      begin
        Progress := ( ElapsedTime - INTRODUCTION_DURATION ) / FADE_DURATION;
        LightPosition := Map.Level[ MapLevel ].Info.LightPosition;
        LightPosition.Latitude := LightPosition.Latitude + ( ( -110 * PI / 180 ) - LightPosition.Latitude ) * Progress;
        LightMapManager.setLightSphericalPosition( LightPosition );
      end
      else
        ApplicationStateData.State := STATE_ATTRACT;
      if ( Progress >= 0.5 ) and not AddedTitles then
      begin
        CreateMessage( 'v' + VERSION_GAME, 6, 1, -1 ).SetColour( COLOUR_WHITE ).SetAlignment( 1, 0 );

        CreateMessage( 'Developed by Steven Knock', 12, 0, 0.2 ).SetColour( COLOUR_CREDIT_SJK );
        CreateMessage( 'Based on an original game by Sandy White', 8, 0, 0.35 ).SetColour( COLOUR_CREDIT_SANDY );
        CreateMessage( '"Antesher" theme, "Beyond the Sands"', 7.5, 0, 0.5 ).SetColour( COLOUR_CREDIT_ANDY );;
        CreateMessage( 'composed and performed by Andy Denton', 7.5, 0, 0.6 ).SetColour( COLOUR_CREDIT_ANDY );

        CreateMessage( 'The Hero', 7.5, -0.7, 0.72 );
        CreateMessage( 'The Heroine', 7.5, -0.225, 0.72 );
        CreateMessage( 'Ant', 7.5, 0.225, 0.72 );
        CreateMessage( 'Grenade', 7.5, 0.7, 0.72 );

        CreateMessage( 'Paolo Piselli', 7.5, -0.7, 0.81 );
        CreateMessage( 'Brian Collins', 7.5, -0.225, 0.81 );
        CreateMessage( 'Psionic', 7.5, 0.225, 0.81 );
        CreateMessage( 'Yasmeen Jahan', 7.5, 0.7, 0.81 );

        CreateMessage( 'Sound effects provided by www.SoundSnap.com', 7, 0, 0.9 ).SetColour( COLOUR_CREDIT_SOUND );

        AddedTitles := true;
      end;
    end;
  end
  else if KEY_ESCAPE in ApplicationStateData.KeysPressed then
    ApplicationStateData.State := STATE_CLOSING
  else
    ApplicationStateData.State := STATE_ATTRACT;
end;

end.
