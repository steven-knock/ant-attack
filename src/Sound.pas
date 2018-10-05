unit Sound;

interface

uses
  Classes, Contnrs, Forms, MPlayer, OpenAL, Geometry;

type
  tSoundFragmentType = ( SOUND_FRAGMENT_BYTE8, SOUND_FRAGMENT_WORD16, SOUND_FRAGMENT_FLOAT32 );

  tSoundSample = class( tObject )
  private
    function GetChannels : cardinal; virtual; abstract;
    function GetData : pointer; virtual; abstract;
    function GetDataFormat : tSoundFragmentType; virtual; abstract;
    function GetSize : cardinal; virtual; abstract;
    function GetFrequency : cardinal; virtual; abstract;
    function GetLength : _float;
  public
    property  Channels : cardinal read GetChannels;
    property  Data : pointer read GetData;
    property  DataFormat : tSoundFragmentType read GetDataFormat;
    property  Size : cardinal read GetSize;
    property  Frequency : cardinal read GetFrequency;
    property  Length : _float read GetLength;
  end;

  tBaseSoundSample = class( tSoundSample )
  protected
    fChannels : cardinal;
    fData : pointer;
    fDataType : tSoundFragmentType;
    fSize : cardinal;
    fFrequency : cardinal;
    function GetChannels : cardinal; override;
    function GetData : pointer; override;
    function GetDataFormat : tSoundFragmentType; override;
    function GetSize : cardinal; override;
    function GetFrequency : cardinal; override;
  public
    procedure ReleaseData;
    destructor  Destroy; override;
  end;

  tSoundSource = class( tObject )
  private
    fID : talUInt;
    fLocation : tPoint3d;
    fVoiceID : cardinal;
    fPriority : integer;
  public
    constructor Create( ID : talUInt );
    procedure   Play( VoiceID : cardinal; Location : tPoint3d; Priority : integer );
    procedure   Stop;
    procedure   UpdateLocation;
    property    ID : talUInt read fID;
    property    Location : tPoint3d read fLocation;
    property    Priority : integer read fPriority;
    property    VoiceID : cardinal read fVoiceID;
  end;

  tDigitalAudioManager = class( tObject )
  private
    MaximumSources : cardinal;
    NextVoiceID : cardinal;
    NextSourceIndex : cardinal;
    Linked : boolean;
    Device : tALCDevice;
    BufferList : tBucketList;
    VoiceList : tBucketList;
    SourceList : tObjectList;
    DynamicSourceList : tList;
    ListenerLocation : tPoint3d;
    procedure   AllocateSources;
    function    BuildDynamicSourceList( SourceState : talInt ) : tList;
    procedure   ChangeState( OldState, NewState : talInt );
    procedure   DeallocateSources;
    function    GetFreeSource( const Location : tPoint3d; Priority : integer ) : tSoundSource;
    function    IsActive : boolean;
    procedure   StopSource( Source : tSoundSource );
  public
    constructor Create( MaximumSources : cardinal = 64 );
    destructor  Destroy; override;
    function    CreateVoice : cardinal;
    procedure   CreateVoices( var VoiceIDs : array of talUInt );
    procedure   DeleteSample( SampleID : cardinal );
    procedure   DeleteVoice( VoiceID : cardinal );
    procedure   DeleteVoices( const VoiceIDs : array of talUInt );
    procedure   Finalise;
    procedure   Initialise;
    procedure   LoadSample( SampleID : cardinal; Sample : tSoundSample );
    procedure   Pause;
    procedure   PlaySound( VoiceID, SampleID : cardinal; Location : tPoint3d; Priority : integer; Loop : boolean = false );
    procedure   Resume;
    procedure   SetListenerViewpoint( Viewpoint : tViewpoint );
    procedure   SetReferenceDistance( Distance : _float );
    procedure   StopVoice( VoiceID : cardinal );
    procedure   UpdateSourceLocations;
    property    Active : boolean read IsActive;
  end;

  tAudioManager = class( tObject )
  private
    fDigitalAudioManager : tDigitalAudioManager;
    MediaPlayer : tMediaPlayer;
    ValidMusicFile : boolean;
  protected
    function    GetSample( Index : integer ) : tSoundSample; virtual; abstract;
  public
    constructor Create( Form : tForm );
    destructor  Destroy; override;
    function    PlayMusicFile( const FileName : string ) : boolean;
    procedure   PlayMusic;
    procedure   StopMusic;
    property    DigitalAudio : tDigitalAudioManager read fDigitalAudioManager;
    property    Sample[ Index : integer ] : tSoundSample read GetSample;
  end;

implementation

const
  ALBoolean : array [ boolean ] of talInt = ( AL_FALSE, AL_TRUE );

  SoundFragmentTypeSize : array [ tSoundFragmentType ] of cardinal = ( 1, 2, 4 );

(* tSoundSample *)

function tSoundSample.GetLength : _float;
begin
  result := ( Size div ( SoundFragmentTypeSize[ DataFormat ] * Channels ) ) / Frequency;
end;

(* tBaseSoundSample *)

procedure tBaseSoundSample.ReleaseData;
begin
  if fData <> nil then
  begin
    FreeMem( fData );
    fData := nil;
  end;
end;

destructor tBaseSoundSample.Destroy;
begin
  ReleaseData;
  inherited;
end;

function tBaseSoundSample.GetChannels : cardinal;
begin
  result := fChannels;
end;

function tBaseSoundSample.GetData : pointer;
begin
  result := fData;
end;

function tBaseSoundSample.GetDataFormat : tSoundFragmentType;
begin
  result := fDataType;
end;

function tBaseSoundSample.GetSize : cardinal;
begin
  result := fSize;
end;

function tBaseSoundSample.GetFrequency : cardinal;
begin
  result := fFrequency;
end;

(* tSoundSource *)

constructor tSoundSource.Create( ID : talUInt );
begin
  inherited Create;
  fID := ID;
end;

procedure tSoundSource.Play( VoiceID : cardinal; Location : tPoint3d; Priority : integer );
begin
  fVoiceID := VoiceID;
  fLocation := Location;
  fPriority := Priority;
  UpdateLocation;
  alSourcePlay( ID );
end;

procedure tSoundSource.Stop;
begin
  alSourceStop( ID );
  fVoiceID := 0;
  fLocation := nil;
end;

procedure tSoundSource.UpdateLocation;
var
  State : talInt;
begin
  alGetSourceI( ID, AL_SOURCE_STATE, @State );
  if State = AL_PLAYING then
    with Location do
      alSource3F( ID, AL_POSITION, x, y, z );
end;

(* tDigitalAudioManager *)

constructor tDigitalAudioManager.Create( MaximumSources : cardinal );
begin
  inherited Create;
  Self.MaximumSources := MaximumSources;
  BufferList := tBucketList.Create;
  VoiceList := tBucketList.Create;
  SourceList := tObjectList.Create;
  ListenerLocation := tPoint3d.Create;
  DynamicSourceList := tList.Create;
  Initialise;
end;

destructor tDigitalAudioManager.Destroy;
begin
  Finalise;
  DynamicSourceList.Free;
  ListenerLocation.Free;
  SourceList.Free;
  VoiceList.Free;
  BufferList.Free;
  inherited;
end;

procedure tDigitalAudioManager.AllocateSources;
var
  Idx : integer;
  SourceID : talUInt;
begin
  DeallocateSources;
  for Idx := 1 to MaximumSources do
  begin
    alGenSources( 1, @SourceID );
    if alGetError <> AL_NO_ERROR then
      break;
    SourceList.Add( tSoundSource.Create( SourceID ) );
  end;
  NextSourceIndex := 0;
end;

function tDigitalAudioManager.BuildDynamicSourceList( SourceState : talInt ) : tList;
var
  Idx : integer;
  SourceID : talUInt;
  State : talInt;
begin
  DynamicSourceList.Clear;
  if Active then
  begin
    for Idx := 0 to SourceList.Count - 1 do
    begin
      SourceID := tSoundSource( SourceList[ Idx ] ).ID;
      alGetSourceI( SourceID, AL_SOURCE_STATE, @State );
      if State = SourceState then
        DynamicSourceList.Add( pointer( SourceID ) );
    end;
  end;
  result := DynamicSourceList;
end;

procedure tDigitalAudioManager.ChangeState( OldState, NewState : talInt );
var
  AffectedSources : tList;
  Idx : integer;
  SourceID : cardinal;
begin
  AffectedSources := BuildDynamicSourceList( OldState );
  for Idx := 0 to AffectedSources.Count - 1 do
  begin
    SourceID := cardinal( AffectedSources[ Idx ] );
    case NewState of
      AL_PLAYING:
        alSourcePlay( SourceID );
      AL_STOPPED:
        alSourceStop( SourceID );
      AL_PAUSED:
        alSourcePause( SourceID );
    end;
  end;
end;

function tDigitalAudioManager.CreateVoice : cardinal;
begin
  result := NextVoiceID;
  inc( NextVoiceID );
end;

procedure tDigitalAudioManager.CreateVoices( var VoiceIDs : array of talUInt );
var
  Idx : integer;
begin
  for Idx := Low( VoiceIDs ) to High( VoiceIDs ) do
    VoiceIDs[ Idx ] := CreateVoice;
end;

procedure tDigitalAudioManager.DeallocateSources;
var
  Idx : integer;
  SourceID : talUInt;
begin
  for Idx := 0 to SourceList.Count - 1 do
  begin
    SourceID := tSoundSource( SourceList[ Idx ] ).ID;
    alDeleteSources( 1, @SourceID );
  end;
  SourceList.Clear;
  VoiceList.Clear;
end;

procedure tDigitalAudioManager.DeleteSample( SampleID : cardinal );
var
  BufferID : cardinal;
begin
  if Active and BufferList.Find( pointer( SampleID ), pointer( BufferID ) ) then
  begin
    alDeleteBuffers( 1, @BufferID );
    if alGetError = AL_NO_ERROR then
      BufferList.Remove( pointer( SampleID ) );
  end;
end;

procedure tDigitalAudioManager.DeleteVoice( VoiceID : cardinal );
var
  Source : tSoundSource;
begin
  if Active and VoiceList.Find( pointer( VoiceID ), pointer( Source ) ) then
    StopSource( Source );
end;

procedure tDigitalAudioManager.DeleteVoices( const VoiceIDs : array of talUInt );
var
  Idx : integer;
begin
  for Idx := Low( VoiceIDs ) to High( VoiceIDs ) do
    DeleteVoice( VoiceIDs[ Idx ] );
end;

procedure tDigitalAudioManager.Finalise;

procedure DeleteBuffer( Info, Item, Data : pointer; out Continue : boolean );
begin
  alDeleteBuffers( 1, @Data );
  Continue := true;
end;

begin
  if Linked then
  begin
    if alcGetCurrentContext <> nil then
    begin
      DeallocateSources;
      BufferList.ForEach( @DeleteBuffer );
      BufferList.Clear;
      alcMakeContextCurrent( nil );
    end;
    if Device <> nil then
    begin
      alcCloseDevice( Device );
      Device := nil;
    end;
  end;
end;

function tDigitalAudioManager.GetFreeSource( const Location : tPoint3d; Priority : integer ) : tSoundSource;
var
  Count : cardinal;
  Sources : cardinal;
  Source : tSoundSource;
  State : talInt;
  NewDistanceSq : _float;
  CurrentDistanceSq : _float;
  FarthestDistanceSq : _float;
  FarthestSource : tSoundSource;
begin
  result := nil;
  Count := SourceList.Count;
  Sources := Count;
  while Count > 0 do   // Iterate through sources to find the first free one
  begin
    Source := tSoundSource( SourceList[ NextSourceIndex ] );
    inc( NextSourceIndex );
    if NextSourceIndex >= Sources then
      NextSourceIndex := 0;

    alGetSourceI( Source.ID, AL_SOURCE_STATE, @State );
    if State <> AL_PLAYING then
    begin
      result := Source;
      exit;
    end;
    dec( Count );
  end;

  // All sources are playing - we need to decide whether to kick one out

  FarthestSource := nil;
  FarthestDistanceSq := 1000 * 1000;
  NewDistanceSq := ListenerLocation.distanceSq( Location );
  for Count := Sources downto 1 do
  begin
    Source := tSoundSource( SourceList[ NextSourceIndex ] );
    CurrentDistanceSq := ListenerLocation.distanceSq( Source.Location );
    inc( NextSourceIndex );
    if NextSourceIndex >= Sources then
      NextSourceIndex := 0;

    if CurrentDistanceSq > NewDistanceSq then   // This playing source is further away than the new sound we want to play so we kick it out
    begin
      StopSource( Source );
      result := Source;
      break;
    end;

    if ( Priority < Source.Priority ) and ( CurrentDistanceSq > FarthestDistanceSq ) then
      FarthestSource := Source;
  end;

  // We were farther away than any other sources - let's see whether we take priority over them

  if FarthestSource <> nil then
  begin
    StopSource( FarthestSource );
    result := FarthestSource;
  end;
end;

procedure tDigitalAudioManager.Initialise;
begin
  Finalise;
  if Linked or InitOpenAL then
  begin
    Linked := true;
    Device := alcOpenDevice( nil );
    if Device <> nil then
    begin
      alcMakeContextCurrent( alcCreateContext( Device, nil ) );
      if alGetError = AL_NO_ERROR then
      begin
        AllocateSources;
        NextVoiceID := 1;
      end;
    end;
  end;
end;

function tDigitalAudioManager.IsActive : boolean;
begin
  result := Linked and ( alcGetCurrentContext <> nil );
end;

procedure tDigitalAudioManager.LoadSample( SampleID : cardinal; Sample : tSoundSample );
const
  FormatXRef : array [ tSoundFragmentType, 1 .. 2 ] of talEnum = ( ( AL_FORMAT_MONO8, AL_FORMAT_STEREO8 ), ( AL_FORMAT_MONO16, AL_FORMAT_STEREO16 ), ( -1, -1 ) );
var
  Format : talEnum;
  BufferID : cardinal;
begin
  DeleteSample( SampleID );

  Format := FormatXRef[ Sample.DataFormat, Sample.Channels ];
  if Active and ( Format <> -1 ) then
  begin
    alGenBuffers( 1, @BufferID );
    if alGetError = AL_NO_ERROR then
    begin
      alBufferData( BufferID, Format, Sample.Data, Sample.Size, Sample.Frequency );
      if alGetError = AL_NO_ERROR then
        BufferList.Add( pointer( SampleID ), pointer( BufferID ) )
      else
        alDeleteBuffers( 1, @BufferID );
    end;
  end;
end;

procedure tDigitalAudioManager.Pause;
begin
  ChangeState( AL_PLAYING, AL_PAUSED );
end;

procedure tDigitalAudioManager.PlaySound( VoiceID, SampleID : cardinal; Location : tPoint3d; Priority : integer; Loop : boolean );
var
  Source : tSoundSource;
  BufferID : talInt;
  CurrentBufferID : talInt;
  State : talInt;
begin
  if Active then
  begin
    if not VoiceList.Find( pointer( VoiceID ), pointer( Source ) ) then
      Source := nil;
    if BufferList.Find( pointer( SampleID ), pointer( BufferID ) ) then
    begin
      if Source = nil then
        Source := GetFreeSource( Location, Priority );

      if Source <> nil then
      begin
        alGetSourceI( Source.ID, AL_BUFFER, @CurrentBufferID );
        alGetSourceI( Source.ID, AL_SOURCE_STATE, @State );
        if not Loop or ( CurrentBufferID <> BufferID ) or ( State <> AL_PLAYING ) then
        begin
          StopSource( Source );
          if CurrentBufferID <> BufferID then
            alSourceI( Source.ID, AL_BUFFER, BufferID );
          alSourceI( Source.ID, AL_LOOPING, ALBoolean[ Loop ] );
          Source.Play( VoiceID, Location, Priority );
          VoiceList.Add( pointer( VoiceID ), Source );
        end;
      end;
    end
    else if Source <> nil then
    begin
      StopSource( Source );
      alSourceI( Source.ID, AL_BUFFER, 0 );    // Detach Buffer
    end;
  end;
end;

procedure tDigitalAudioManager.Resume;
begin
  ChangeState( AL_PAUSED, AL_PLAYING );
end;

procedure tDigitalAudioManager.SetListenerViewpoint( Viewpoint : tViewpoint );
var
  Vec : array [ 0 .. 5 ] of _float;
begin
  if Active then
  begin
    with Viewpoint do
    begin
      with Orientation do
      begin
        Vec[ 0 ] := ptAxis[ 2 ].x;
        Vec[ 1 ] := ptAxis[ 2 ].y;
        Vec[ 2 ] := -ptAxis[ 2 ].z;
        Vec[ 3 ] := ptAxis[ 1 ].x;
        Vec[ 4 ] := ptAxis[ 1 ].y;
        Vec[ 5 ] := -ptAxis[ 1 ].z;
      end;
      alListener3F( AL_POSITION, x, y, z );
      alListenerFV( AL_ORIENTATION, @Vec );
    end;
    ListenerLocation.setLocation( Viewpoint );
  end;
end;

procedure tDigitalAudioManager.SetReferenceDistance( Distance : _float );
var
  Idx : integer;
begin
  if Active then
    for Idx := 0 to SourceList.Count - 1 do
      alSourceF( tSoundSource( SourceList[ Idx ] ).ID, AL_REFERENCE_DISTANCE, Distance );
end;

procedure tDigitalAudioManager.StopVoice( VoiceID : cardinal );
var
  Source : tSoundSource;
begin
  if Active and VoiceList.Find( pointer( VoiceID ), pointer( Source ) ) then
    StopSource( Source );
end;

procedure tDigitalAudioManager.StopSource( Source : tSoundSource );
begin
  if Active then
  begin
    VoiceList.Remove( pointer( Source.VoiceID ) );
    Source.Stop;
  end;
end;

procedure tDigitalAudioManager.UpdateSourceLocations;
var
  Idx : integer;
begin
  if Active then
    for Idx := 0 to SourceList.Count - 1 do
      tSoundSource( SourceList[ Idx ] ).UpdateLocation;
end;

(* tAudioManager *)

constructor tAudioManager.Create( Form : tForm );
begin
  inherited Create;
  fDigitalAudioManager := tDigitalAudioManager.Create;
  MediaPlayer := tMediaPlayer.Create( Form );    // Will be freed when the Form Closes
  MediaPlayer.Parent := Form;
  MediaPlayer.Visible := false;
end;

destructor tAudioManager.Destroy;
begin
  fDigitalAudioManager.Free;
  inherited;
end;

function tAudioManager.PlayMusicFile( const FileName : string ) : boolean;
begin
  StopMusic;
  MediaPlayer.FileName := FileName;
  try
    MediaPlayer.Open;
    MediaPlayer.Play;
    result := true;
  except
    result := false;
  end;
  ValidMusicFile := result;
end;

procedure tAudioManager.PlayMusic;
begin
  if ValidMusicFile and ( MediaPlayer.Mode = mpStopped ) then
    MediaPlayer.Play;
end;

procedure tAudioManager.StopMusic;
begin
  if MediaPlayer.Mode = mpPlaying then
    MediaPlayer.Stop;
end;

end.
