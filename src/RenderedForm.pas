unit RenderedForm;

interface

uses
  Classes, Controls, Forms, Map, Renderer, MDIChildForm;

type
  tRenderedForm = class( tMDIChildForm )
  private
    cRenderer : tRenderer;
    sCaption : string;
  protected
    function    getMap : tMap; virtual;
    procedure   setMap( aMap : tMap ); virtual;
    procedure   updateMenu; override;
  public
    constructor create( aOwner : tComponent ); override;
    destructor  destroy; override;
    procedure   afterConstruction; override;
    procedure   updateCaption; virtual;
    property    Map : tMap read getMap write setMap;
    property    Renderer : tRenderer read cRenderer;
  end;

implementation

uses
  SysUtils;

(* Constructor *)

constructor tRenderedForm.create( aOwner : tComponent );
begin
  inherited create( aOwner );
  cRenderer := tRenderer.create;
  sCaption := Caption;
end;

destructor tRenderedForm.destroy;
begin
  FreeAndNil( cRenderer );
  inherited;
end;

function tRenderedForm.getMap : tMap;
begin
  result := cRenderer.Map;
end;

procedure tRenderedForm.setMap( aMap : tMap );
begin
  cRenderer.Map := aMap;
  updateCaption;
end;

procedure tRenderedForm.updateMenu;
begin
end;

procedure tRenderedForm.afterConstruction;
begin
  inherited;
  if cRenderer.RenderStatus.cControl <> nil then
    cRenderer.initialiseOpenGL;
  updateCaption;
end;

procedure tRenderedForm.updateCaption;
begin
  if Map <> nil then
    Caption := Format( sCaption, [ Map.Header^.Title ] );
end;

end.
