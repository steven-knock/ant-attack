unit AvailableMapList;

interface

uses
  Classes, Common, Map;

type
  tAvailableMapList = class( tObjectList )
  private
    fCurrentIndex : integer;
    fPath : string;
    fFileNames : tStringList;
    fMapNames : tStringList;
    function    GetMap( Index : integer ) : tMap;
    function    GetMP3FileName( Index : integer ) : string;
    procedure   SetPath( aPath : string );
  public
    constructor Create; overload;
    constructor Create( const aPath : string ); overload;
    destructor  Destroy; override;
    procedure   Refresh;
    property    CurrentIndex : integer read fCurrentIndex write fCurrentIndex;
    property    Map[ Index : integer ] : tMap read GetMap;
    property    MP3FileName[ Index : integer ] : string read GetMP3FileName;
    property    Path : string read fPath write SetPath;
  end;

implementation

uses
  Forms, SysUtils;

const
  MP3_EXTENSION = '.mp3';

constructor tAvailableMapList.Create;
begin
  Create( ExtractFilePath( Application.EXEName ) );
end;

constructor tAvailableMapList.Create( const aPath : string );
begin
  inherited Create;
  fFileNames := tStringList.Create;
  fMapNames := tStringList.Create;
  fMapNames.Sorted := true;
  Path := aPath;
end;

destructor tAvailableMapList.Destroy;
begin
  fFileNames.Free;
  fMapNames.Free;
  inherited;
end;

function tAvailableMapList.GetMap( Index : integer ) : tMap;
begin
  result := tMap( Get( Index ) );
end;

function tAvailableMapList.GetMP3FileName( Index : integer ) : string;
begin
  result := Path + ChangeFileExt( fFileNames[ Index ], MP3_EXTENSION );
  if not FileExists( result ) then
    result := '';
end;

procedure tAvailableMapList.SetPath( aPath : string );
begin
  if ( aPath <> fPath ) and ( Length( aPath ) > 0 ) then
  begin
    fPath := aPath;
    if fPath[ Length( fPath ) ] <> '\' then
      fPath := fPath + '\';
  end;
end;

procedure tAvailableMapList.Refresh;
var
  ChosenName : string;
  SearchRec : tSearchRec;
  Code, Index : integer;
  cMap : tMap;
begin
  ChosenName := '';
  if fCurrentIndex < fMapNames.Count then
    ChosenName := fMapNames[ fCurrentIndex ];

  Clear;
  fMapNames.Clear;
  fFileNames.Clear;

  Code := FindFirst( Path + '*' + MAP_EXTENSION, faReadOnly or faArchive, SearchRec );
  if Code = 0 then
  begin
    try
      repeat
        if ( SearchRec.Attr and faDirectory ) = 0 then
        begin
          try
            cMap := tMap.Create( Path + SearchRec.Name );
            Index := fMapNames.Add( cMap.Header^.Title );
            Insert( Index, cMap );
            fFileNames.Insert( Index, SearchRec.Name );
            Code := FindNext( SearchRec );
          except
            on e : eInOutError do
              { Nothing }
          end;
        end;
      until Code <> 0;
    finally
      FindClose( SearchRec );
    end;
  end;

  fCurrentIndex := -1;
  for Index := 0 to fMapNames.Count - 1 do
    if fMapNames[ Index ] = ChosenName then
    begin
      fCurrentIndex := Index;
      break;
    end;
  if ( fCurrentIndex = -1 ) and ( fMapNames.Count > 0 ) then
    fCurrentIndex := 0;
end;

end.
