unit MD2Model;

interface

uses
  Graphics, Types, Common, Geometry, Model, ModelBase;

type
  tMD2Model = class( tModelBase )
  private
    fFrameList : tObjectList;
    fGeometry : tGeometry;
    fTextureSize : tPoint;
    fVertexCount : cardinal;
    property    FrameList : tObjectList read fFrameList;
  protected
    property    TextureSize : tPoint read fTextureSize;
    property    VertexCount : cardinal read fVertexCount;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   AddResourceTexture( ID : cardinal ); overload;
    procedure   AddResourceTexture( const Name : string ); overload;
    procedure   AddTexture( Skin : tBitmap );
    function    DefineAnimation( StartFrame, EndFrame : cardinal; GroupID : cardinal = 0; Wrap : boolean = false; FPS : _float = 0 ) : tAnimation;
  end;

implementation

uses
  Classes, SysUtils, Colour, Resource;

type
  (* Private Classes *)

  tMD2Frame = class( tObject )
  private
    pVertexData : pFloatPoint3d;
  public
    constructor Create( pVertexData : pFloatPoint3d );
    destructor  Destroy; override;
  end;

  tMD2Animation = class( tAnimation )
  private
    fGroupID : cardinal;
    fID : cardinal;
    fModel : tMD2Model;
    fStartFrame : cardinal;
    fEndFrame : cardinal;
    fWrap : boolean;
    fFPS : _float;
  protected
    function    GetFrameCount : cardinal;
    function    GetGroupID : string; override;
    function    GetID : string; override;
    function    GetLength : _float; override;
    property    Model : tMD2Model read fModel;
  public
    constructor Create( Model : tMD2Model; ID, StartFrame, EndFrame, GroupID : cardinal; Wrap : boolean; FPS : _float );
    function    GetFrameGeometry( Time : _float ) : tGeometry; override;
    property    StartFrame : cardinal read fStartFrame;
    property    EndFrame : cardinal read fEndFrame;
    property    Wrap : boolean read fWrap;
    property    FPS : _float read fFPS;
  end;

  tMD2GeometryGroup = class( tGeometryGroup )
  private
    fPrimitiveCount : cardinal;
    fPrimitiveBuffer : pointer;
    fGeometryBuffer : pointer;
  protected
    function  GetMaterialIndex : cardinal; override;
    function  GetPrimitiveArray : pModelPrimitive; override;
    function  GetPrimitiveCount : cardinal; override;
    function  GetVertexArray : pModelVertex; override;
  public
    constructor Create( PrimitiveCount : cardinal; PrimitiveBuffer, GeometryBuffer : pointer );
    destructor  Destroy; override;
  end;

  tMD2Geometry = class( tGeometry )
  private
    fGeometryGroup : tMD2GeometryGroup;
  protected
    function  GetGeometryGroup( Index : cardinal ) : tGeometryGroup; override;
    function  GetGeometryGroupCount : cardinal; override;
  public
    constructor Create( GeometryGroup : tMD2GeometryGroup );
    destructor  Destroy; override;
  end;

  tMD2ModelBuilder = class( tModelBuilder )
  private
    procedure LoadFrames( Model : tMD2Model; FrameCount : cardinal; Data : pointer );
    procedure LoadGeometry( Model : tMD2Model; Data : pointer );
    procedure LoadTextures( Model : tMD2Model; Count : cardinal; Data : pointer );
  public
    function  CreateModel( ModelData : tStream ) : tModel; override;
  end;

  (* MD2 File Format Structures *)

  pMD2Header = ^tMD2Header;
  tMD2Header = record
    Magic : cardinal;
    Version : cardinal;
    SkinSize : tPoint;
    FrameSize : cardinal;
    SkinCount : cardinal;
    VertexCount : cardinal;
    UVCount : cardinal;
    TriangleCount : cardinal;
    GLCmdCount : cardinal;
    FrameCount : cardinal;
    SkinOffset : cardinal;
    UVOffset : cardinal;
    TriangleOffset : cardinal;
    FrameOffset : cardinal;
    GLCmdOffset : cardinal;
    EndOffset : cardinal;
  end;

  pMD2Skin = ^tMD2Skin;
  tMD2Skin = array [ 0 .. 63 ] of char;

  pMD2Vertex = ^tMD2Vertex;
  tMD2Vertex = record
    v : array [ 0 .. 2 ] of byte;
    NormalIndex : byte;
  end;

  pMD2GLPacket = ^tMD2GLPacket;
  tMD2GLPacket = record
    u, v : _float;
    VIdx : integer;
  end;

  pMD2FrameHeader = ^tMD2FrameHeader;
  tMD2FrameHeader = record
    Scale : tFloatPoint3d;
    Translate : tFloatPoint3d;
    Name : array [ 0 .. 15 ] of char;
  end;

const
  MD2_MAGIC = 844121161;
  MD2_VERSION = 8;
  MD2_FPS = 10;

  NormalTable : array [ 0 .. 161, 0 .. 2 ] of _float = (
    ( -0.525731,  0.000000,  0.850651 ),
    ( -0.442863,  0.238856,  0.864188 ),
    ( -0.295242,  0.000000,  0.955423 ),
    ( -0.309017,  0.500000,  0.809017 ),
    ( -0.162460,  0.262866,  0.951056 ),
    (  0.000000,  0.000000,  1.000000 ),
    (  0.000000,  0.850651,  0.525731 ),
    ( -0.147621,  0.716567,  0.681718 ),
    (  0.147621,  0.716567,  0.681718 ),
    (  0.000000,  0.525731,  0.850651 ),
    (  0.309017,  0.500000,  0.809017 ),
    (  0.525731,  0.000000,  0.850651 ),
    (  0.295242,  0.000000,  0.955423 ),
    (  0.442863,  0.238856,  0.864188 ),
    (  0.162460,  0.262866,  0.951056 ),
    ( -0.681718,  0.147621,  0.716567 ),
    ( -0.809017,  0.309017,  0.500000 ),
    ( -0.587785,  0.425325,  0.688191 ),
    ( -0.850651,  0.525731,  0.000000 ),
    ( -0.864188,  0.442863,  0.238856 ),
    ( -0.716567,  0.681718,  0.147621 ),
    ( -0.688191,  0.587785,  0.425325 ),
    ( -0.500000,  0.809017,  0.309017 ),
    ( -0.238856,  0.864188,  0.442863 ),
    ( -0.425325,  0.688191,  0.587785 ), 
    ( -0.716567,  0.681718, -0.147621 ), 
    ( -0.500000,  0.809017, -0.309017 ), 
    ( -0.525731,  0.850651,  0.000000 ), 
    (  0.000000,  0.850651, -0.525731 ), 
    ( -0.238856,  0.864188, -0.442863 ), 
    (  0.000000,  0.955423, -0.295242 ), 
    ( -0.262866,  0.951056, -0.162460 ),
    (  0.000000,  1.000000,  0.000000 ), 
    (  0.000000,  0.955423,  0.295242 ), 
    ( -0.262866,  0.951056,  0.162460 ),
    (  0.238856,  0.864188,  0.442863 ),
    (  0.262866,  0.951056,  0.162460 ), 
    (  0.500000,  0.809017,  0.309017 ),
    (  0.238856,  0.864188, -0.442863 ), 
    (  0.262866,  0.951056, -0.162460 ),
    (  0.500000,  0.809017, -0.309017 ), 
    (  0.850651,  0.525731,  0.000000 ),
    (  0.716567,  0.681718,  0.147621 ), 
    (  0.716567,  0.681718, -0.147621 ),
    (  0.525731,  0.850651,  0.000000 ), 
    (  0.425325,  0.688191,  0.587785 ),
    (  0.864188,  0.442863,  0.238856 ), 
    (  0.688191,  0.587785,  0.425325 ),
    (  0.809017,  0.309017,  0.500000 ), 
    (  0.681718,  0.147621,  0.716567 ),
    (  0.587785,  0.425325,  0.688191 ), 
    (  0.955423,  0.295242,  0.000000 ), 
    (  1.000000,  0.000000,  0.000000 ), 
    (  0.951056,  0.162460,  0.262866 ), 
    (  0.850651, -0.525731,  0.000000 ), 
    (  0.955423, -0.295242,  0.000000 ), 
    (  0.864188, -0.442863,  0.238856 ), 
    (  0.951056, -0.162460,  0.262866 ), 
    (  0.809017, -0.309017,  0.500000 ), 
    (  0.681718, -0.147621,  0.716567 ),
    (  0.850651,  0.000000,  0.525731 ),
    (  0.864188,  0.442863, -0.238856 ), 
    (  0.809017,  0.309017, -0.500000 ), 
    (  0.951056,  0.162460, -0.262866 ), 
    (  0.525731,  0.000000, -0.850651 ),
    (  0.681718,  0.147621, -0.716567 ),
    (  0.681718, -0.147621, -0.716567 ), 
    (  0.850651,  0.000000, -0.525731 ), 
    (  0.809017, -0.309017, -0.500000 ),
    (  0.864188, -0.442863, -0.238856 ),
    (  0.951056, -0.162460, -0.262866 ), 
    (  0.147621,  0.716567, -0.681718 ), 
    (  0.309017,  0.500000, -0.809017 ), 
    (  0.425325,  0.688191, -0.587785 ),
    (  0.442863,  0.238856, -0.864188 ), 
    (  0.587785,  0.425325, -0.688191 ), 
    (  0.688191,  0.587785, -0.425325 ), 
    ( -0.147621,  0.716567, -0.681718 ),
    ( -0.309017,  0.500000, -0.809017 ),
    (  0.000000,  0.525731, -0.850651 ), 
    ( -0.525731,  0.000000, -0.850651 ), 
    ( -0.442863,  0.238856, -0.864188 ),
    ( -0.295242,  0.000000, -0.955423 ), 
    ( -0.162460,  0.262866, -0.951056 ), 
    (  0.000000,  0.000000, -1.000000 ),
    (  0.295242,  0.000000, -0.955423 ),
    (  0.162460,  0.262866, -0.951056 ), 
    ( -0.442863, -0.238856, -0.864188 ),
    ( -0.309017, -0.500000, -0.809017 ),
    ( -0.162460, -0.262866, -0.951056 ),
    (  0.000000, -0.850651, -0.525731 ), 
    ( -0.147621, -0.716567, -0.681718 ),
    (  0.147621, -0.716567, -0.681718 ), 
    (  0.000000, -0.525731, -0.850651 ), 
    (  0.309017, -0.500000, -0.809017 ),
    (  0.442863, -0.238856, -0.864188 ), 
    (  0.162460, -0.262866, -0.951056 ), 
    (  0.238856, -0.864188, -0.442863 ), 
    (  0.500000, -0.809017, -0.309017 ), 
    (  0.425325, -0.688191, -0.587785 ), 
    (  0.716567, -0.681718, -0.147621 ), 
    (  0.688191, -0.587785, -0.425325 ), 
    (  0.587785, -0.425325, -0.688191 ),
    (  0.000000, -0.955423, -0.295242 ), 
    (  0.000000, -1.000000,  0.000000 ), 
    (  0.262866, -0.951056, -0.162460 ), 
    (  0.000000, -0.850651,  0.525731 ),
    (  0.000000, -0.955423,  0.295242 ),
    (  0.238856, -0.864188,  0.442863 ), 
    (  0.262866, -0.951056,  0.162460 ), 
    (  0.500000, -0.809017,  0.309017 ), 
    (  0.716567, -0.681718,  0.147621 ),
    (  0.525731, -0.850651,  0.000000 ), 
    ( -0.238856, -0.864188, -0.442863 ), 
    ( -0.500000, -0.809017, -0.309017 ), 
    ( -0.262866, -0.951056, -0.162460 ),
    ( -0.850651, -0.525731,  0.000000 ),
    ( -0.716567, -0.681718, -0.147621 ), 
    ( -0.716567, -0.681718,  0.147621 ), 
    ( -0.525731, -0.850651,  0.000000 ), 
    ( -0.500000, -0.809017,  0.309017 ),
    ( -0.238856, -0.864188,  0.442863 ),
    ( -0.262866, -0.951056,  0.162460 ), 
    ( -0.864188, -0.442863,  0.238856 ),
    ( -0.809017, -0.309017,  0.500000 ), 
    ( -0.688191, -0.587785,  0.425325 ), 
    ( -0.681718, -0.147621,  0.716567 ), 
    ( -0.442863, -0.238856,  0.864188 ),
    ( -0.587785, -0.425325,  0.688191 ), 
    ( -0.309017, -0.500000,  0.809017 ),
    ( -0.147621, -0.716567,  0.681718 ), 
    ( -0.425325, -0.688191,  0.587785 ),
    ( -0.162460, -0.262866,  0.951056 ), 
    (  0.442863, -0.238856,  0.864188 ),
    (  0.162460, -0.262866,  0.951056 ), 
    (  0.309017, -0.500000,  0.809017 ),
    (  0.147621, -0.716567,  0.681718 ), 
    (  0.000000, -0.525731,  0.850651 ), 
    (  0.425325, -0.688191,  0.587785 ), 
    (  0.587785, -0.425325,  0.688191 ), 
    (  0.688191, -0.587785,  0.425325 ), 
    ( -0.955423,  0.295242,  0.000000 ),
    ( -0.951056,  0.162460,  0.262866 ),
    ( -1.000000,  0.000000,  0.000000 ),
    ( -0.850651,  0.000000,  0.525731 ),
    ( -0.955423, -0.295242,  0.000000 ),
    ( -0.951056, -0.162460,  0.262866 ),
    ( -0.864188,  0.442863, -0.238856 ),
    ( -0.951056,  0.162460, -0.262866 ),
    ( -0.809017,  0.309017, -0.500000 ),
    ( -0.864188, -0.442863, -0.238856 ),
    ( -0.951056, -0.162460, -0.262866 ),
    ( -0.809017, -0.309017, -0.500000 ),
    ( -0.681718,  0.147621, -0.716567 ),
    ( -0.681718, -0.147621, -0.716567 ),
    ( -0.850651,  0.000000, -0.525731 ),
    ( -0.688191,  0.587785, -0.425325 ),
    ( -0.587785,  0.425325, -0.688191 ),
    ( -0.425325,  0.688191, -0.587785 ),
    ( -0.425325, -0.688191, -0.587785 ),
    ( -0.587785, -0.425325, -0.688191 ),
    ( -0.688191, -0.587785, -0.425325 )
  );

(* tMD2Frame *)

constructor tMD2Frame.Create( pVertexData : pFloatPoint3d );
begin
  inherited Create;
  Self.pVertexData := pVertexData;
end;

destructor  tMD2Frame.Destroy;
begin
  FreeMem( pVertexData );
  inherited;
end;

(* tMD2Animation *)

constructor tMD2Animation.Create( Model : tMD2Model; ID, StartFrame, EndFrame, GroupID : cardinal; Wrap : boolean; FPS : _float );
begin
  inherited Create;
  fModel := Model;
  fID := ID;
  fGroupID := GroupID;
  fStartFrame := StartFrame;
  fEndFrame := EndFrame;
  fWrap := Wrap;
  fFPS := FPS;
end;

function tMD2Animation.GetFrameCount : cardinal;
begin
  result := Abs( fEndFrame - fStartFrame ) + 1;
end;

function tMD2Animation.GetGroupID : string;
begin
  result := IntToStr( fGroupID );
end;

function tMD2Animation.GetID : string;
begin
  result := IntToStr( fID );
end;

function tMD2Animation.GetLength : _float;
var
  Count : cardinal;
begin
  Count := GetFrameCount;
  if not Wrap then
    dec( Count );
  result := Count / FPS;
end;

function tMD2Animation.GetFrameGeometry( Time : _float ) : tGeometry;
const
  EPSILON = 0.0001;
var
  Idx : cardinal;
  Len : _float;
  Frame, Bias : _float;
  SF, F1, F2 : integer;
  GeometryGroup : tMD2GeometryGroup;
  pGeometry, pF1, pF2 : ^_float;
begin
  Len := Length;
  if Len > 0 then
  begin
    if Time > Len then
      if Wrap then
        Time := Time - ( Len * Trunc( Time / Len ) )    // Cause Time to wrap around
      else
        Time := Len - ( 1 / FPS );
  end
  else
    Time := 0;

  Frame := Time * FPS;
  SF := StartFrame;
  F1 := Trunc( Frame );
  F2 := cardinal( F1 + 1 ) mod GetFrameCount;
  Bias := Frac( Frame );
  if Integer( EndFrame - StartFrame ) < 0 then
  begin
    F1 := -F1;
    F2 := -F2;
  end;

  pF1 := pointer( tMD2Frame( Model.FrameList[ SF + F1 ] ).pVertexData );
  pF2 := pointer( tMD2Frame( Model.FrameList[ SF + F2 ] ).pVertexData );

  result := Model.fGeometry;
  GeometryGroup := tMD2GeometryGroup( result.Group[ 0 ] );
  pGeometry := GeometryGroup.fGeometryBuffer;

  if Bias > EPSILON then
  begin
    for Idx := 1 to Model.VertexCount * 6 do
    begin
      pGeometry^ := pF1^ + ( Bias * ( pF2^ - pF1^ ) );      // Interpolate the location and the normal
      inc( pF1 );
      inc( pF2 );
      inc( pGeometry );
    end;
  end
  else
    for Idx := 1 to Model.VertexCount * 6 do
    begin
      pGeometry^ := pF1^;
      inc( pF1 );
      inc( pGeometry );
    end;
end;

(* tMD2GeometryGroup *)

constructor tMD2GeometryGroup.Create( PrimitiveCount : cardinal; PrimitiveBuffer, GeometryBuffer : pointer );
begin
  inherited Create;
  fPrimitiveCount := PrimitiveCount;
  fPrimitiveBuffer := PrimitiveBuffer;
  fGeometryBuffer := GeometryBuffer;
end;

destructor tMD2GeometryGroup.Destroy;
begin
  FreeMem( fPrimitiveBuffer );
  FreeMem( fGeometryBuffer );
  inherited;
end;

function tMD2GeometryGroup.GetMaterialIndex : cardinal;
begin
  result := 0;
end;

function tMD2GeometryGroup.GetPrimitiveArray : pModelPrimitive;
begin
  result := fPrimitiveBuffer;
end;

function tMD2GeometryGroup.GetPrimitiveCount : cardinal;
begin
  result := fPrimitiveCount;
end;

function tMD2GeometryGroup.GetVertexArray : pModelVertex;
begin
  result := fGeometryBuffer;
end;

(* tMD2Geometry *)

constructor tMD2Geometry.Create( GeometryGroup : tMD2GeometryGroup );
begin
  inherited Create;
  fGeometryGroup := GeometryGroup;
end;

destructor tMD2Geometry.Destroy;
begin
  fGeometryGroup.Free;
  inherited;
end;

function tMD2Geometry.GetGeometryGroup( Index : cardinal ) : tGeometryGroup;
begin
  if Index > 0 then
    raise eRangeError.Create( 'Invalid Geometry Group Index' );
  result := fGeometryGroup;
end;

function tMD2Geometry.GetGeometryGroupCount : cardinal;
begin
  result := 1;
end;

(* tMD2ModelBuilder *)

function tMD2ModelBuilder.CreateModel( ModelData : tStream ) : tModel;
var
  MD2Data : pointer;

function GetHunk( Offset : cardinal ) : pointer;
begin
  result := pointer( cardinal( MD2Data ) + Offset - SizeOf( tMD2Header ) );
end;

var
  Header : tMD2Header;
  Model : tMD2Model;
  Size : integer;
begin
  result := nil;
  if ModelData.Read( Header, SizeOf( Header ) ) = SizeOf( Header ) then
  begin
    if ( Header.Magic = MD2_MAGIC ) and ( Header.Version = MD2_VERSION ) then
    begin
      Size := Header.EndOffset - SizeOf( Header );
      GetMem( MD2Data, Size );
      try
        if ModelData.Read( MD2Data^, Size ) = Size then
        begin
          Model := tMD2Model.Create;
          try
            Model.fVertexCount := Header.VertexCount;
            if Header.SkinCount > 0 then
            begin
              Model.fTextureSize := Header.SkinSize;
              LoadTextures( Model, Header.SkinCount, GetHunk( Header.SkinOffset ) );
            end;
            LoadFrames( Model, Header.FrameCount, GetHunk( Header.FrameOffset ) );
            LoadGeometry( Model, GetHunk( Header.GLCmdOffset ) );
            result := Model;
          except
            Model.Free;
            raise;
          end;
        end;
      finally
        FreeMem( MD2Data );
      end;
    end;
  end;
end;

procedure tMD2ModelBuilder.LoadFrames( Model : tMD2Model; FrameCount : cardinal; Data : pointer );
var
  Idx, VIdx, CIdx : cardinal;
  Size : cardinal;
  pVertexData : pointer;
  pVertex : pFloatPoint3d;
  pFrame : pMD2FrameHeader;
  pVX : pMD2Vertex;
  pNormal : pFloatPoint3d;
begin
  pFrame := Data;
  Size := 2 * Model.VertexCount * SizeOf( tFloatPoint3d );
  for Idx := 1 to FrameCount do
  begin
    GetMem( pVertexData, Size );
    try
      pVertex := pVertexData;
      pVX := pointer( cardinal( pFrame ) + SizeOf( tMD2FrameHeader ) );
      for VIdx := 0 to Model.VertexCount - 1 do
      begin
        for CIdx := 0 to 2 do
          pVertex^.i[ CIdx ] := ( pFrame^.Scale.i[ CIdx ] * pVX^.v[ CIdx ] ) + pFrame^.Translate.i[ CIdx ];
        inc( pVertex );

        pNormal := @NormalTable[ pVX^.NormalIndex ];
        pVertex^ := pNormal^;
        inc( pVertex );

        inc( pVX );
      end;
      pFrame := pointer( pVX );

      Model.FrameList.Add( tMD2Frame.Create( pVertexData ) );
    except
      FreeMem( pVertexData );
      raise;
    end;
  end;
end;

procedure tMD2ModelBuilder.LoadGeometry( Model : tMD2Model; Data : pointer );
var
  Pass, Idx, Count, PreviousCount : integer;
  pScan : pInteger;
  pPacket : pMD2GLPacket;
  Primitive : tPrimitive;
  GeometryBuffer : pointer;
  CommandBuffer : pointer;
  CommandBufferSize : cardinal;
  CommandScan : pModelPrimitive;
  PreviousCommandScan : pModelPrimitive;
  CommandCount : cardinal;
begin
  GeometryBuffer := nil;
  CommandCount := 0;
  CommandBufferSize := 0;
  CommandBuffer := nil;
  CommandScan := nil;

  try
    for Pass := 1 to 2 do
    begin
      pScan := Data;

      PreviousCommandScan := nil;
      Primitive := PR_TRIANGLE_FAN;
      PreviousCount := 0;
      Idx := 0;

      repeat
        Count := pScan^;
        if Count < 0 then
        begin
          Primitive := PR_TRIANGLE_FAN;
          Count := -Count;
        end
        else if Count > 3 then
          Primitive := PR_TRIANGLE_STRIP
        else if Count = 3 then
        begin
          if Primitive = PR_TRIANGLE then   // Combine successive TRIANGLE primitives
          begin
            Count := PreviousCount + 3;
            if Pass = 2 then
            begin
              CommandScan := PreviousCommandScan;
              CommandScan^.Header.VertexCount := Count;
            end;
          end;
          Primitive := PR_TRIANGLE;
          PreviousCount := Count;
        end
        else
          break;

        if ( Primitive <> PR_TRIANGLE ) or ( Count = 3 ) then   // Only allocate a new Command if not combining TRIANGLES
        begin
          if Pass = 2 then
          begin
            CommandScan^.Header.Primitive := Primitive;
            CommandScan^.Header.VertexCount := Count;
          end
          else
          begin
            inc( CommandCount );
            inc( CommandBufferSize, SizeOf( tModelPrimitiveHeader ) );
          end;

          Idx := 0;
        end;

        inc( pScan );
        pPacket := pointer( pScan );
        repeat
          if Pass = 2 then
          begin
            with CommandScan^.Vertices[ Idx ] do
            begin
              Texture.x := pPacket^.u;
              Texture.y := pPacket^.v;
              VertexIndex := pPacket^.VIdx;
            end;
          end
          else
            inc( CommandBufferSize, SizeOf( tModelPrimitiveVertex ) );
          inc( pPacket );
          inc( Idx );
        until Idx = Count;
        PreviousCommandScan := CommandScan;
        inc( cardinal( CommandScan ), SizeOf( tModelPrimitiveHeader ) );
        inc( cardinal( CommandScan ), SizeOf( tModelPrimitiveVertex ) * Count );
        pScan := pointer( pPacket );
      until false;

      if Pass = 1 then
      begin
        GetMem( GeometryBuffer, Model.VertexCount * SizeOf( tModelVertex ) );
        GetMem( CommandBuffer, CommandBufferSize );
        CommandScan := CommandBuffer;
      end
      else
        Model.fGeometry := tMD2Geometry.Create( tMD2GeometryGroup.Create( CommandCount, CommandBuffer, GeometryBuffer ) );
    end;
  except
    if GeometryBuffer <> nil then
      FreeMem( GeometryBuffer );
    if CommandBuffer <> nil then
      FreeMem( CommandBuffer );
    raise;
  end;
end;

procedure tMD2ModelBuilder.LoadTextures( Model : tMD2Model; Count : cardinal; Data : pointer );
var
  Idx : cardinal;
  pSkin : pMD2Skin;
begin
  pSkin := Data;
  for Idx := 1 to Count do
  begin
    Model.AddResourceTexture( pSkin^ );
    inc( pSkin );
  end;
end;

(* tMD2Model *)

constructor tMD2Model.Create;
begin
  inherited;
  fFrameList := tObjectList.Create;
  DefaultFPS := MD2_FPS;
  Orientation.rotateX( PI / 2 );      // MD2 Models are Up=Z+; Right=Y-; Away=X+
  Orientation.rotateY( PI );
end;

destructor tMD2Model.Destroy;
begin
  fGeometry.Free;
  fFrameList.Free;
  inherited;
end;

procedure tMD2Model.AddResourceTexture( ID : cardinal );
var
  Skin : tBitmap;
begin
  Skin := tBitmap.Create;
  try
    Skin.LoadFromResourceID( hResourceInstance, ID );
    if ( TextureSize.x <> 0 ) and ( TextureSize.y <> 0 ) and ( ( TextureSize.x <> Skin.Width ) or ( TextureSize.y <> Skin.Height ) ) then
      raise eCreateModelException.Create( 'Texture size does not match MD2 specification' );
    AddTexture( Skin );
  finally
    Skin.Free;
  end;
end;

procedure tMD2Model.AddResourceTexture( const Name : string );
var
  Skin : tBitmap;
begin
  Skin := tBitmap.Create;
  try
    Skin.LoadFromResourceName( hResourceInstance, Name );
    AddTexture( Skin );
  finally
    Skin.Free;
  end;
end;

procedure tMD2Model.AddTexture( Skin : tBitmap );
const
  Colour : tColour = ( rgba : $ffffffff );
begin
  TextureList.Add( tTextureBase.Create( Skin ) );
  MaterialList.Add( tMaterialBase.Create( Colour, TextureList.Count - 1 ) );
end;

function tMD2Model.DefineAnimation( StartFrame, EndFrame, GroupID : cardinal; Wrap : boolean; FPS : _float ) : tAnimation;
begin
  if FPS <= 0 then
    FPS := DefaultFPS;
  if GroupID = 0 then
    GroupID := AnimationList.Count + 1;
  result := tMD2Animation.Create( Self, AnimationList.Count + 1, StartFrame, EndFrame, GroupID, Wrap, FPS );
  AnimationList.Add( result );
end;

initialization
  tModelManager.RegisterBuilder( tMD2ModelBuilder.Create );
end.
