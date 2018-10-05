Unit MapProp;

Interface

Uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Map;

Type
  tfrmProperties = Class(tForm)
    grpInformation: TGroupBox;
    lblTitle: TLabel;
    edtTitle: TEdit;
    edtWidth: TEdit;
    edtHeight: TEdit;
    lblWidth: TLabel;
    lblHeight: TLabel;
    spnWidth: TUpDown;
    spnHeight: TUpDown;
    grpPalette: TGroupBox;
    lblGround: TLabel;
    lblWater: TLabel;
    lblLight: TLabel;
    lblDark: TLabel;
    pnlGround: TPanel;
    pbxGround: TPaintBox;
    pnlLight: TPanel;
    pbxLight: TPaintBox;
    pnlWater: TPanel;
    pbxWater: TPaintBox;
    pnlDark: TPanel;
    pbxDark: TPaintBox;
    dlgColour: TColorDialog;
    btnOk: TButton;
    btnCancel: TButton;
    grpOptions: TGroupBox;
    lblHitPoints: TLabel;
    edtHitPoints: TEdit;
    spnHitPoints: TUpDown;
    lblGrenades: TLabel;
    edtGrenades: TEdit;
    spnGrenades: TUpDown;
    lblAntHitPoints: TLabel;
    edtAntHitPoints: TEdit;
    spnAntHitPoints: TUpDown;
    lblLevels: TLabel;
    edtLevels: TEdit;
    spnLevels: TUpDown;
    chk1stPerson: TCheckBox;
    Procedure btnOkClick (Sender : tObject);
    Procedure pbxSwatchClick (Sender : tObject);
    Procedure pbxSwatchPaint (Sender : tObject);
  Private
    Header : pMapHeader;
  Public
    Constructor CreateMap ( aOwner : tComponent; Header : pMapHeader );
  End;

Implementation

{$R *.DFM}

(* Constructor *)

Constructor tfrmProperties.CreateMap ( aOwner : tComponent; Header : pMapHeader );
Begin
  Inherited Create(aOwner);
  Self.Header := Header;
  With Header^ Do
  Begin
    edtTitle.Text:=Title;
    edtTitle.MaxLength:=MAP_SIZE_TITLE;
    spnWidth.Min:=MAP_SIZE_MIN;
    spnWidth.Max:=MAP_SIZE_MAX;
    spnWidth.Position:=Width;
    spnHeight.Min:=MAP_SIZE_MIN;
    spnHeight.Max:=MAP_SIZE_MAX;
    spnHeight.Position:=Height;
    spnHitPoints.Position:=HitPoints;
    spnGrenades.Position:=Grenades;
    spnAntHitPoints.Position:=AntHitPoints;
    spnLevels.Position:=Levels;
    chk1stPerson.Checked := ( Flags and MAP_FLAG_1ST_PERSON_ONLY ) <> 0;
    pbxGround.Tag:=Palette[PAL_GROUND].rgba;
    pbxLight.Tag:=Palette[PAL_LIGHT].rgba;
    pbxWater.Tag:=Palette[PAL_WATER].rgba;
    pbxDark.Tag:=Palette[PAL_DARK].rgba;
  End;
End;

(* Events *)

Procedure tfrmProperties.btnOkClick (Sender : tObject);

procedure setFlag( Flag : integer; Value : boolean );
begin
  if Value then
    Header^.Flags := Header^.Flags or Flag
  else
    Header^.Flags := Header^.Flags and not Flag;
end;

Begin
  With Header^ Do
  Begin
    StrPLCopy(Title,Trim(edtTitle.Text),MAP_SIZE_TITLE);
    Width:=spnWidth.Position;
    Height:=spnHeight.Position;
    HitPoints:=spnHitPoints.Position;
    Grenades:=spnGrenades.Position;
    AntHitPoints:=spnAntHitPoints.Position;
    Levels:=spnLevels.Position;
    setFlag( MAP_FLAG_1ST_PERSON_ONLY, chk1stPerson.Checked );
    Palette[PAL_GROUND].rgba:=pbxGround.Tag;
    Palette[PAL_LIGHT].rgba:=pbxLight.Tag;
    Palette[PAL_WATER].rgba:=pbxWater.Tag;
    Palette[PAL_DARK].rgba:=pbxDark.Tag;
    ModalResult:=mrOk;
  End;
End;

Procedure tfrmProperties.pbxSwatchClick (Sender : tObject);
Var
  PaintBox : tPaintBox;
Begin
  PaintBox:=tPaintBox(Sender);
  dlgColour.Color:=PaintBox.Tag;
  If dlgColour.Execute Then
  Begin
    PaintBox.Tag:=dlgColour.Color;
    PaintBox.Repaint;
  End;
End;

Procedure tfrmProperties.pbxSwatchPaint (Sender : tObject);
Begin
  With tPaintBox(Sender), Canvas Do
  Begin
    Brush.Handle:=CreateSolidBrush(Tag);
    FillRect(GetClientRect);
  End;
End;

End.
