unit Messaging;

interface

uses
  Classes, Colour, Common, Geometry;

type
  tMessage = class( tObject )
  private
    fCategory : integer;
    fDescription : string;
    fPosition : tFloatPoint2d;
    fAlignment : tFloatPoint2d;
    fSize : _float;
    fColour : tColour;
    fBackgroundColour : tColour;
    fCreateTime : cardinal;  // Milliseconds
    fLifeTime : cardinal;
    fFadeTime : cardinal;
    function    GetCurrentColour( Index : integer ) : tColour;
  public
    constructor Create( aCategory : integer; const aDescription : string; aSize : _float; aLifeTime : cardinal );
    function    PostponeCreateTime( Offset : cardinal ) : tMessage;
    function    SetAlignment( x, y : _float ) : tMessage;
    function    SetBackgroundColour( BackgroundColour : tColour ) : tMessage; overload;
    function    SetColour( Colour : tColour ) : tMessage; overload;
    function    SetBackgroundColour( r, g, b, a : byte ) : tMessage; overload;
    function    SetColour( r, g, b, a : byte ) : tMessage; overload;
    function    SetFadeTime( aFadeTime : cardinal ) : tMessage;
    function    SetPosition( x, y : _float ) : tMessage;
    property    Category : integer read fCategory;
    property    Description : string read fDescription;
    property    Position : tFloatPoint2d read fPosition;
    property    Alignment : tFloatPoint2d read fAlignment;
    property    Size : _float read fSize;
    property    Colour : tColour read fColour;
    property    BackgroundColour : tColour read fBackgroundColour;
    property    CurrentColour : tColour index 0 read GetCurrentColour;
    property    CurrentBackgroundColour : tColour index 1 read GetCurrentColour;
    property    CreateTime : cardinal read fCreateTime;
    property    LifeTime : cardinal read fLifeTime;
    property    FadeTime : cardinal read fFadeTime;
  end;

  tMessageList = class( tObject )
  private
    fMessageList : tObjectList;
    function    Get( Idx : integer ) : tMessage;
  public
    constructor Create;
    destructor  Destroy; override;
    function    AddMessage( aMessage : tMessage ) : tMessage;
    procedure   Clear;
    procedure   ClearCategory( Category : integer );
    procedure   GetActiveMessages( MessageList : tList );
  end;

implementation

uses
  Windows;

(* tMessage *)

constructor tMessage.Create( aCategory : integer; const aDescription : string; aSize : _float; aLifeTime : cardinal );
begin
  inherited Create;
  fAlignment.x := 0.5;
  fCategory := aCategory;
  fDescription := aDescription;
  fSize := aSize;
  fColour.a := 255;
  fCreateTime := GetTickCount;
  fLifeTime := aLifeTime;
  if fLifeTime >= 4000 then
    fFadeTime := 1000
  else
    fFadeTime := 0;
end;

function tMessage.GetCurrentColour( Index : integer ) : tColour;
var
  Now : cardinal;
  Factor : _float;
  Solid : boolean;
begin
  if Index = 0 then
    result := Colour
  else
    result := BackgroundColour;

  Now := GetTickCount;
  Solid := true;
  Factor := 1;
  if FadeTime > 0 then
  begin
    if Now > CreateTime then
    begin
      if Now < CreateTime + FadeTime then
      begin
        Factor := ( Now - CreateTime ) / FadeTime;
        Solid := false;
      end
      else if Now < CreateTime + LifeTime then
      begin
        if Now > CreateTime + LifeTime - FadeTime then
        begin
          Factor := ( CreateTime + LifeTime - Now ) / FadeTime;
          Solid := false;
        end
      end
      else if LifeTime <> 0 then
      begin
        Factor := 0;
        Solid := false;
      end
    end
    else
    begin
      Factor := 0;
      Solid := false;
    end
  end;
  if not Solid then
    result.a := Trunc( Sin( Factor ) * result.a );
end;

function tMessage.PostponeCreateTime( Offset : cardinal ) : tMessage;
begin
  inc( fCreateTime, Offset );
  result := Self;
end;

function tMessage.SetAlignment( x, y : _float ) : tMessage;
begin
  fAlignment.x := x;
  fAlignment.y := y;
  result := Self;
end;

function tMessage.SetBackgroundColour( BackgroundColour : tColour ) : tMessage;
begin
  fBackgroundColour := BackgroundColour;
  result := Self;
end;

function tMessage.SetColour( Colour : tColour ) : tMessage;
begin
  fColour := Colour;
  result := Self;
end;

function tMessage.SetBackgroundColour( r, g, b, a : byte ) : tMessage;
begin
  fBackgroundColour.r := r;
  fBackgroundColour.g := g;
  fBackgroundColour.b := b;
  fBackgroundColour.a := a;
  result := Self;
end;

function tMessage.SetColour( r, g, b, a : byte ) : tMessage;
begin
  fColour.r := r;
  fColour.g := g;
  fColour.b := b;
  fColour.a := a;
  result := Self;
end;

function tMessage.SetFadeTime( aFadeTime : cardinal ) : tMessage;
begin
  fFadeTime := aFadeTime;
  result := Self;
end;

function tMessage.SetPosition( x, y : _float ) : tMessage;
begin
  fPosition.x := x;
  fPosition.y := y;
  result := Self;
end;

(* tMessageList *)

constructor tMessageList.Create;
begin
  inherited;
  fMessageList := tObjectList.Create;
end;

destructor tMessageList.Destroy;
begin
  fMessageList.Free;
  inherited;
end;

function tMessageList.Get( Idx : integer ) : tMessage;
begin
  result := tMessage( fMessageList[ Idx ] );
end;

function tMessageList.AddMessage( aMessage : tMessage ) : tMessage;
begin
  result := aMessage;
  fMessageList.Add( aMessage );
end;

procedure tMessageList.Clear;
begin
  fMessageList.Clear;
end;

procedure tMessageList.ClearCategory( Category : integer );
var
  Idx : integer;
begin
  for Idx := fMessageList.Count - 1 downto 0 do
    if Get( Idx ).Category = Category then
      fMessageList.Delete( Idx );
end;

procedure tMessageList.GetActiveMessages( MessageList : tList );
var
  Idx : integer;
  Now : cardinal;
  Msg : tMessage;
begin
  MessageList.Clear;
  Now := GetTickCount;
  for Idx := fMessageList.Count - 1 downto 0 do
  begin
    Msg := Get( Idx );
    if Msg.CreateTime <= Now then
    begin
      if ( Msg.CreateTime + Msg.LifeTime >= Now ) or ( Msg.LifeTime = 0 ) then
        MessageList.Add( Msg )
      else
        fMessageList.Delete( Idx );
    end;
  end;
end;

end.
