unit Model;

interface

uses
  Classes, Colour, Common, Geometry, SysUtils;

type
  pModelVertex = ^tModelVertex;
  tModelVertex = record
    Location : tFloatPoint3d;
    Normal : tFloatPoint3d;
  end;

  tPrimitive = ( PR_TRIANGLE, PR_TRIANGLE_STRIP, PR_TRIANGLE_FAN );

  tModelPrimitiveHeader = record
    Primitive : tPrimitive;
    VertexCount : cardinal;
  end;

  pModelPrimitiveVertex = ^tModelPrimitiveVertex;
  tModelPrimitiveVertex = record
    Texture : tFloatPoint2d;
    VertexIndex : cardinal;
  end;

  pModelPrimitive = ^tModelPrimitive;
  tModelPrimitive = record
    Header : tModelPrimitiveHeader;
    Vertices : array [ 0 .. 4095 ] of tModelPrimitiveVertex;
  end;

  tMaterial = class( tObject )
  protected
    function  GetAlwaysIlluminate : boolean; virtual; abstract;
    function  GetColour : tColour; virtual; abstract;
    function  GetTextureIndex : integer; virtual; abstract;
  public
    property  AlwaysIlluminate : boolean read GetAlwaysIlluminate;
    property  Colour : tColour read GetColour;
    property  TextureIndex : integer read GetTextureIndex;
  end;

  tGeometryGroup = class( tObject )
  protected
    function  GetMaterialIndex : cardinal; virtual; abstract;
    function  GetPrimitiveArray : pModelPrimitive; virtual; abstract;
    function  GetPrimitiveCount : cardinal; virtual; abstract;
    function  GetVertexArray : pModelVertex; virtual; abstract;
  public
    property  MaterialIndex : cardinal read GetMaterialIndex;
    property  PrimitiveArray : pModelPrimitive read GetPrimitiveArray;
    property  PrimitiveCount : cardinal read GetPrimitiveCount;
    property  VertexArray : pModelVertex read GetVertexArray;
  end;

  tGeometry = class( tObject )
  protected
    function  GetGeometryGroup( Index : cardinal ) : tGeometryGroup; virtual; abstract;
    function  GetGeometryGroupCount : cardinal; virtual; abstract;
  public
    property  Group[ Index : cardinal ] : tGeometryGroup read GetGeometryGroup;
    property  GroupCount : cardinal read GetGeometryGroupCount;
  end;

  tAnimation = class( tObject )
  protected
    function  GetGroupID : string; virtual;
    function  GetID : string; virtual; abstract;
    function  GetLength : _float; virtual; abstract;
  public
    function  GetFrameGeometry( Time : _float ) : tGeometry; virtual; abstract;
    property  GroupID : string read GetGroupID;
    property  ID : string read GetID;
    property  Length : _float read GetLength;
  end;

  tTexture = class( tObject )
  private
    fInternalID : integer;
  protected
    function  GetBitsPerPixel : cardinal; virtual; abstract;
    function  GetData : pointer; virtual; abstract;
    function  GetHeight : cardinal; virtual; abstract;
    function  GetWidth : cardinal; virtual; abstract;
  public
    procedure ReleaseData; virtual; abstract;
    property  InternalID : integer read fInternalID write fInternalID;
    property  BitsPerPixel : cardinal read GetBitsPerPixel;
    property  Data : pointer read GetData;
    property  Height : cardinal read GetHeight;
    property  Width : cardinal read GetWidth;
  end;

  tModel = class( tObject )
  private
    fDefaultFPS : _float;
    fOrientation : tAxis;
    fOrientationMatrix : array [ 0 .. 15 ] of _float;
    fRebuildMatrix : boolean;
    fScale : tPoint3d;
    fTranslation : tPoint3d;
    procedure BuildOrientationMatrix;
  protected
    constructor Create;
    function  GetAnimation( Index : cardinal ) : tAnimation; virtual; abstract;
    function  GetAnimationCount : cardinal; virtual; abstract;
    function  GetMaterial( Index : cardinal ) : tMaterial; virtual; abstract;
    function  GetMaterialCount : cardinal; virtual; abstract;
    function  GetOrientation : tAxis; virtual;
    function  GetOrientationMatrix : pFloat; virtual;
    function  GetTexture( Index : cardinal ) : tTexture; virtual; abstract;
    function  GetTextureCount : cardinal; virtual; abstract;
  public
    destructor Destroy; override;
    property  Animation[ Index : cardinal ] : tAnimation read GetAnimation;
    property  AnimationCount : cardinal read GetAnimationCount;
    property  DefaultFPS : _float read fDefaultFPS write fDefaultFPS;
    property  Material[ Index : cardinal ] : tMaterial read GetMaterial;
    property  MaterialCount : cardinal read GetMaterialCount;
    property  Orientation : tAxis read GetOrientation;
    property  OrientationMatrix : pFloat read GetOrientationMatrix;
    property  Scale : tPoint3d read fScale;
    property  Texture[ Index : cardinal ] : tTexture read GetTexture;
    property  TextureCount : cardinal read GetTextureCount;
    property  Translation : tPoint3d read fTranslation;
  end;

  tModelBuilder = class( tObject )
  public
    function  CreateModel( ModelData : tStream ) : tModel; virtual; abstract;
  end;

  tModelManager = class( tModelBuilder )
  public
    function  CreateModel( ModelData : tStream ) : tModel; override;
    class procedure RegisterBuilder( Builder : tModelBuilder );
  end;

  eCreateModelException = class( Exception );

implementation

uses
  glGeometry;

var
  ModelBuilderList : tObjectList;

(* tAnimation *)

function tAnimation.GetGroupID : string;
begin
  result := ID;
end;

(* tModel *)

constructor tModel.Create;
begin
  inherited;
  fRebuildMatrix := true;
  fOrientation := tAxis.Create;
  fScale := tPoint3d.Create( 1, 1, 1 );
  fTranslation := tPoint3d.Create;
end;

destructor tModel.Destroy;
begin
  fTranslation.Free;
  fScale.Free;
  fOrientation.Free;
  inherited;
end;

procedure tModel.BuildOrientationMatrix;
begin
  glgGetAxis( Orientation, fOrientationMatrix, false );
  fRebuildMatrix := false;
end;

function tModel.GetOrientation : tAxis;
begin
  fRebuildMatrix := true;
  result := fOrientation;
end;

function tModel.GetOrientationMatrix : pFloat;
begin
  if fRebuildMatrix then
    BuildOrientationMatrix;
  result := @fOrientationMatrix;
end;

(* tModelManager *)

class procedure tModelManager.RegisterBuilder( Builder : tModelBuilder );
begin
  ModelBuilderList.Add( Builder );
end;

function tModelManager.CreateModel( ModelData : tStream ) : tModel;
var
  Idx : integer;
  Start : Int64;
begin
  result := nil;
  Start := ModelData.Position;
  for Idx := 0 to ModelBuilderList.Count - 1 do
  begin
    ModelData.Seek( Start, soFromBeginning );
    result := tModelBuilder( ModelBuilderList[ Idx ] ).CreateModel( ModelData );
    if result <> nil then
      break;
  end;
end;

initialization
  ModelBuilderList := tObjectList.Create;
finalization
  ModelBuilderList.Free;
end.
