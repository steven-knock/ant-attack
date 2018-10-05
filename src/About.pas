unit About;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls;

type
  tfrmAbout = class( tForm )
    pnlInfo: TPanel;
    pnlButton: TPanel;
    btnClose: TButton;
    edtInfo: TRichEdit;
    procedure btnCloseClick( Sender : tObject );
    procedure FormClose( Sender : tObject; var Action : tCloseAction );
    procedure FormCreate( Sender : tObject );
    procedure FormResize( Sender: tObject );
  end;

var
  frmAbout : tfrmAbout;

implementation

{$R *.DFM}

uses
  Common, Resource;

procedure tfrmAbout.btnCloseClick( Sender : tObject );
begin
  close;
end;

procedure tfrmAbout.FormClose( Sender : tObject; var Action : tCloseAction );
begin
  Action := caFree;
  frmAbout := nil;
end;

procedure tfrmAbout.FormCreate( Sender : tObject );
var
  cRTF : tResourceStream;
begin
  Caption := Caption + ' - v' + VERSION_EDITOR;
  cRTF := tResourceStream.createFromID( hResourceInstance, RES_ABOUT_RTF, RT_RCDATA );
  try
    edtInfo.Lines.loadFromStream( cRTF );
  finally
    cRTF.free;
  end;
end;

procedure tfrmAbout.FormResize( Sender : tObject );
begin
  edtInfo.Repaint;
end;

end.
