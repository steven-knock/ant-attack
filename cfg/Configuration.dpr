program Configuration;

uses
  Forms,
  main in 'main.pas' {frmConfig};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Ant Attack Configuration';
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.Run;
end.
