unit ExportMap;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Map;

type
  tfrmExport = class( tForm )
    grpFilename: TGroupBox;
    edtFilename: TEdit;
    btnFilename: TButton;
    grpFormat: TGroupBox;
    btnPackedWord: TRadioButton;
    btnBytePerBlock: TRadioButton;
    btnWordPerBlock: TRadioButton;
    grpRawOptions: TGroupBox;
    btnTitle: TCheckBox;
    btnDimension: TCheckBox;
    btnExport: TButton;
    btnCancel: TButton;
    dlgExport: TSaveDialog;
    btnSTLText: TRadioButton;
    grpSTLOptions: TGroupBox;
    btnGroundPlane: TCheckBox;
    lblScale: TLabel;
    edtScale: TEdit;
    btnSTLBinary: TRadioButton;
    lblArea: TLabel;
    edtLeft: TEdit;
    lblLeft: TLabel;
    edtTop: TEdit;
    lblTop: TLabel;
    lblWidth: TLabel;
    edtWidth: TEdit;
    lblHeight: TLabel;
    edtHeight: TEdit;
    procedure   btnExportClick( Sender : tObject );
    procedure   btnFilenameClick( Sender : tObject );
    procedure   rawExportFormatClick(Sender: TObject);
    procedure   stlExportFormatClick(Sender: TObject);
  private
    cMap : tMap;
    function    GetArea : tRect;
    function    GetScale : single;
    procedure   SetFileExtension( const Extension : string );
    procedure   UpdateControls( Tag : integer );
    procedure   Validate;
  public
    constructor Create( cOwner : tComponent; cMap : tMap ); reintroduce;
    function    GetExportOptions : tExportOptions;
    function    GetFilename : string;
  end;

implementation

{$R *.dfm}

constructor tfrmExport.Create( cOwner : tComponent; cMap : tMap );

procedure UpdateRadioCaption( btnRadio : tRadioButton; nSize : integer );
begin
  btnRadio.Caption := btnRadio.Caption + ' [' + IntToStr( nSize * cMap.Width * cMap.Height ) + ' bytes]';
end;

procedure UpdateCheckCaption( btnCheck : tCheckBox; nSize : integer );
begin
  btnCheck.Caption := btnCheck.Caption + ' [' + IntToStr( nSize ) + ' bytes]';
end;

begin
  inherited create( cOwner );
  Self.cMap := cMap;
  UpdateRadioCaption( btnPackedWord, sizeof( word ) );
  UpdateRadioCaption( btnBytePerBlock, sizeof( byte ) * 8 );
  UpdateRadioCaption( btnWordPerBlock, sizeof( word ) * 8 );
  UpdateCheckCaption( btnTitle, sizeof( cMap.Header^.Title ) );
  UpdateCheckCaption( btnDimension, sizeof( cMap.Width ) + sizeof( cMap.Height ) );
  edtWidth.Text := IntToStr( cMap.Width );
  edtHeight.Text := IntToStr( cMap.Height );
  rawExportFormatClick( Self );
end;

procedure tfrmExport.btnExportClick( Sender : tObject );
begin
  Validate;
  ModalResult := mrOk;
end;

procedure tfrmExport.btnFilenameClick( Sender : tObject );
begin
  dlgExport.FileName := edtFilename.Text;
  if dlgExport.Execute then
    edtFilename.Text := dlgExport.FileName;
end;

procedure tfrmExport.rawExportFormatClick(Sender: TObject);
begin
  SetFileExtension('.raw');
  UpdateControls( 1 );
end;

procedure tfrmExport.stlExportFormatClick(Sender: TObject);
begin
  SetFileExtension('.stl');
  UpdateControls( 2 );
end;

function tfrmExport.GetArea : tRect;

function GetMessage( const Dimension : string ) : string;
begin
  result := 'Please specify a valid ' + Dimension + ' value';
end;

var
  Msg : string;
  Width, Height : integer;
begin
  result.Left := StrToIntDef( edtLeft.Text, -1 );
  result.Top := StrToIntDef( edtTop.Text, -1 );
  Width :=StrToIntDef( edtWidth.Text, -1 );
  Height := StrToIntDef( edtHeight.Text, -1 );

  Msg := '';
  if result.Left < 0 then
    Msg := GetMessage( 'Left' )
  else if result.Top < 0 then
    Msg := GetMessage( 'Top' )
  else if Width < 1 then
    Msg := GetMessage( 'Width' )
  else if Height < 1 then
    Msg := GetMessage( 'Height' );

  if Msg <> '' then raise eConvertError.Create( Msg );

  result.Right := result.Left + Width - 1;
  result.Bottom := result.Top + Height - 1;
end;

function tfrmExport.GetScale : single;
begin
  result := StrToFloatDef( edtScale.Text, 0 );
  if result <= 0 then
    raise EConvertError.Create('Please specify a positive scale');
end;

procedure tfrmExport.Validate;
begin
  if GetFilename = '' then
  begin
    edtFilename.SetFocus;
    raise eRangeError.Create( 'Please specify a valid filename' );
  end;
  if grpSTLOptions.Visible then
  begin
    GetScale;
    GetArea;
  end;
end;

procedure tfrmExport.SetFileExtension( const Extension : string );
var
  Filename : string;
begin
  Filename := GetFilename;
  if Filename = '' then
    Filename := ExpandFilename( cMap.Filename );
  if Filename <> '' then
    Filename := ChangeFileExt( Filename, Extension );
  if Filename <> cMap.Filename then
    edtFilename.Text := Filename;
end;

procedure tfrmExport.UpdateControls( Tag : integer );
var
  Idx : integer;
  Control : tControl;
begin
  for Idx := 0 to ControlCount - 1 do
  begin
    Control := Controls[ Idx ];
    if Control.Tag > 0 then
      Control.Visible := Control.Tag = Tag;
  end;
end;

function tfrmExport.GetExportOptions : tExportOptions;
begin
  if btnPackedWord.Checked then result.nFormat := EXF_PACKED_WORD;
  if btnBytePerBlock.Checked then result.nFormat := EXF_BYTE_PER_BLOCK;
  if btnWordPerBlock.Checked then result.nFormat := EXF_WORD_PER_BLOCK;
  if btnSTLText.Checked then result.nFormat := EXF_STL_TEXT;
  if btnSTLBinary.Checked then result.nFormat := EXF_STL_BINARY;
  if ( result.nFormat = EXF_STL_TEXT ) or ( result.nFormat = EXF_STL_BINARY ) then
  begin
    result.StlOptions.GroundPlane := btnGroundPlane.Checked;
    result.StlOptions.Area := GetArea;
    result.StlOptions.Scale := GetScale;
  end
  else
  begin
    result.RawOptions.Title := btnTitle.Checked;
    result.RawOptions.Dimensions := btnDimension.Checked;
  end;
end;

function tfrmExport.GetFilename : string;
begin
  result := trim( edtFilename.Text );
end;

end.
