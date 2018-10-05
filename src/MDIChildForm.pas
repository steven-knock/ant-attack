unit MDIChildForm;

interface

uses
  Forms, Messages;

type
  tMDIChildForm = class( tForm )
  private
    procedure WMMDIActivate( var Msg : tWMMDIActivate ); message WM_MDIACTIVATE;
  protected
    procedure UpdateMenu; virtual; abstract;
  public
    destructor Destroy; override;
  end;

implementation

uses
  Windows;

procedure tMDIChildForm.WMMDIActivate( var Msg : tWMMDIActivate );
begin
  inherited;
  if Msg.ActiveWnd = Handle then
    UpdateMenu;
end;

destructor tMDIChildForm.Destroy;
begin
  if ( Owner <> nil ) and ( tForm( Owner ).Visible ) then
    PostMessage( tForm( Owner ).Handle, WM_INITMENU, 0, 0 );
  inherited;
end;

end.
