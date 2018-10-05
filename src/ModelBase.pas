unit ModelBase;

interface

uses
  Graphics, Colour, Common, Model;

type
  tTextureBase = class ( tTexture )
  private
    fBitsPerPixel : cardinal;
    fData : pointer;
    fWidth : cardinal;
    fHeight : cardinal;
    FreeDataOnDestroy : boolean;
    function  DecodeBitmap( Bitmap : tBitmap ) : pointer;
    function  DecodeTarga( TargaImage : pointer ) : pointer;
  protected
    function  GetBitsPerPixel : cardinal; override;
    function  GetData : pointer; override;
    function  GetHeight : cardinal; override;
    function  GetWidth : cardinal; override;
  public
    constructor Create( BitsPerPixel : cardinal; Data : pointer; Width, Height : cardinal; FreeDataOnDestroy : boolean ); overload;
    constructor Create( Bitmap : tBitmap ); overload;
    constructor Create( TargaImage : pointer ); overload;
    destructor  Destroy; override;
    procedure   ReleaseData; override;
  end;

  tMaterialBase = class( tMaterial )
  private
    fAlwaysIlluminate : boolean;
    fColour : tColour;
    fTextureIndex : integer;
  protected
    function    GetAlwaysIlluminate : boolean; override;
    function    GetColour : tColour; override;
    function    GetTextureIndex : integer; override;
  public
    constructor Create( Colour : tColour; TextureIndex : integer; AlwaysIlluminate : boolean = false );
  end;

  tModelBase = class( tModel )
  private
    fAnimationList : tObjectList;
    fMaterialList : tObjectList;
    fTextureList : tObjectList;
  protected
    constructor Create;
    function    GetAnimation( Index : cardinal ) : tAnimation; override;
    function    GetAnimationCount : cardinal; override;
    function    GetMaterial( Index : cardinal ) : tMaterial; override;
    function    GetMaterialCount : cardinal; override;
    function    GetTexture( Index : cardinal ) : tTexture; override;
    function    GetTextureCount : cardinal; override;
    property    AnimationList : tObjectList read fAnimationList;
    property    MaterialList : tObjectList read fMaterialList;
    property    TextureList : tObjectList read fTextureList;
  public
    destructor  Destroy; override;
  end;

implementation

(* tTextureBase *)

constructor tTextureBase.Create( BitsPerPixel : cardinal; Data : pointer; Width, Height : cardinal; FreeDataOnDestroy : boolean );
begin
  inherited Create;
  fBitsPerPixel := BitsPerPixel;
  fData := Data;
  fWidth := Width;
  fHeight := Height;
  Self.FreeDataOnDestroy := FreeDataOnDestroy;
end;

constructor tTextureBase.Create( Bitmap : tBitmap );
begin
  inherited Create;
  fBitsPerPixel := 24;
  fWidth := Bitmap.Width;
  fHeight := Bitmap.Height;
  fData := DecodeBitmap( Bitmap );
  FreeDataOnDestroy := true;
end;

constructor tTextureBase.Create( TargaImage : pointer );
begin
  inherited Create;
  fData := DecodeTarga( TargaImage );
  FreeDataOnDestroy := true;
end;

destructor tTextureBase.Destroy;
begin
  if FreeDataOnDestroy and ( Data <> nil ) then
    FreeMem( Data );
  inherited;
end;

function tTextureBase.DecodeBitmap( Bitmap : tBitmap ) : pointer;
var
  x, y : integer;
  Size : cardinal;
  Scan : pByte;
  Colour : tColour;
begin
  Size := Bitmap.Width * Bitmap.Height * 3;
  GetMem( result, Size );
  try
    Scan := result;
    for y := 0 to Bitmap.Height - 1 do
      for x := 0 to Bitmap.Width - 1 do
      begin
        Colour.rgba := Bitmap.Canvas.Pixels[ x, y ];
        Scan^ := Colour.r;
        inc( Scan );
        Scan^ := Colour.g;
        inc( Scan );
        Scan^ := Colour.b;
        inc( Scan );
      end;
  except
    FreeMem( result );
    raise;
  end;
end;

function tTextureBase.DecodeTarga( TargaImage : pointer ) : pointer;
type
  pTargaHeader = ^tTargaHeader;
  tTargaHeader = packed record
    ImageIDLength : byte;
    ColourMapType : byte;
    ImageType     : byte;
    ColourMapBase : word;
    ColourMapSize : word;
    ColourMapBits : byte;
    XOrigin       : word;
    YOrigin       : word;
    Width         : word;
    Height        : word;
    BitsPerPixel  : byte;
    Flags         : byte;
  end;
var
  Header : pTargaHeader;
  ImageData, OutputData : pByte;
  Size : cardinal;
  Strip : cardinal;
  PixelCount : cardinal;
  PixelSize : cardinal;
  Pixel : cardinal;
  y : integer;
  pR, pB : pByte;
  Temp : byte;
begin
  Header := TargaImage;
  PixelSize := Header^.BitsPerPixel div 8;
  PixelCount := Header^.Width * Header^.Height;
  Size := PixelCount * PixelSize;
  Strip := Header^.Width * PixelSize;
  if ( Header^.ColourMapType = 0 ) and ( Header^.ImageType = 2 ) then     // True-colour uncompressed
  begin
    fWidth := Header^.Width;
    fHeight := Header^.Height;
    fBitsPerPixel := Header^.BitsPerPixel;
    GetMem( result, Size );
    try
      ImageData := pointer( Header );
      inc( ImageData, SizeOf( tTargaHeader ) );
      inc( ImageData, Header^.ImageIDLength );
      inc( ImageData, Size );
      OutputData := pointer( result );
      for y := 1 to Header^.Height do
      begin
        dec( ImageData, Strip );
        Move( ImageData^, OutputData^, Strip );
        inc( OutputData, Strip );
      end;

      // Swap round the Red and Blue components
      pR := result;
      pB := pR;
      inc( pB, 2 );
      for Pixel := PixelCount downto 1 do
      begin
        Temp := pR^;
        pR^ := pB^;
        pB^ := Temp;
        inc( pR, PixelSize );
        inc( pB, PixelSize );
      end;

    except
      FreeMem( result );
      raise;
    end;
  end
  else
    raise eCreateModelException.Create( 'Unsupported Targa Image' );
end;

function tTextureBase.GetBitsPerPixel : cardinal;
begin
  result := fBitsPerPixel;
end;

function tTextureBase.GetData : pointer;
begin
  result := fData;
end;

function tTextureBase.GetHeight : cardinal;
begin
  result := fHeight;
end;

function tTextureBase.GetWidth : cardinal;
begin
  result := fWidth;
end;

procedure tTextureBase.ReleaseData;
begin
  if fData <> nil then
  begin
    FreeMem( fData );
    fData := nil;
  end;
end;

(* tMaterialBase *)

constructor tMaterialBase.Create( Colour : tColour; TextureIndex : integer; AlwaysIlluminate : boolean );
begin
  inherited Create;
  fColour := Colour;
  fTextureIndex := TextureIndex;
  fAlwaysIlluminate := AlwaysIlluminate;
end;

function tMaterialBase.GetAlwaysIlluminate : boolean;
begin
  result := fAlwaysIlluminate;
end;

function tMaterialBase.GetColour : tColour;
begin
  result := fColour;
end;

function tMaterialBase.GetTextureIndex : integer;
begin
  result := fTextureIndex;
end;

(* tModelBase *)

constructor tModelBase.Create;
begin
  inherited;
  fAnimationList := tObjectList.Create;
  fMaterialList := tObjectList.Create;
  fTextureList := tObjectList.Create;
end;

function tModelBase.GetAnimation( Index : cardinal ) : tAnimation;
begin
  result := tAnimation( AnimationList[ Index ] );
end;

function tModelBase.GetAnimationCount : cardinal;
begin
  result := AnimationList.Count;
end;

function tModelBase.GetMaterial( Index : cardinal ) : tMaterial;
begin
  result := tMaterial( MaterialList[ Index ] );
end;

function tModelBase.GetMaterialCount : cardinal;
begin
  result := MaterialList.Count;
end;

function tModelBase.GetTexture( Index : cardinal ) : tTexture;
begin
  result := tTexture( TextureList[ Index ] );
end;

function tModelBase.GetTextureCount : cardinal;
begin
  result := TextureList.Count;
end;

destructor tModelBase.Destroy;
begin
  fAnimationList.Free;
  fMaterialList.Free;
  fTextureList.Free;
  inherited;
end;

end.
