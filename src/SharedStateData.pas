unit SharedStateData;

interface

uses
  Classes, Geometry, Log, Map, Messaging, Sound;

type
  tKeyCommand = ( KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_FIRE, KEY_JUMP, KEY_WALK, KEY_PAUSE, KEY_PERSPECTIVE, KEY_SELECT, KEY_ESCAPE, KEY_MAP, KEY_BOY, KEY_GIRL, KEY_HELP, KEY_ELTON, KEY_INVULNERABLE, KEY_SKIP_LEVEL, KEY_NULL );
  tKeyCommands = set of tKeyCommand;

  tGender = ( GENDER_MALE, GENDER_FEMALE );

  tSharedStateData = class( tObject )
  private
    fInvulnerable : boolean;
    fKeysPressed : tKeyCommands;
    fMessageList : tMessageList;
    fRescuerGender : tGender;
    fRescueeGender : tGender;
    fLog : tStrings;
    procedure   LogImpl( Category : tLogCategory; const Message : string );
  protected
    constructor Create;
    function    GetAudioManager : tAudioManager; virtual; abstract;
    function    GetMap : tMap; virtual; abstract;
    function    GetMessageCategory : integer; virtual; abstract;
    procedure   SetMap( aMap : tMap ); virtual; abstract;
  public
    destructor  Destroy; override;
    function    AddMessage( const Message : string; aSize : _float = 12; aLifeTime : cardinal = 0 ) : tMessage;
    procedure   ClearMessages;
    procedure   ExcludeKey( Key : tKeyCommand );
    procedure   IncludeKey( Key : tKeyCommand );
    function    IsLogEnabled : boolean;
    procedure   Log( Category : tLogCategory; const Message : string ); overload;
    procedure   Log( Category : tLogCategory; const Message : string; const Args : array of const ); overload;
    property    AudioManager : tAudioManager read GetAudioManager;
    property    Invulnerable : boolean read fInvulnerable write fInvulnerable;
    property    KeysPressed : tKeyCommands read fKeysPressed write fKeysPressed;
    property    LogSource : tStrings read fLog write fLog;
    property    Map : tMap read GetMap write SetMap;
    property    MessageList : tMessageList read fMessageList;
    property    RescuerGender : tGender read fRescuerGender write fRescuerGender;
    property    RescueeGender : tGender read fRescueeGender write fRescueeGender;
  end;

implementation

uses
  SysUtils;

(* tSharedStateData *)

constructor tSharedStateData.Create;
begin
  inherited Create;
  fMessageList := tMessageList.Create;
  fRescuerGender := GENDER_MALE;
  fRescueeGender := GENDER_FEMALE;
end;

destructor tSharedStateData.Destroy;
begin
  fMessageList.Free;
  inherited;
end;

function tSharedStateData.AddMessage( const Message : string; aSize : _float; aLifeTime : cardinal ) : tMessage;
begin
  result := MessageList.AddMessage( tMessage.Create( GetMessageCategory, Message, aSize, aLifeTime ) );
end;

procedure tSharedStateData.ClearMessages;
begin
  MessageList.ClearCategory( GetMessageCategory );
end;

procedure tSharedStateData.ExcludeKey( Key : tKeyCommand );
begin
  Exclude( fKeysPressed, Key );
end;

procedure tSharedStateData.IncludeKey( Key : tKeyCommand );
begin
  include( fKeysPressed, Key );
end;

function tSharedStateData.IsLogEnabled : boolean;
begin
  result := LogSource <> nil;
end;

procedure tSharedStateData.LogImpl( Category : tLogCategory; const Message : string );
begin
  LogSource.Add( LogCategoryDescription[ Category ] + ': ' + Message );
end;

procedure tSharedStateData.Log( Category : tLogCategory; const Message : string );
begin
  if LogSource <> nil then
    LogImpl( Category, Message );
end;

procedure tSharedStateData.Log( Category : tLogCategory; const Message : string; const Args : array of const );
begin
  if LogSource <> nil then
    LogImpl( Category, Format( Message, Args ) );
end;

end.
