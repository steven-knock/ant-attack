unit ApplicationStateData;

interface

uses
  AvailableMapList, Map, Renderer, RenderedForm, SharedStateData, Sound;

type
  tApplicationState = ( STATE_NULL, STATE_CREATING, STATE_INTRODUCTION, STATE_CHOOSE_MAP, STATE_ATTRACT, STATE_PLAY, STATE_CLOSING );

  tApplicationStateData = class( tSharedStateData )
  private
    fAudioManager : tAudioManager;
    fAvailableMapList : tAvailableMapList;
    fForm : tRenderedForm;
    fInEditor : boolean;
    fRenderRequired : boolean;
    fState : tApplicationState;
  protected
    function    GetAudioManager : tAudioManager; override;
    function    GetMap : tMap; override;
    procedure   SetMap( aMap : tMap ); override;
    function    GetMessageCategory : integer; override;
    function    GetRenderer : tRenderer;
  public
    constructor Create( aForm : tRenderedForm );
    destructor  Destroy; override;
    property    Form : tRenderedForm read fForm;
    property    InEditor : boolean read fInEditor write fInEditor;
    property    MapList : tAvailableMapList read fAvailableMapList;
    property    Renderer : tRenderer read GetRenderer;
    property    RenderRequired : boolean read fRenderRequired write fRenderRequired;
    property    State : tApplicationState read fState write fState;
  end;

  tApplicationStateHandler = class( tObject )
  private
    fApplicationStateData : tApplicationStateData;
    fState : tApplicationState;
    fKeysLatched : tKeyCommands;
  protected
    constructor Create( aApplicationStateData : tApplicationStateData; aState : tApplicationState; aKeysLatched : tKeyCommands );
    procedure   RenderMapTitle;
    property    ApplicationStateData : tApplicationStateData read fApplicationStateData;
  public
    procedure   Activate; virtual;
    procedure   Deactivate; virtual;
    procedure   Initialise; virtual;
    procedure   Finalise; virtual;
    procedure   Process; virtual; abstract;
    property    State : tApplicationState read fState;
    property    KeysLatched : tKeyCommands read fKeysLatched;
  end;

implementation

uses
  Colour, GameSound;

(* tApplicationStateData *)

constructor tApplicationStateData.Create( aForm : tRenderedForm );
begin
  inherited Create;
  fAudioManager := tGameAudioManager.Create( aForm );
  fAvailableMapList := tAvailableMapList.Create;
  fForm := aForm;
  fForm.Renderer.MessageList := MessageList;
end;

destructor tApplicationStateData.Destroy;
begin
  fAvailableMapList.Free;
  fAudioManager.Free;
  inherited;
end;

function tApplicationStateData.GetAudioManager : tAudioManager;
begin
  result := fAudioManager;
end;

function tApplicationStateData.GetMap : tMap;
begin
  result := Form.Map;
end;

procedure tApplicationStateData.SetMap( aMap : tMap );
begin
  Form.Map := aMap;
end;

function tApplicationStateData.GetMessageCategory : integer;
begin
  result := Ord( State );
end;

function tApplicationStateData.GetRenderer : tRenderer;
begin
  result := fForm.Renderer;
end;

(* tApplicationStateHandler *)

constructor tApplicationStateHandler.Create( aApplicationStateData : tApplicationStateData; aState : tApplicationState; aKeysLatched : tKeyCommands );
begin
  inherited Create;
  fApplicationStateData := aApplicationStateData;
  fState := aState;
  fKeysLatched := aKeysLatched;
end;

procedure tApplicationStateHandler.RenderMapTitle;
begin
  ApplicationStateData.AddMessage( ApplicationStateData.Renderer.Map.Header^.Title, 15 ).SetPosition( 0, -0.9 ).SetAlignment( 0.5, 0 ).SetColour( COLOUR_MAP_TITLE );
end;

procedure tApplicationStateHandler.Activate;
begin
end;

procedure tApplicationStateHandler.Deactivate;
begin
end;

procedure tApplicationStateHandler.Finalise;
begin
end;

procedure tApplicationStateHandler.Initialise;
begin
end;

end.
