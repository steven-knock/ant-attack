unit LevelEdit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Map, ComCtrls;

type
  tfrmLevelEdit = class( tForm )
    grpLevel: TGroupBox;
    lblLatitude: TLabel;
    lblLongitude: TLabel;
    edtLatitude: TEdit;
    edtLongitude: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    lblAntCount: TLabel;
    lblSpawnInterval: TLabel;
    edtAntCount: TEdit;
    edtSpawnInterval: TEdit;
    spnAntCount: TUpDown;
    spnSpawnInterval: TUpDown;
    lblDrawDistance: TLabel;
    edtDrawDistance: TEdit;
    spnDrawDistance: TUpDown;
    procedure btnOKClick( Sender : tObject );
  private
    fMapLevel : tMapLevel;
    procedure   Populate;
  public
    constructor Create( aOwner : tComponent; aMapLevel : tMapLevel ); reintroduce;
  end;

implementation

{$R *.dfm}

uses
  Common, Math;

constructor tfrmLevelEdit.Create( aOwner : tComponent; aMapLevel : tMapLevel );
begin
  inherited Create( aOwner );
  fMapLevel := aMapLevel;
  Populate;
end;

procedure tfrmLevelEdit.Populate;
begin
  grpLevel.Caption := Format( grpLevel.Caption, [ fMapLevel.Info.Level ] );
  spnAntCount.Position := fMapLevel.Info.AntCount;
  spnSpawnInterval.Position := fMapLevel.Info.SpawnInterval;
  spnDrawDistance.Position := fMapLevel.Info.DrawDistance;
  edtLatitude.Text := SingleToStr( RadToDeg( fMapLevel.Info.LightPosition.Latitude ) );
  edtLongitude.Text := SingleToStr( RadToDeg( fMapLevel.Info.LightPosition.Longitude ) );
end;

procedure tfrmLevelEdit.btnOKClick( Sender : tObject );
const
  EPSILON = 0.00001;
var
  Input : tSphericalCoordinate;
begin
  try
    Input.Latitude := DegToRad( StrToFloat( edtLatitude.Text ) );
    Input.Longitude := DegToRad( StrToFloat( edtLongitude.Text ) );
    with fMapLevel.Info.LightPosition do
      if ( Abs( Latitude - Input.Latitude ) > EPSILON ) or ( Abs( Longitude - Input.Longitude ) > EPSILON ) then
        fMapLevel.InvalidateLightMap;
    fMapLevel.Info.LightPosition := Input;
    fMapLevel.Info.AntCount := spnAntCount.Position;
    fMapLevel.Info.DrawDistance := spnDrawDistance.Position;
    fMapLevel.Info.SpawnInterval := spnSpawnInterval.Position;
    ModalResult := mrOk;
  except
    MessageDlg( 'Please specify a pair of valid numbers', mtInformation, [ mbOk ], 0 );
  end;
end;

end.
