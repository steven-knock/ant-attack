Unit Things;

Interface

Uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Map, ExtCtrls;

Type
  tfrmThing = Class(tForm)
    pnlThings: TPanel;
    pnlButtons: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    pnlImage: TPanel;
    pbxImage: TPaintBox;
    lblClass: TLabel;
    cmbClass: TComboBox;
    lblOrientation: TLabel;
    lblLevels: TLabel;
    lstLevels: TListBox;
    cmbOrientation: TComboBox;
    btnSelectAll: TButton;
    btnSelectNone: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnSelectNoneClick(Sender: TObject);
    procedure pbxImagePaint(Sender: TObject);
  Private
    cMap : tMap;
    cThing : tThing;
    function    GetThingInfo : tThingInfo;
    procedure   Initialise;
    procedure   Select( Mode : boolean );
  Public
    constructor Create( aOwner : tComponent; cMap : tMap; cThing : tThing ); reintroduce;
  End;

Implementation

{$R *.DFM}

uses
  Geometry, Resource;

type
  tCompassOrientation = ( NORTH, EAST, SOUTH, WEST );

const
  Orientation : array [ tCompassOrientation ] of string = ( 'North', 'East', 'South', 'West' );

constructor tfrmThing.Create( aOwner : tComponent; cMap : tMap; cThing : tThing );
begin
  inherited Create( aOwner );
  Self.cMap := cMap;
  Self.cThing := cThing;
  Initialise;
end;

procedure tfrmThing.btnOKClick(Sender: TObject);
begin
  cThing.Info := GetThingInfo;
  ModalResult := mrOk;
end;

procedure tfrmThing.btnSelectAllClick(Sender: TObject);
begin
  Select( true );
end;

procedure tfrmThing.btnSelectNoneClick(Sender: TObject);
begin
  Select( false );
end;

procedure tfrmThing.pbxImagePaint(Sender: TObject);
var
  BlockRenderInfo : tBlockRenderInfo;
begin
  pbxImage.Canvas.FillRect( pbxImage.ClientRect );
  with BlockRenderInfo do
  begin
    Canvas := pbxImage.Canvas;
    x := 4;
    y := 4;
    ZoomLevel := 8;
    CameraDirection := Low( tDirection );
  end;
  DrawThing( BlockRenderInfo, false, false, GetThingInfo );
end;

function tfrmThing.GetThingInfo : tThingInfo;
var
  Idx : integer;
  Mask : int64;
begin
  result := cThing.Info;
  result.ThingType := tThingType( cmbClass.ItemIndex );
  result.Orientation := PI - PI * cmbOrientation.ItemIndex / 2;
  result.LevelMask := 0;
  Mask := 1;
  for Idx := 0 to lstLevels.Count - 1 do
  begin
    if lstLevels.Selected[ Idx ] then
      result.LevelMask := result.LevelMask or Mask;
    Mask := Mask shl 1;
  end;
end;

procedure tfrmThing.Initialise;
var
  TIdx : tThingType;
  CIdx : tCompassOrientation;
  Idx : integer;
  Mask : int64;
  Bearing : _float;
begin
  for TIdx := Low( tThingType ) to High( tThingType ) do
    cmbClass.Items.Add( ThingTypeName[ TIdx ] );
  cmbClass.ItemIndex := Ord( cThing.Info.ThingType );

  for CIdx := Low( tCompassOrientation ) to High( tCompassOrientation ) do
    cmbOrientation.Items.Add( Orientation[ CIdx ] );

  Bearing := PI - cThing.Info.Orientation + ( PI / 4 );
  while Bearing < 0 do
    Bearing := Bearing + 2 * PI;
  cmbOrientation.ItemIndex := Trunc( Bearing * 2 / PI );

  Mask := 1;
  for Idx := 1 to cMap.Header^.Levels do
  begin
    lstLevels.Items.Add( 'Level ' + IntToStr( Idx ) );
    if ( cThing.Info.LevelMask and Mask ) <> 0 then
      lstLevels.Selected[ Idx - 1 ] := true;
    Mask := Mask shl 1;
  end;
end;

procedure tfrmThing.Select( Mode : boolean );
var
  Idx : integer;
begin
  for Idx := 0 to lstLevels.Count - 1 do
    lstLevels.Selected[ Idx ] := Mode;
end;

end.
