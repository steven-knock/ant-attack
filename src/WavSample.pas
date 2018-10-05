unit WavSample;

interface

uses
  Sound;

type
  tWAVSoundSample = class( tBaseSoundSample )
  private
    function    DecodeData( DataChunk : pointer; ChunkSize : cardinal ) : string;
    function    DecodeFormat( FormatChunk : pointer; ChunkSize : cardinal ) : string;
    procedure   DecodeWAVData( WAVData : pointer );
  public
    constructor Create( WAVData : pointer );
  end;

implementation

uses
  SysUtils;

constructor tWAVSoundSample.Create( WAVData : pointer );
begin
  inherited Create;
  DecodeWAVData( WAVData );
end;

function tWAVSoundSample.DecodeData( DataChunk : pointer; ChunkSize : cardinal ) : string;
begin
  if fData = nil then
  begin
    fSize := ChunkSize;
    GetMem( fData, ChunkSize );     // Destructor of base class will clean up
    Move( DataChunk^, fData^, ChunkSize );
  end;
end;

function tWAVSoundSample.DecodeFormat( FormatChunk : pointer; ChunkSize : cardinal ) : string;
type
  tFormatChunk = record
    FormatTag : shortint;
    Channels  : word;
    SamplesPerSec : cardinal;
    AvgBytesPerSec : cardinal;
    BlockAlign : word;
    BitsPerSample : word;
  end;
var
  pFormatChunk : ^tFormatChunk absolute FormatChunk;
begin
  result := '';
  if pFormatChunk^.FormatTag = 1 then
  begin
    fChannels := pFormatChunk^.Channels;
    if fChannels <= 2 then
    begin
      fFrequency := pFormatChunk^.SamplesPerSec;
      case pFormatChunk^.BitsPerSample of
        8:
          fDataType := SOUND_FRAGMENT_BYTE8;
        16:
          fDataType := SOUND_FRAGMENT_WORD16;
      else
        result := 'Unsupported WAV data type';
      end;
    end
    else
      result := 'Only Mono and Stereo formats are supported';
  end
  else
    result := 'Unsupported WAV format';
end;

procedure tWAVSoundSample.DecodeWAVData( WAVData : pointer );
const
  ID_RIFF   = $46464952;    // 'RIFF'
  ID_WAVE   = $45564157;    // 'WAVE'
  ID_FORMAT = $20746D66;    // 'fmt '
  ID_DATA   = $61746164;    // 'data';
var
  pScan : pByte;

function ReadLong : cardinal;
begin
  result := pCardinal( pScan )^;
  inc( pScan, SizeOf( Cardinal ) );
end;

var
  RiffType : cardinal;
  ChunkType : cardinal;
  ChunkSize : cardinal;
  Count : longint;
  FormatDone : boolean;
  DataDone : boolean;
  Error : string;
begin
  Error := '';
  if ReadLong = ID_RIFF then
  begin
    Count := ReadLong;
    RiffType := ReadLong;
    if RiffType = ID_WAVE then
    begin
      Dec( Count, SizeOf( Cardinal ) );
      FormatDone := false;
      DataDone := false;
      while ( Count > 0 ) and ( Error = '' ) do
      begin
        ChunkType := ReadLong;
        ChunkSize := ReadLong;

        Dec( Count, SizeOf( Cardinal ) * 2 );
        case ChunkType of
          ID_FORMAT:
          begin
            Error := DecodeFormat( pScan, ChunkSize );
            FormatDone := true;
          end;
          ID_DATA:
          begin
            Error := DecodeData( pScan, ChunkSize );
            DataDone := true;
          end;
        end;
        ChunkSize := ( ChunkSize + 1 ) and not 1;     // Chunks are always rounded to even bytes
        inc( pScan, ChunkSize );
        Dec( Count, ChunkSize );
      end;
      if Error = '' then
      begin
        if not FormatDone then
          Error := 'No format chunk found'
        else if not DataDone then
          Error := 'No data chunk found';
      end;
    end
    else
      Error := 'No WAVE data';
  end
  else
    Error := 'Not a WAV file';

  if Error <> '' then
    raise eConvertError.Create( 'Invalid WAV Format: ' + Error );
end;

end.
