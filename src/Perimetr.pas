Unit Perimetr;

Interface

Uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Map;

Type
  tfrmPerimeter = Class(tForm)
    grpPerimeter: TGroupBox;
    btnOk: TButton;
    btnCancel: TButton;
    lblWalls: TLabel;
    boxWalls: TScrollBox;
    lstWalls: TListBox;
    lblHeight: TLabel;
    edtHeight: TEdit;
    updHeight: TUpDown;
    pnlPreview: TPanel;
    pbxPreview: TPaintBox;
    lblPreview: TLabel;
    Procedure lstWallsDrawItem (Control : tWinControl; Index : Integer; Rect : tRect; State : tOwnerDrawState);
    Procedure lstWallsClick (Sender : tObject);
    Procedure pbxPreviewPaint (Sender : tObject);
    Procedure updHeightClick (Sender : tObject; Button : tUDBtnType);
  Private
    ImageList : tImageList;
    ImageSize : tPoint;
    Procedure BuildWall (DesignIdx, Offset : Integer; WallBuffer : Pointer);
    Procedure CreateImage (aCanvas : tCanvas; DesignIdx, Offset : Integer);
    Procedure CreateImages;
    Function GetImageRect : tRect;
    Function IsNullDesign (DesignIdx : Integer) : Boolean;
    Procedure UpdatePreview;
  Public
    Constructor Create (aOwner : tComponent); Override;
    Procedure CreatePerimeter (Map : tMap);
    Destructor Destroy; Override;
  End;

Var
  frmPerimeter : tfrmPerimeter;

Implementation

{$R *.DFM}

uses
  Resource;

Const
  DESIGN_COUNT = 8;
  WALL_LENGTH  = 8;
  ZOOM_LEVEL   = 2;
  IMAGE_MARGIN = 8;
  TRANSPARENT_COLOUR = clTeal;
  Wall : Array [1..DESIGN_COUNT,1..WALL_LENGTH] Of tBlock =
    ((0,0,0,0,0,0,0,0),(15,63,255,63,15,63,255,63),(63,63,255,255,63,63,255,255),(63,255,1023,1023,1023,1023,1023,255),
     (63,63,63,255,1023,255,63,63),(63,15,255,783,783,255,15,63),(63,15,15,63,15,15,63,15),(255,255,255,831,3855,831,255,255));

(* Constructor *)

Constructor tfrmPerimeter.Create (aOwner : tComponent);
Begin
  Inherited Create(aOwner);
  ImageSize.X:=((BlockGfx[ZOOM_LEVEL,BLOCK_SOLID,BLOCK_IMAGE].Width * (WALL_LENGTH + 1)) Shr 1) + (IMAGE_MARGIN Shl 1);
  ImageSize.Y:=ImageSize.X + (BlockGfx[ZOOM_LEVEL,BLOCK_SOLID,BLOCK_IMAGE].Height * 7 Shr 2);
  ImageList:=tImageList.Create(Self);
  With ImageList Do
  Begin
    Width:=ImageSize.X;
    Height:=ImageSize.Y;
    Masked:=True;
  End;
  CreateImages;
End;

(* Events *)

Procedure tfrmPerimeter.lstWallsClick (Sender : tObject);
Begin
  btnOk.Enabled:=True;
  UpdatePreview;
End;

Procedure tfrmPerimeter.lstWallsDrawItem (Control : tWinControl; Index : Integer; Rect : tRect; State : tOwnerDrawState);
Begin
  With lstWalls, Canvas Do
  Begin
    If odSelected In State Then
      Brush.Color:=clHighlight
    Else
      Brush.Color:=clWindow;
    FillRect(Rect);
    ImageList.Draw(Canvas,Rect.Left,Rect.Top,Index);
  End;
End;

Procedure tfrmPerimeter.pbxPreviewPaint (Sender : tObject);
Begin
  UpdatePreview;
End;

Procedure tfrmPerimeter.updHeightClick (Sender : tObject; Button : tUDBtnType);
Begin
  UpdatePreview;
End;

(* Private *)

Procedure tfrmPerimeter.BuildWall (DesignIdx, Offset : Integer; WallBuffer : Pointer);
Var
  WIdx : Integer;
  pScan : pBlock;
  Segment : tBlock;
Begin
  pScan:=WallBuffer;
  Inc(Offset,Offset);
  For WIdx:=1 To WALL_LENGTH Do
  Begin
    Segment:=Wall[DesignIdx,WIdx];
    If Segment <> 0 Then
      If Offset > 0 Then
        Segment:=tBlock((Segment Shl Offset) Or ((3 Shl Offset) - 1))
      Else
        Segment:=Segment Shr -Offset;
    pScan^:=Segment;
    Inc(pScan);
  End;
End;

Procedure tfrmPerimeter.CreateImage (aCanvas : tCanvas; DesignIdx, Offset : Integer);
Var
  BlockRenderInfo : tBlockRenderInfo;
  WIdx, X, Y : Integer;
  ImageRect : tRect;
  BlockSize, BlockHalf, BlockQtr : Integer;
  WallBuffer : Array [1..WALL_LENGTH] Of tBlock;
Begin
  FillChar( BlockRenderInfo, SizeOf( BlockRenderInfo ), 0 );
  with BlockRenderInfo do
  begin
    Canvas := aCanvas;
    ZoomLevel := ZOOM_LEVEL;
    EditLevel := -1;
  end;

  If DesignIdx > 0 Then
  Begin
    ImageRect:=GetImageRect;
    BlockSize:=BlockGfx[ZOOM_LEVEL,BLOCK_SOLID,BLOCK_IMAGE].Width;
    BlockHalf:=BlockSize Shr 1;
    BlockQtr:=BlockHalf Shr 1;
    aCanvas.FillRect(ImageRect);
    If Not IsNullDesign(DesignIdx) Then
    Begin
      X:=ImageSize.X - IMAGE_MARGIN - BlockSize;
      Y:=(BlockHalf * 8) + IMAGE_MARGIN;
      BuildWall(DesignIdx,Offset,@WallBuffer);
      For WIdx:=1 To WALL_LENGTH Do
      Begin
        BlockRenderInfo.x := X;
        BlockRenderInfo.y := Y;
        BlockRenderInfo.Bitmask := WallBuffer[WIdx];
        DrawMapBlock( BlockRenderInfo );
        Dec(X,BlockHalf);
        Inc(Y,BlockQtr);
      End;
    End
    Else
      DrawText(aCanvas.Handle,'None',-1,ImageRect,DT_SINGLELINE Or DT_CENTER Or DT_VCENTER);
  End;
End;

Procedure tfrmPerimeter.CreateImages;
Var
  Idx : Integer;
  Scratch : tBitmap;
Begin
  Scratch:=tBitmap.Create;
  With Scratch Do
    Try
      Width:=ImageSize.X;
      Height:=ImageSize.Y;
      Canvas.Font.Assign(lstWalls.Font);
      Canvas.Brush.Color:=TRANSPARENT_COLOUR;
      For Idx:=1 To DESIGN_COUNT Do
      Begin
        CreateImage(Scratch.Canvas,Idx,0);
        ImageList.AddMasked(Scratch,TRANSPARENT_COLOUR);
        lstWalls.Items.AddObject('',Pointer(Idx));
      End;
    Finally
      Free;
    End;
End;

Function tfrmPerimeter.GetImageRect : tRect;
Begin
  Result:=Rect(0,0,ImageSize.X,ImageSize.Y);
End;

Function tfrmPerimeter.IsNullDesign (DesignIdx : Integer) : Boolean;
Var
  Idx : Integer;
Begin
  Result:=True;
  Idx:=1;
  While (Idx <= WALL_LENGTH) And Result Do
  Begin
    Result:=Wall[DesignIdx,Idx] = 0;
    Inc(Idx);
  End;
End;

Procedure tfrmPerimeter.UpdatePreview;
Begin
  pbxPreview.Canvas.FillRect(GetImageRect);
  CreateImage(pbxPreview.Canvas,lstWalls.ItemIndex + 1,updHeight.Position);
End;

(* Public Methods *)

Procedure tfrmPerimeter.CreatePerimeter (Map : tMap);
Var
  WallBuffer : Array [1..WALL_LENGTH] Of tBlock;
  WIdx : Integer;
  pScan : pBlock;

Procedure DoRow (Length, Delta, WDelta : Integer);
Var
  Idx : Integer;
Begin
  For Idx:=1 To Length Do
  Begin
    Inc(pScan,Delta);
    pScan^:=WallBuffer[WIdx];
    If WDelta > 0 Then
    Begin
      Inc(WIdx);
      If WIdx > WALL_LENGTH Then
        WIdx:=1;
    End
    Else
    Begin
      Dec(WIdx);
      If WIdx < 1 Then
        WIdx:=WALL_LENGTH;
    End;
  End;
End;

Begin
  BuildWall(lstWalls.ItemIndex + 1,updHeight.Position,@WallBuffer);
  pScan:=Map.BlockData;
  WIdx:=1;
  Dec(pScan,1);
  DoRow(Map.Width,1,1);
  DoRow(Map.Height - 1,Map.Width,-1);
  DoRow(Map.Width - 1,-1,1);
  DoRow(Map.Height - 1,-Map.Width,-1);
  Map.EnsureThingsAreNotObstructed;
  Map.invalidateLightMaps;
End;

(* Destructor *)

Destructor tfrmPerimeter.Destroy;
Begin
  ImageList.Free;
  Inherited Destroy;
End;

End.
