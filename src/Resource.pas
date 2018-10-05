unit Resource;

interface

uses
  Classes, Graphics, Cube, Map, Types;

const
  RES_BLOCK_BASE      = 100;
  RES_BACKGROUND_BASE = 500;
  RES_SOUND_BASE      = 800;
  RES_BLOCK_TEXTURE   = 900;
  RES_FLOOR_TEXTURE   = 910;
  RES_FONT_STRUCTURE  = 930;
  RES_ICON_TEXTURE    = 940;
  RES_MODEL_BASE      = 950;
  RES_SPRITE_BASE     = 960;
  RES_SPRITE_TEXTURE  = 970;
  RES_INTRO_MAP       = 990;
  RES_ABOUT_RTF       = 999;

  ICON_GRENADE        = 0;

type
  tBlockState = ( BLOCK_MASK, BLOCK_IMAGE, BLOCK_SELECTED_IMAGE, BLOCK_HIGHLIGHT, BLOCK_SELECTED_HIGHLIGHT, BLOCK_GRID, BLOCK_SELECTED_GRID );

  tThingState = ( THING_MASK, THING_IMAGE, THING_HIGHLIGHT );

  tSelectionStyle = ( SELECTION_MAP, SELECTION_THINGS );

  tDirection = (DIR_NORTHWEST,DIR_NORTHEAST,DIR_SOUTHEAST,DIR_SOUTHWEST);

  tDirectionInfo = Record
    Origin : tPoint;
    Size   : tPoint;
    Delta  : tPoint;
    Desc   : String;
  End;

  pResourceHunk = ^tResourceHunk;
  tResourceHunk = record
    Data : pointer;
    Size : cardinal;
  end;

  tBlockRenderInfo = record
    Canvas : tCanvas;
    x, y, ZoomLevel, EditLevel : integer;
    CameraDirection : tDirection;
    Bitmask : tBlock;
    Grid, Selected : boolean;
    ThingList : tList;
  end;

const
  BLOCK_COUNT = 8;    // Number of different zoom levels

  SELECTION_COLOUR : tColor = ( $FF8040 );

  MasterDirectionInfo : Array [tDirection] Of tDirectionInfo = (
    (Origin:(X:0;Y:0);Size:(X:1;Y:-1);Delta:(X:1;Y:100);Desc:'Northwest'),
    (Origin:(X:1;Y:0);Size:(X:-1;Y:1);Delta:(X:100;Y:-1);Desc:'Northeast'),
    (Origin:(X:1;Y:-1);Size:(X:1;Y:-1);Delta:(X:-1;Y:-100);Desc:'Southeast'),
    (Origin:(X:0;Y:-1);Size:(X:-1;Y:1);Delta:(X:-100;Y:1);Desc:'Southwest'));

var
  BlockGfx : Array [ 1 .. BLOCK_COUNT, BLOCK_WATER .. BLOCK_SOLID, tBlockState ] Of tBitmap;
  ThingGfx : Array [ 1 .. BLOCK_COUNT, tThingState ] of tBitmap;

Function GetBlockTexture( nMipLevel : integer ) : pointer;
Function GetFloorTexture( nMipLevel : integer ) : pointer;
Function GetFontStructure( nId : integer ) : pointer;
function GetIconTexture( nId : integer ) : pointer;
function GetSpriteTexture( nId : integer ) : pointer;
function GetSoundEffect( nId : integer ) : pointer;
function GetIntroductionMap( nId : integer ) : pResourceHunk;
Procedure DrawMapBlock ( var BlockRenderInfo : tBlockRenderInfo );
procedure DrawThing( var BlockRenderInfo : tBlockRenderInfo; Highlight, OffsetPosition : boolean; const Thing : tThingInfo );

var
  hResourceInstance : cardinal;

implementation

uses
  Dialogs, Forms, Windows, glFont, Colour;

const
  RESOURCE_LIBRARY = 'resource.dat';

Var
  pBlockTexture : array [ 0 .. 7 ] of tResourceHunk;
  pFloorTexture : array [ 0 .. 0 ] of tResourceHunk;
  pFontStructure : array [ 0 .. 0 ] of tResourceHunk;
  pIconTexture : array [ 0 .. 0 ] of tResourceHunk;
  pSpriteTexture : array [ 0 .. 3 ] of tResourceHunk;
  pSoundEffect : array [ 0 .. 24 ] of tResourceHunk;
  pIntroductionMap : array [ 0 .. 0 ] of tResourceHunk;

procedure DrawMapBlock ( var BlockRenderInfo : tBlockRenderInfo );
Var
  Bit, SBit, BlockHalf, Idx : Integer;
  BlockType : tBlockType;
  BlockState : tBlockState;
  Highlight : boolean;
Begin
  with BlockRenderInfo do
  begin
    SBit := 0;
    BlockHalf:=BlockGfx[ZoomLevel,BLOCK_SOLID,BLOCK_IMAGE].Height Shr 1;
    For Bit:=0 To 7 Do
    Begin
      Highlight := Bit = EditLevel;
      Dec( Y, BlockHalf );
      BlockType := tBlockType( ( ( 3 shl SBit ) and BitMask ) shr SBit );   // 8-03
      If BlockType <> BLOCK_EMPTY Then
      begin
        With Canvas Do
        Begin
          CopyMode:=cmSrcAnd;
          Draw(X,Y,BlockGfx[ZoomLevel,BlockType,BLOCK_MASK]);
          CopyMode:=cmSrcPaint;
          If Highlight Then
          begin
            if Grid then
              BlockState := BLOCK_GRID
            else
              BlockState := BLOCK_HIGHLIGHT;
          end
          else
            BlockState := BLOCK_IMAGE;
          if Selected then
            BlockState := Succ( BlockState );
          Draw(X,Y,BlockGfx[ZoomLevel,BlockType,BlockState])
        End;
      end
      else
        if ThingList <> nil then
          for Idx := 0 to ThingList.Count - 1 do
            with tThing( ThingList[ Idx ] ) do
              if Info.Position.y = Bit then
                DrawThing( BlockRenderInfo, Highlight, true, Info );

      Inc(SBit,2);
    End;
  end;
End;

procedure DrawThing( var BlockRenderInfo : tBlockRenderInfo; Highlight, OffsetPosition : boolean; const Thing : tThingInfo );
const
  ThingHighlight : array [ boolean ] of tThingState = ( THING_IMAGE, THING_HIGHLIGHT );
  DirectionLookup : array [ 0 .. 3 ] of integer = ( 3, 0, 1, 2 );
var
  Image, Mask : Graphics.tBitmap;
  SX, SY, ImageX, ImageY, ImageWidth, ImageHeight : integer;
  Direction : integer;
  Source, Destination : tRect;
begin
  with BlockRenderInfo do
  begin
    Image := ThingGfx[ ZoomLevel, ThingHighlight[ Highlight ] ];
    Mask := ThingGfx[ ZoomLevel, THING_MASK ];

    SX := x;
    SY := y;

    ImageWidth := Image.Width div ( Ord( High( tThingType ) ) + 1 );
    ImageHeight := Image.Height div 4;
    if OffsetPosition then
    begin
      Inc( SX, ImageWidth Shr 1 );
      Inc( SY, ImageHeight * 3 div 4 );
    end;

    Direction := ( 4 + Round( ( PI - Thing.Orientation ) * 2 / PI ) - Ord( CameraDirection ) ) mod 4;

    ImageX := Ord( Thing.ThingType ) * ImageWidth;
    ImageY := DirectionLookup[ Direction ] * ImageHeight;
    Source := Rect( ImageX, ImageY, ImageX + ImageWidth, ImageY + ImageHeight );
    Destination := Rect( SX, SY, SX + ImageWidth, SY + ImageHeight );

    with Canvas do
    begin
      CopyMode := cmSrcAnd;
      CopyRect( Destination, Mask.Canvas, Source );
      CopyMode := cmSrcPaint;
      CopyRect( Destination, Image.Canvas, Source );
    end;
  end;
end;

Function GetBlockTexture( nMipLevel : integer ) : pointer;
Begin
  Result := pBlockTexture[ nMipLevel ].Data;
End;

Function GetFloorTexture( nMipLevel : integer ) : pointer;
Begin
  Result := pFloorTexture[ nMipLevel ].Data;
End;

Function GetFontStructure( nId : integer ) : pointer;
begin
  result := pFontStructure[ nId ].Data;
end;

function GetIconTexture( nId : integer ) : pointer;
begin
  result := pIconTexture[ nId ].Data;
end;

function GetSpriteTexture( nId : integer ) : pointer;
begin
  result := pSpriteTexture[ nId ].Data;
end;

function GetSoundEffect( nId : integer ) : pointer;
begin
  result := pSoundEffect[ nId ].Data;
end;

function GetIntroductionMap( nId : integer ) : pResourceHunk;
begin
  result := @pIntroductionMap[ nId ];
end;

(* Startup and Shutdown *)

function CreateSelectedBitmap( const Source, Mask : Graphics.tBitmap ) : Graphics.tBitmap;
var
  x, y : integer;
begin
  result := Graphics.tBitmap.Create;
  try
    result.Width := Source.Width;
    result.Height := Source.Height;
    result.Monochrome := false;
    for y := 0 to Source.Height - 1 do
      for x := 0 to Source.Width - 1 do
        if Mask.Canvas.Pixels[ x, y ] = 0 then
          result.Canvas.Pixels[ x, y ] := BlendColours( Source.Canvas.Pixels[ x, y ], SELECTION_COLOUR )
        else
          result.Canvas.Pixels[ x, y ] := 0;
  except
    result.free;
    raise;
  end;
end;

Procedure InitResources;

Function GetResourceData( ResourceID : integer; CopyMode : boolean = false ) : tResourceHunk;
var
  hResourceInfo : cardinal;
  pResource : pointer;
begin
  hResourceInfo := findResource( hResourceInstance, pChar( ResourceID ), RT_RCDATA );
  result.Data := lockResource( loadResource( hResourceInstance, hResourceInfo ) );
  result.Size := SizeOfResource( hResourceInstance, hResourceInfo );
  if CopyMode then
  begin
    pResource := result.Data;
    GetMem( result.Data, result.Size );
    Move( pResource^, result.Data^, result.Size );
  end;
end;

const
  BlockState : array [ 0 .. 3 ] of tBlockState = ( BLOCK_MASK, BLOCK_IMAGE, BLOCK_HIGHLIGHT, BLOCK_GRID );
  BlockTypeBase : array [ tBlockType ] of integer = ( 0, 10, 20, 0 );
  ThingStateBase : array [ tThingState ] of integer = ( 130, 230, 330 );
Var
  State : tBlockState;
  TState : tThingState;
  Bitmap : Graphics.tBitmap;
  SIdx, Idx, Offset : Integer;
  BlockType : tBlockType;
Begin
  hResourceInstance := LoadLibrary( RESOURCE_LIBRARY );
  if hResourceInstance = 0 then
  begin
    MessageDlg( 'Unable to locate ' + RESOURCE_LIBRARY, mtError, [ mbOk ], 0 );
    halt;
  end;
  FillChar(BlockGfx,SizeOf(BlockGfx),0);
  FillChar(ThingGfx,SizeOf(ThingGfx),0);
  Offset:=RES_BLOCK_BASE;
  For SIdx:=Low( BlockState ) To High( BlockState ) Do
  Begin
    State := BlockState[ SIdx ];
    for BlockType := BLOCK_WATER to BLOCK_SOLID do
    begin
      For Idx:=1 To BLOCK_COUNT Do
      Begin
        Bitmap := Graphics.tBitmap.Create;  // 8-03
        BlockGfx[ Idx, BlockType, State ]:= Bitmap;
        Bitmap.LoadFromResourceID( hResourceInstance, Idx + BlockTypeBase[ BlockType ] + Offset - 1 );
        if State <> BLOCK_MASK then
          BlockGfx[ Idx, BlockType, Succ( State ) ] := CreateSelectedBitmap( Bitmap, BlockGfx[ Idx, BlockType, BLOCK_MASK ] );
      End;
    end;
    Inc(Offset,RES_BLOCK_BASE);
  End;

  For TState:=Low(tThingState) To High(tThingState) Do
  Begin
    For Idx:=1 To BLOCK_COUNT Do
    Begin
      ThingGfx[Idx,TState]:=Graphics.TBitmap.Create;
      With ThingGfx[Idx,TState] Do
        LoadFromResourceID(hResourceInstance, Idx + ThingStateBase[TState] - 1);
    End;
  End;

  for Idx := low( pBlockTexture ) to high( pBlockTexture ) do
    pBlockTexture[ Idx ] := GetResourceData( RES_BLOCK_TEXTURE + Idx );
  for Idx := low( pFloorTexture ) to high( pFloorTexture ) do
    pFloorTexture[ Idx ] := GetResourceData( RES_FLOOR_TEXTURE + Idx );
  for Idx := low( pFontStructure ) to high( pFontStructure ) do
  begin
    pFontStructure[ Idx ] := GetResourceData( RES_FONT_STRUCTURE + Idx, True );   // We copy the fonts because we need to write to them
    glFontBorder( pFontStructure[ Idx ].Data, 1 );
  end;
  for Idx := low( pIconTexture ) to high( pIconTexture ) do
    pIconTexture[ Idx ] := GetResourceData( RES_ICON_TEXTURE + Idx );
  for Idx := low( pSpriteTexture ) to high( pSpriteTexture ) do
    pSpriteTexture[ Idx ] := GetResourceData( RES_SPRITE_TEXTURE + Idx );
  for Idx := low( pSoundEffect ) to high( pSoundEffect ) do
    pSoundEffect[ Idx ] := GetResourceData( RES_SOUND_BASE + Idx );
  for Idx := low( pIntroductionMap ) to high( pIntroductionMap ) do
    pIntroductionMap[ Idx ] := GetResourceData( RES_INTRO_MAP + Idx );
End;

Procedure FreeResources;
Var
  State : tBlockState;
  TState : tThingState;
  BlockType : tBlockType;
  Idx : Integer;
Begin
  For State:=Low(tBlockState) To High(tBlockState) Do
    for BlockType := BLOCK_WATER to BLOCK_SOLID do
      For Idx:=1 To BLOCK_COUNT Do
        BlockGfx[ Idx, BlockType, State ].Free;   // 8-03
  For TState:=Low(tThingState) To High(tThingState) Do
    For Idx:=1 To BLOCK_COUNT Do
      ThingGfx[Idx,TState].Free;
  for Idx := low( pFontStructure ) to high( pFontStructure ) do
    FreeMem( pFontStructure[ Idx ].Data );
  FreeLibrary( hResourceInstance );
End;

Initialization
  InitResources;
Finalization
  FreeResources;
end.
