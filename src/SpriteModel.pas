unit SpriteModel;

interface

uses
  Common, Types, Geometry, Model;

type
  tSpriteModel = class;

  tSpriteGeometryGroup = class( tGeometryGroup )
  private
    pPrimitiveData : pModelPrimitive;
    pVertexData : pModelVertex;
    procedure PreparePrimitiveData;
  protected
    function  GetMaterialIndex : cardinal; override;
    function  GetPrimitiveArray : pModelPrimitive; override;
    function  GetPrimitiveCount : cardinal; override;
    function  GetVertexArray : pModelVertex; override;
  public
    constructor Create;
    destructor  Destroy; override;
  end;

  tSpriteGeometry = class( tGeometry )
  private
    fGeometryGroup : tGeometryGroup;
  protected
    function  GetGeometryGroup( Index : cardinal ) : tGeometryGroup; override;
    function  GetGeometryGroupCount : cardinal; override;
  public
    constructor Create;
    destructor  Destroy; override;
  end;

  tSpriteAnimation = class( tAnimation )
  private
    Dimension : tFloatPoint2d;
    Geometry : tSpriteGeometry;
    FrameCount : cardinal;
    FrameRate : _float;
    FrameSize : tPoint;
    SpriteModel : tSpriteModel;
  protected
    function  GetID : string; override;
    function  GetLength : _float; override;
  public
    constructor Create( SpriteModel : tSpriteModel );
    destructor  Destroy; override;
    function    GetFrameGeometry( Time : _float ) : tGeometry; override;
  end;

  tSpriteModel = class( tModel )
  private
    fAnimation : tSpriteAnimation;
    fMaterial : tMaterial;
    fTexture : tTexture;
  protected
    function  GetAnimation( Index : cardinal ) : tAnimation; override;
    function  GetAnimationCount : cardinal; override;
    function  GetMaterial( Index : cardinal ) : tMaterial; override;
    function  GetMaterialCount : cardinal; override;
    function  GetTexture( Index : cardinal ) : tTexture; override;
    function  GetTextureCount : cardinal; override;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   SetTextureFromResource( ID : cardinal );
  end;

implementation

uses
  Classes, Colour, Math, SysUtils, ModelBase, Resource;

type
  tSpriteModelBuilder = class( tModelBuilder )
  private
    function  BuildModel( SpriteDef : tStringList ) : tSpriteModel;
    function  IsSpriteStream( ModelData : tStream ) : boolean;
  public
    function  CreateModel( ModelData : tStream ) : tModel; override;
  end;

const
  SPRITE_VERTEX_ARRAY : array [ 0 .. 3 ] of tModelVertex = (
    ( Location: ( x:-1; y:-1; z:0 ); Normal: ( x:0; y:0; z:1 ) ),
    ( Location: ( x:-1; y:1;  z:0 ); Normal: ( x:0; y:0; z:1 ) ),
    ( Location: ( x:1;  y:-1;  z:0 ); Normal: ( x:0; y:0; z:1 ) ),
    ( Location: ( x:1;  y:1; z:0 ); Normal: ( x:0; y:0; z:1 ) )
  );

procedure DemandZeroIndex( Index : integer );
begin
  if Index <> 0 then
    raise eRangeError.Create( 'Index must be 0 when referencing Sprite data' );
end;

(* tSpriteModel *)

constructor tSpriteModel.Create;
begin
  inherited;
  fAnimation := tSpriteAnimation.Create( Self );
  fMaterial := tMaterialBase.Create( COLOUR_WHITE, 0, true );
end;

destructor tSpriteModel.Destroy;
begin
  fMaterial.Free;
  fTexture.Free;
  fAnimation.Free;
  inherited;
end;

function tSpriteModel.GetAnimation( Index : cardinal ) : tAnimation;
begin
  DemandZeroIndex( Index );
  result := fAnimation;
end;

function tSpriteModel.GetAnimationCount : cardinal;
begin
  result := 1;
end;

function tSpriteModel.GetMaterial( Index : cardinal ) : tMaterial;
begin
  DemandZeroIndex( Index );
  result := fMaterial;
end;

function tSpriteModel.GetMaterialCount : cardinal;
begin
  result := 1;
end;

function tSpriteModel.GetTexture( Index : cardinal ) : tTexture;
begin
  DemandZeroIndex( Index );
  result := fTexture;
end;

function tSpriteModel.GetTextureCount : cardinal;
begin
  if fTexture <> nil then
    result := 1
  else
    result := 0;
end;

procedure tSpriteModel.SetTextureFromResource( ID : cardinal );
begin
  FreeAndNil( fTexture );
  fTexture := tTextureBase.Create( GetSpriteTexture( ID ) );
end;

(* tSpriteGeometry *)

constructor tSpriteGeometry.Create;
begin
  inherited;
  fGeometryGroup := tSpriteGeometryGroup.Create;
end;

destructor tSpriteGeometry.Destroy;
begin
  fGeometryGroup.Free;
  inherited;
end;

function tSpriteGeometry.GetGeometryGroup( Index : cardinal ) : tGeometryGroup;
begin
  DemandZeroIndex( Index );
  result := fGeometryGroup;
end;

function tSpriteGeometry.GetGeometryGroupCount : cardinal;
begin
  result := 1;
end;

(* tSpriteGeometryGroup *)

constructor tSpriteGeometryGroup.Create;
begin
  inherited;
  GetMem( pVertexData, 4 * SizeOf( tModelVertex ) );
  Move( SPRITE_VERTEX_ARRAY, pVertexData^, SizeOf( SPRITE_VERTEX_ARRAY ) );
  GetMem( pPrimitiveData, SizeOf( tModelPrimitiveHeader ) + SizeOf( tModelPrimitiveVertex ) * 4 );     // 4 vertices required to describe a quad using triangle strip
  PreparePrimitiveData;
end;

destructor tSpriteGeometryGroup.Destroy;
begin
  FreeMem( pPrimitiveData );
  FreeMem( pVertexData );
  inherited;
end;

function tSpriteGeometryGroup.GetMaterialIndex : cardinal;
begin
  result := 0;
end;

function tSpriteGeometryGroup.GetPrimitiveArray : pModelPrimitive;
begin
  result := pPrimitiveData;
end;

function tSpriteGeometryGroup.GetPrimitiveCount : cardinal;
begin
  result := 1;
end;

function tSpriteGeometryGroup.GetVertexArray : pModelVertex;
begin
  result := pVertexData;
end;

procedure tSpriteGeometryGroup.PreparePrimitiveData;
var
  Idx : integer;
begin
  pPrimitiveData^.Header.Primitive := PR_TRIANGLE_STRIP;
  pPrimitiveData^.Header.VertexCount := 4;

  for Idx := 0 to 3 do
    pPrimitiveData^.Vertices[ Idx ].VertexIndex := Idx;
end;

(* tSpriteAnimation *)

constructor tSpriteAnimation.Create( SpriteModel : tSpriteModel );
begin
  inherited Create;
  Self.SpriteModel := SpriteModel;
  Geometry := tSpriteGeometry.Create;
end;

destructor tSpriteAnimation.Destroy;
begin
  Geometry.Free;
  inherited;
end;

function tSpriteAnimation.GetID : string;
begin
  result := 'BILLBOARD';
end;

function tSpriteAnimation.GetLength : _float;
begin
  result := FrameCount / FrameRate
end;

function tSpriteAnimation.GetFrameGeometry( Time : _float ) : tGeometry;

procedure PrepareVertices;
var
  Idx : integer;
  pScan : pModelVertex;
begin
  pScan := Geometry.Group[ 0 ].VertexArray;
  for Idx := 0 to 3 do
  begin
    pScan^.Location.x := Sign( pScan^.Location.x ) * Dimension.x / 2;
    pScan^.Location.y := Sign( pScan^.Location.y ) * Dimension.y / 2;
    inc( pScan );
  end;
end;

function PrepareTextureCoordinates : boolean;
var
  Frame : cardinal;
  FramesPerRow : cardinal;
  Texture : tTexture;
  x1, y1, x2, y2 : _float;
  PrimitiveData : pModelPrimitive;

procedure SetCoords( Index : integer; u, v : _float );
begin
  with PrimitiveData^.Vertices[ Index ].Texture do
  begin
    x := u / Texture.Width;
    y := v / Texture.Height;
  end;
end;

begin
  result := true;
  if SpriteModel.TextureCount = 1 then
  begin
    Texture := SpriteModel.Texture[ 0 ];

    if FrameCount > 1 then
    begin
      Frame := Trunc( Time * FrameRate );
      if Frame >= FrameCount then
      begin
        result := false;    // No longer remain on final frame but instead display nothing
        exit;
      end;
    end
    else
      Frame := 0;

    FramesPerRow := Texture.Width div cardinal( FrameSize.x );

    x1 := ( Frame mod FramesPerRow ) * cardinal( FrameSize.x ) + 0.5;
    y1 := ( Frame div FramesPerRow ) * cardinal( FrameSize.y ) + 0.5;
    x2 := x1 + cardinal( FrameSize.x ) - 0.5;
    y2 := y1 + cardinal( FrameSize.y ) - 0.5;

    PrimitiveData := Geometry.Group[ 0 ].PrimitiveArray;
    SetCoords( 0, x1, y2 );
    SetCoords( 1, x1, y1 );
    SetCoords( 2, x2, y2 );
    SetCoords( 3, x2, y1 );
  end;
end;

begin
  PrepareVertices;
  if PrepareTextureCoordinates then
    result := Geometry
  else
    result := nil;
end;

(* tSpriteModelBuilder *)

function tSpriteModelBuilder.BuildModel( SpriteDef : tStringList ) : tSpriteModel;
var
  Idx : integer;
  Key, Value : string;
  OldDecimalSeparator : char;
begin
  OldDecimalSeparator := DecimalSeparator;
  try
    DecimalSeparator := '.';                    // v1.0.3 - Fix bug that failed to convert Strings to floats when in locales that used a different decimal seperator
    result := tSpriteModel.Create;
    try
      for Idx := 0 to SpriteDef.Count - 1 do
      begin
        Key := SpriteDef.Names[ Idx ];
        if Key <> '' then
        begin
          Value := SpriteDef.Values[ Key ];
          if Key = 'object.width' then
            result.fAnimation.Dimension.x := StrToFloat( Value )
          else if Key = 'object.height' then
            result.fAnimation.Dimension.y := StrToFloat( Value )
          else if Key = 'object.x' then
            result.Translation.x := StrToFloat( Value )
          else if Key = 'object.y' then
            result.Translation.y := StrToFloat( Value )
          else if Key = 'object.z' then
            result.Translation.z := StrToFloat( Value )
          else if Key = 'texture.id' then
            result.SetTextureFromResource( StrToInt( Value ) )
          else if Key = 'frame.width' then
            result.fAnimation.FrameSize.x := StrToInt( Value )
          else if Key = 'frame.height' then
            result.fAnimation.FrameSize.y := StrToInt( Value )
          else if Key = 'frame.count' then
            result.fAnimation.FrameCount := StrToInt( Value )
          else if Key = 'frame.rate' then
            result.fAnimation.FrameRate := StrToInt( Value )
        end;
      end;
    except
      result.Free;
      raise;
    end;
  finally
    DecimalSeparator := OldDecimalSeparator;
  end;
end;

function tSpriteModelBuilder.IsSpriteStream( ModelData : tStream ) : boolean;
var
  Buffer : array [ 0 .. 6 ] of char;
begin
  result := false;
  if ModelData.Read( Buffer, SizeOf( Buffer ) ) = SizeOf( Buffer ) then
  begin
    Buffer[ High( Buffer ) ] := #0;
    result := Buffer = 'SPRITE'; 
  end;
end;

function tSpriteModelBuilder.CreateModel( ModelData : tStream ) : tModel;
var
  SpriteDef : tStringList;
begin
  result := nil;
  if IsSpriteStream( ModelData ) then
  begin
    SpriteDef := tStringList.Create;
    try
      SpriteDef.LoadFromStream( ModelData );
      result := BuildModel( SpriteDef );
    finally
      SpriteDef.Free;
    end;
  end;
end;

initialization
  tModelManager.RegisterBuilder( tSpriteModelBuilder.Create );
end.
