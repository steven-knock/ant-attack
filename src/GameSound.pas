unit GameSound;

interface

uses
  Classes, Forms, Geometry, SharedStateData, Sound;

type
  tSoundType =  (
    SOUND_GRENADE, SOUND_EXPLOSION,
    SOUND_ANT_EMERGE, SOUND_ANT_ATTACK, SOUND_ANT_BITE, SOUND_ANT_PARALYSIS, SOUND_ANT_RUN, SOUND_ANT_WALK, SOUND_ANT_PAIN, SOUND_ANT_DEAD,
    SOUND_HUMAN_RUN, SOUND_HUMAN_WALK,
    SOUND_MALE_JUMP, SOUND_MALE_THROW, SOUND_MALE_PAIN1, SOUND_MALE_PAIN2, SOUND_MALE_PAIN3, SOUND_MALE_DEAD,
    SOUND_FEMALE_JUMP, SOUND_FEMALE_THROW, SOUND_FEMALE_PAIN1, SOUND_FEMALE_PAIN2, SOUND_FEMALE_PAIN3, SOUND_FEMALE_DEAD,
    SOUND_ATMOSPHERE
  );

  tHumanSoundType = ( SOUND_RUN, SOUND_WALK, SOUND_JUMP, SOUND_THROW, SOUND_PAIN1, SOUND_PAIN2, SOUND_PAIN3, SOUND_DEAD );

  tGameAudioManager = class( tAudioManager )
  private
    Sample : array [ tSoundType ] of tSoundSample;
    procedure   LoadGameSounds;
  protected
    function    GetSample( Index : integer ) : tSoundSample; override;
  public
    constructor Create( Form : tForm );
    destructor  Destroy; override;
  end;

const
  GenderSoundCrossReference : array [ tGender, tHumanSoundType ] of tSoundType = (
    ( SOUND_HUMAN_RUN, SOUND_HUMAN_WALK, SOUND_MALE_JUMP, SOUND_MALE_THROW, SOUND_MALE_PAIN1, SOUND_MALE_PAIN2, SOUND_MALE_PAIN3, SOUND_MALE_DEAD ),
    ( SOUND_HUMAN_RUN, SOUND_HUMAN_WALK, SOUND_FEMALE_JUMP, SOUND_FEMALE_THROW, SOUND_FEMALE_PAIN1, SOUND_FEMALE_PAIN2, SOUND_FEMALE_PAIN3, SOUND_FEMALE_DEAD )
  );

implementation

uses
  GameState, Resource, WavSample;

constructor tGameAudioManager.Create( Form : tForm );
begin
  inherited;
  LoadGameSounds;
  DigitalAudio.SetReferenceDistance( 3 );   // Distance units before sound aplitude is halved
end;

destructor tGameAudioManager.Destroy;
var
  Idx : tSoundType;
begin
  for Idx := Low( tSoundType ) to High( tSoundType ) do
    Sample[ Idx ].Free;
  inherited;
end;

function tGameAudioManager.GetSample( Index : integer ) : tSoundSample; 
begin
  result := Sample[ tSoundType( Index ) ];
end;

procedure tGameAudioManager.LoadGameSounds;
var
  SoundType : tSoundType;
  SampleID : cardinal;
  WavData : pointer;
  WavSample : tWavSoundSample;
begin
  for SoundType := Low( tSoundType ) to High( tSoundType ) do
  begin
    SampleID := Ord( SoundType );
    WavData := GetSoundEffect( SampleID );
    if WavData <> nil then
    begin
      WavSample := tWavSoundSample.Create( WavData );
      try
        DigitalAudio.LoadSample( SampleID, WavSample );
        WavSample.ReleaseData;
        Sample[ SoundType ] := WavSample;
      except
        WavSample.Free;
        raise;
      end;
    end;
  end;
end;

end.
