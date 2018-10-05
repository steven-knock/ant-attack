unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, Renderer, Buttons;

type
  TfrmConfig = class(TForm)
    cmbColourDepth: TComboBox;
    cmbZBufferDepth: TComboBox;
    cmbPerPixelFog: TComboBox;
    cmbFullScreen: TComboBox;
    edtWidth: TEdit;
    spnWidth: TUpDown;
    edtHeight: TEdit;
    spnHeight: TUpDown;
    imgBackground: TImage;
    btnWidthDefault: TSpeedButton;
    btnHeightDefault: TSpeedButton;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    tmrLaunch: TTimer;
    cmbInvertMouse: TComboBox;
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnUpdate( Sender : tObject );
    procedure edtExit( Sender : tObject );
    procedure spnClick(Sender: TObject; Button: TUDBtnType);
    procedure tmrLaunchTimer(Sender: TObject);
  private
    Config : tRendererConfiguration;
    ScreenSize : tPoint;
    WindowedSize : tPoint;
    DefaultResolution : tPoint;
    Updating : boolean;
    procedure   PopulateControls;
    procedure   UpdateDimensions;
  public
    constructor Create( Owner : tComponent ); override;
    destructor  Destroy; override;
  end;

var
  frmConfig: TfrmConfig;

implementation

{$R *.dfm}

uses
  Common, Resource;

const
  MIN_SIZE = 256;

constructor tfrmConfig.Create( Owner : tComponent );
var
  Background : tBitmap;
begin
  inherited;
  Background := tBitmap.Create;
  try
    Background.LoadFromResourceID( hResourceInstance, RES_BACKGROUND_BASE );
    imgBackground.Picture.Assign( Background );
  finally
    Background.Free;
  end;
  ScreenSize := Point( Screen.Width, Screen.Height );
  WindowedSize := Point( ScreenSize.x div 2, ScreenSize.y div 2 );
  spnWidth.Max := ScreenSize.x;
  spnHeight.Max := ScreenSize.y;
  Config := tRendererConfiguration.Create;
  PopulateControls;
end;

destructor tfrmConfig.Destroy;
begin
  Config.Free;
  inherited;
end;

procedure tfrmConfig.PopulateControls;

procedure InitialiseItem( Combo : tComboBox; Value : integer );
var
  Idx : integer;
begin
  Idx := Combo.Items.IndexOf( IntToStr( Value ) );
  if Idx < 0 then
    Idx := 1;
  Combo.ItemIndex := Idx;
end;

begin
  with Config do
  begin
    cmbFullScreen.ItemIndex := Ord( FullScreen );
    if Width >= MIN_SIZE then
    begin
      spnWidth.Position := Width;
      btnWidthDefault.Down := true;
    end;
    if Height >= MIN_SIZE then
    begin
      spnHeight.Position := Height;
      btnHeightDefault.Down := true;
    end;
    InitialiseItem( cmbColourDepth, ColourDepth );
    InitialiseItem( cmbZBufferDepth, ZBufferDepth );
    cmbPerPixelFog.ItemIndex := PerPixelFog + 1;
    if cmbPerPixelFog.ItemIndex < 0 then
      cmbPerPixelFog.ItemIndex := 0;
    cmbInvertMouse.ItemIndex := Ord( InvertMouse );
  end;
  UpdateDimensions;
end;

procedure tfrmConfig.UpdateDimensions;
begin
  if Updating then
    exit;

  Updating := true;
  try
    if cmbFullScreen.ItemIndex = 0 then
      DefaultResolution := WindowedSize
    else
      DefaultResolution := ScreenSize;

    if not btnWidthDefault.Down then
    begin
      spnWidth.Position := 0;     // Force Update
      spnWidth.Position := DefaultResolution.x;
    end;
    spnWidth.Enabled := btnWidthDefault.Down;
    edtWidth.Enabled := btnWidthDefault.Down;

    if not btnHeightDefault.Down then
    begin
      spnHeight.Position := 0;    // Force Update
      spnHeight.Position := spnWidth.Position * ScreenSize.y div ScreenSize.x;
    end;
    spnHeight.Enabled := btnHeightDefault.Down;
    edtHeight.Enabled := btnHeightDefault.Down;
  finally
    Updating := false;
  end;
end;

procedure TfrmConfig.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmConfig.btnOKClick(Sender: TObject);

function GetDimension( DefaultButton : tSpeedButton; Spin : tUpDown ) : integer;
begin
  if DefaultButton.Down then
    result := Spin.Position
  else
    result := 0;
end;

begin
  with Config do
  begin
    FullScreen := cmbFullScreen.ItemIndex <> 0;
    Width := GetDimension( btnWidthDefault, spnWidth );
    Height := GetDimension( btnHeightDefault, spnHeight );
    PerPixelFog := cmbPerPixelFog.ItemIndex - 1;
    ColourDepth := 16 + cmbColourDepth.ItemIndex * 8;
    ZBufferDepth := 16 + cmbZBufferDepth.ItemIndex * 8;
    InvertMouse := cmbInvertMouse.ItemIndex <> 0;
    Save;
  end;
  Hide;
  tmrLaunch.Enabled := true;
end;

procedure tfrmConfig.btnUpdate( Sender : tObject );
begin
  UpdateDimensions;
end;

procedure tfrmConfig.edtExit( Sender : tObject );
var
  PreviousPosition : integer;
  Spin : tUpDown;
begin
  if Sender = edtWidth then
    Spin := spnWidth
  else
    Spin := spnHeight;
  PreviousPosition := Spin.Position;
  Spin.Position := 0;
  Spin.Position := PreviousPosition;
end;

procedure TfrmConfig.spnClick(Sender: TObject; Button: TUDBtnType);
begin
  UpdateDimensions;
end;

procedure TfrmConfig.tmrLaunchTimer(Sender: TObject);
var
  Filename : string;
begin
  tmrLaunch.Enabled := false;
  Filename := ExtractFilePath( Application.ExeName ) + FILE_ANT_ATTACK;
  if WinExec( pChar( Filename ), SW_SHOW ) <= 31 then
    MessageDlg( 'Unable to launch ' + Filename, mtInformation, [ mbOk ], 0 );
  Close;
end;

end.
