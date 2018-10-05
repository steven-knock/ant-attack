unit Progress;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ComCtrls, StdCtrls;

type
  TfrmProgress = class(TForm)
    pnlProgress: TPanel;
    barProgress: TProgressBar;
    lblInformation: TLabel;
    pnlButton: TPanel;
    btnCancel: TButton;
    procedure btnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    fOnCancel : tNotifyEvent;
  public
    constructor Create( aOwner : tComponent; const Title : string; Steps : integer ); reintroduce;
    procedure   SetPosition( Position : integer );
    procedure   SetInformation( const Information : String );
    property    OnCancel : tNotifyEvent read fOnCancel write fOnCancel;
  end;

implementation

{$R *.dfm}

constructor tfrmProgress.Create( aOwner : tComponent; const Title : string; Steps : integer );
begin
  inherited Create( aOwner );
  Caption := Title;
  barProgress.Max := Steps;
end;

procedure tfrmProgress.SetPosition( Position : integer );
begin
  barProgress.Position := Position;
end;

procedure tfrmProgress.SetInformation( const Information : String );
begin
  lblInformation.Caption := Information;
end;

procedure TfrmProgress.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmProgress.FormClose( Sender: TObject; var Action: tCloseAction );
begin
  if Assigned( fOnCancel ) then
    fOnCancel( Self );
  Action := caHide;
end;

end.
