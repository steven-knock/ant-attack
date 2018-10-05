Unit Viewer;

Interface

Uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, Common, Map, Resource, Selection, MDIChildForm;

Type
  tMenuItems = ( MS_UNDO, MS_CUT, MS_COPY, MS_PASTE, MS_DELETE, MS_RAISE, MS_LOWER, MS_ZOOMIN, MS_ZOOMOUT, MS_PLANEFIRST, MS_PLANEUP, MS_PLANEDOWN, MS_PLANELAST );
  tMenuState = Set Of tMenuItems;

  tEditMode = ( EDIT_BLOCK, EDIT_THING );

  tfrmViewer = Class(tMDIChildForm)
    dlgSave: TSaveDialog;
    pbxRender: TPaintBox;
    Procedure FormClose (Sender : tObject; Var Action : tCloseAction);
    Procedure FormCloseQuery (Sender : tObject; Var CanClose : Boolean);
    Procedure FormKeyDown (Sender : tObject; Var Key : Word; Shift : tShiftState);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure pbxRenderDblClick(Sender: TObject);
    procedure pbxRenderMouseDown (Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : Integer);
    procedure pbxRenderMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbxRenderMouseUp (Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : Integer);
    Procedure pbxRenderPaint (Sender : tObject);
  Private
    fDirection : tDirection;
    fDirty : boolean;
    fEditLevel : Integer;
    fEditMode : tEditMode;
    fMapSelectionState : tMapSelectionState;
    fSelectionHandler : tSelectionHandler;
    fShowGrid : boolean;
    fShowOnlyActivePlane : boolean;
    fZoom : Integer;
    fBlockType : tBlockType;
    fThingType : tThingType;
    fThingMap : tStringList;
    cMap : tMap;
    DirectionInfo : tDirectionInfo;
    ScanBuffer : Pointer;
    ScanLimit : Integer;
    procedure AdjustClipRect( var ClipRect : tRect );
    Procedure AskSave;
    function  BuildCellClipRect( const MapPos : tPoint ) : tRect;
    function  BuildSelectionClipRect : tRect;
    Procedure BuildScanBuffer;
    Procedure CalculateWindow;
    Procedure FreeMap;
    Function  GetBlockSize : Integer;
    Function  GetCamera : tPoint;
    Function  GetColumnHeight : Integer;
    Function  GetMapPosition (X,Y,Z : Integer) : tPoint;
    Function  GetMenuState : tMenuState;
    function  GetSelectionRegion : tSelectionRegion;
    function  GetThing( x, y, z : integer ) : tThing;
    function  GetThingKey( x, y, z : integer ) : string;
    procedure GetThingsInBlock( x, y, z : integer; List : tList ); overload;
    procedure GetThingsInBlock( Offset, y : integer; List : tList ); overload;
    Function  GetWndPosition (X,Y,Z : Integer) : tPoint;
    procedure HandleMouseEvent( Button : tMouseButton; X, Y, EventCode : Integer);
    function  IsPreview : boolean;
    function  IsPlaying : boolean;
    function  NormaliseRectangle( const Rect : tRect ) : tRect;
    Procedure PerformSave (Const NewFilename : String);
    procedure ProcessSelection( Command : tSelectionCommand; UpdateSelection : boolean = true; RequireSelection : boolean = true; FreeCommand : boolean = true );
    procedure PopulateThingMap;
    procedure RenderDynamicSelection;
    procedure RenderStaticSelection( DrawCanvas : tCanvas );
    Procedure RenderMap (DrawCanvas : tCanvas);
    procedure SetBlockType( aBlockType : tBlockType );
    Procedure SetCamera (MapPos : tPoint);
    Procedure SetDirection (aDirection : tDirection);
    procedure SetDirty( aDirty : boolean );
    Procedure SetEditLevel (aEditLevel : Integer);
    procedure SetShowGrid( aShowGrid : boolean );
    procedure SetShowOnlyActivePlane( aShowOnlyActivePlane : boolean );
    procedure SetThingType( aThingType : tThingType );
    Procedure SetZoom (aZoom : Integer);
    Procedure UpdateDirectionInfo;
  protected
    procedure UpdateMenu; override;
  Public
    Constructor Create (aOwner : tComponent; aMap : tMap); Reintroduce;
    procedure CopySelection;
    procedure ClearSelection;
    procedure CutSelection;
    procedure DeleteSelection;
    procedure ExportMap;
    procedure LowerSelection;
    Procedure MapSizeChange;
    procedure PasteSelection;
    procedure RaiseSelection;
    procedure RememberMap;
    Procedure Save;
    Procedure SaveAs;
    procedure SelectAll;
    procedure UndoAction;
    Procedure UpdateCaption;
    Destructor Destroy; Override;
    Property BlockType : tBlockType read fBlockType write SetBlockType;
    property Dirty : boolean read fDirty write SetDirty;
    property ThingType : tThingType read fThingType write SetThingType;
    Property MenuState : tMenuState Read GetMenuState;
    Property Direction : tDirection Read fDirection Write SetDirection;
    property EditMode : tEditMode read fEditMode;
    Property EditLevel : Integer Read fEditLevel Write SetEditLevel;
    property Map : tMap read cMap;
    property ShowGrid : boolean read fShowGrid write SetShowGrid;
    property ShowOnlyActivePlane : boolean read fShowOnlyActivePlane write SetShowOnlyActivePlane;
    Property Zoom : Integer Read fZoom Write SetZoom;
  End;

Var
  frmViewer : tfrmViewer;

Implementation

{$R *.DFM}

Uses
  Colour, ExportMap, Game, Main, Preview, StrUtils, Things;

const
  MOUSE_DOWN = 0;
  MOUSE_UP = 1;
  MOUSE_DOUBLE_CLICK = 2;
  MOUSE_MOVE = 3;

  MIN_EDIT_LEVEL = 0;
  MAX_EDIT_LEVEL = 7;

Type
  pScanLine = ^tScanLine;
  tScanLine = Record
    MapAddr : pBlock;
    Offset  : Integer;
    Delta   : Integer;
    Length  : Integer;
  End;

Constructor tfrmViewer.Create (aOwner : tComponent; aMap : tMap);
Begin
  Inherited Create(aOwner);
  fSelectionHandler := tSelectionHandler.Create;
  fMapSelectionState := tMapSelectionState.Create;
  FreeMap;
  cMap:=aMap;
  ScanBuffer:=Nil;
  fShowGrid := true;
  fThingMap := tStringList.Create;
  fThingMap.Sorted := true;
  fEditLevel:=0;
  fZoom:=2;
  fBlockType := BLOCK_SOLID;
  fEditMode := EDIT_BLOCK;
  Left:=0;
  Top:=0;
  MapSizeChange;
  UpdateCaption;
End;

(* Events *)

Procedure tfrmViewer.FormClose (Sender : tObject; Var Action : tCloseAction);
Begin
  Action:=caFree;
End;

Procedure tfrmViewer.FormCloseQuery (Sender : tObject; Var CanClose : Boolean);
Begin
  Try
    AskSave;
  Except
    CanClose:=False;
  End;
End;

Procedure tfrmViewer.FormKeyDown (Sender : tObject; Var Key : Word; Shift : tShiftState);
Var
  CtrlDown : Boolean;
  Delta : tPoint;
  PageSize : Integer;
Begin
  CtrlDown:=ssCtrl In Shift;
  Delta.X:=0;
  Delta.Y:=0;
  Case Key Of
    VK_LEFT:
      Delta.X:=-HorzScrollBar.Increment;
    VK_RIGHT:
      Delta.X:=HorzScrollBar.Increment;
    VK_UP:
      Delta.Y:=-VertScrollBar.Increment;
    VK_DOWN:
      Delta.Y:=VertScrollBar.Increment;
    VK_HOME:
    Begin
      HorzScrollBar.Position:=0;
      If CtrlDown Then
        VertScrollBar.Position:=0;
    End;
    VK_END:
    Begin
      HorzScrollBar.Position:=HorzScrollBar.Range;
      If CtrlDown Then
        VertScrollBar.Position:=VertScrollBar.Range;
    End;
    VK_PRIOR:
      If Not CtrlDown Then
      Begin
        Delta.Y:=-VertScrollBar.Increment;
        CtrlDown:=True;
      End
      Else
        VertScrollBar.Position:=0;
    VK_NEXT:
      If Not CtrlDown Then
      Begin
        Delta.Y:=VertScrollBar.Increment;
        CtrlDown:=True;
      End
      Else
        VertScrollBar.Position:=VertScrollBar.Range;
    VK_ESCAPE:
      ClearSelection;
  End;
  If CtrlDown Then
    PageSize:=16
  Else
    PageSize:=1;
  HorzScrollBar.Position:=HorzScrollBar.Position + Delta.X * PageSize;
  VertScrollBar.Position:=VertScrollBar.Position + Delta.Y * PageSize;
End;

procedure tfrmViewer.FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  UnityDelta : integer;
begin
  UnityDelta := WheelDelta div Abs( WheelDelta );
  if Shift = [] then
    EditLevel := EditLevel + UnityDelta
  else if Shift = [ssShift, ssCtrl] then
    Zoom := Zoom + UnityDelta
  else if Shift = [ssShift] then
    HorzScrollBar.Position := HorzScrollBar.Position + WheelDelta
  else if Shift = [ssCtrl] then
    VertScrollBar.Position := VertScrollBar.Position - WheelDelta;
  Handled := true;
end;

procedure tfrmViewer.pbxRenderDblClick(Sender: TObject);
begin
  with ScreenToClient( Mouse.CursorPos ) do
    HandleMouseEvent( mbLeft, X + HorzScrollBar.Position, Y + VertScrollBar.Position, MOUSE_DOUBLE_CLICK );
end;

Procedure tfrmViewer.pbxRenderMouseDown (Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : Integer);
begin
  HandleMouseEvent( Button, X, Y, MOUSE_DOWN );
end;

procedure tfrmViewer.pbxRenderMouseMove( Sender: TObject; Shift: TShiftState; X, Y: Integer );
begin
  if fMapSelectionState.Dragging or fMapSelectionState.DragTest then
    HandleMouseEvent( mbLeft, X, Y, MOUSE_MOVE );
end;

procedure tfrmViewer.pbxRenderMouseUp (Sender : tObject; Button : tMouseButton; Shift : tShiftState; X, Y : Integer);
begin
  HandleMouseEvent( Button, X, Y, MOUSE_UP );
end;

Procedure tfrmViewer.pbxRenderPaint (Sender : tObject);
Begin
  RenderMap(pbxRender.Canvas);
End;

(* Private Methods *)

procedure tfrmViewer.AdjustClipRect( var ClipRect : tRect );
var
  BlockSize, BlockHalf : Integer;
begin
  BlockSize:=GetBlockSize;
  BlockHalf:=BlockSize Shr 1;
  With ClipRect Do
  Begin
    Dec( Left, BlockSize + HorzScrollBar.Position );
    Dec( Top, BlockSize + VertScrollBar.Position );
    Inc( Right, BlockSize + BlockHalf - HorzScrollBar.Position );
    Inc( Bottom, BlockSize + BlockHalf - VertScrollBar.Position );
  End;
end;

Procedure tfrmViewer.AskSave;
Begin
  If Dirty And Assigned(Map) Then
    Case MessageDlg('Do You Want To Save Changes Made To ' + Map.Header^.Title + '?',mtConfirmation,mbYesNoCancel,0) Of
      mrYes:
        Save;
      mrCancel:
        Abort;
    End;
End;

function tfrmViewer.BuildCellClipRect( const MapPos : tPoint ) : tRect;
begin
  result.TopLeft := GetWndPosition(MapPos.X,MapPos.Y,EditLevel);
  result.BottomRight := result.TopLeft;
  AdjustClipRect( result );
end;

function tfrmViewer.BuildSelectionClipRect : tRect;
var
  Idx, WIdx, Level : integer;
  WndPos : array [ 0 .. 3 ] of tPoint;
begin
  with fMapSelectionState.Area do
  begin
    for Idx := 0 to 1 do
    begin
      Level := MAX_EDIT_LEVEL * Idx;
      WndPos[ 0 ] := GetWndPosition( Left, Top, Level );
      WndPos[ 1 ] := GetWndPosition( Right, Top, Level );
      WndPos[ 2 ] := GetWndPosition( Right, Bottom, Level );
      WndPos[ 3 ] := GetWndPosition( Left, Bottom, Level );
      for WIdx := 0 to 3 do
        if ( Idx = 0 ) and ( WIdx = 0 ) then
        begin
          result.TopLeft := WndPos[ 0 ];
          result.BottomRight := result.TopLeft;
        end
        else
          AddPointToRect( result, WndPos[ WIdx ] );
    end;
  end;
  AdjustClipRect( result );
end;

Procedure tfrmViewer.BuildScanBuffer;
Var
  pScan : pScanLine;
  Idx, X, Length, ColHeight : Integer;
  pMapScan : pBlock;

Begin
  If Assigned(ScanBuffer) Then
  Begin
    FreeMem(ScanBuffer);
    ScanBuffer:=Nil;
  End;
  ColHeight:=MAP_SIZE_COLUMN Shl 1;
  ScanLimit:=Map.Width + Map.Height - 1 + ColHeight;
  GetMem(ScanBuffer,ScanLimit * SizeOf(tScanLine));
  Try
    pScan:=ScanBuffer;
    For Idx:=1 To ColHeight Do
    Begin
      pScan^.MapAddr:=Nil;
      Inc(pScan);
    End;
    With DirectionInfo Do
    Begin
      pMapScan:=@pBlockArray(Map.BlockData)^[Origin.Y * Map.Width + Origin.X];
      X:=Size.Y - 1;
      Length:=1;
      For Idx:=1 To Size.X + Size.Y - 1 Do
      Begin
        pScan^.MapAddr:=pMapScan;
        pScan^.Offset:=X;
        pScan^.Delta:=Delta.X - Delta.Y;
        pScan^.Length:=Length;
        Inc(pScan);
        If Idx < Size.Y Then
        Begin
          Inc(pMapScan,Delta.Y);
          Dec(X);
        End
        Else
        Begin
          Inc(pMapScan,Delta.X);
          Inc(X);
        End;
        If Idx < Size.X Then
          Inc(Length);
        If Idx >= Size.Y Then
          Dec(Length);
      End;
    End;
  Except
    FreeMem(ScanBuffer);
    ScanBuffer:=Nil;
    Raise;
  End;
End;

Procedure tfrmViewer.CalculateWindow;
Const
  BottomMargin = 2;
Var
  BlockSize : Integer;
  FullSize, MaxSize  : tPoint;

Procedure ResizeWindow;
Begin
  If WindowState = wsNormal Then
  Begin
    MaxSize.X:=tCustomForm(Owner).ClientWidth - Left - Width + ClientWidth - 4;
    MaxSize.Y:=tCustomForm(Owner).ClientHeight - Top - Height + ClientHeight - 4 - 29;  // Have to include the height of the toolbar since ClientHeight doesn't include it
    If FullSize.X > MaxSize.X Then
      FullSize.X:=MaxSize.X;
    If FullSize.Y > MaxSize.Y Then
      FullSize.Y:=MaxSize.Y;
    ClientWidth:=FullSize.X;
    ClientHeight:=FullSize.Y;
  End;
End;

Begin
  HorzScrollBar.Visible:=False;
  VertScrollBar.Visible:=False;
  BlockSize:=GetBlockSize;
  If Assigned(Map) Then
  Begin
    FullSize.X:=((Map.Width Shr 1) + (Map.Height Shr 1)) * BlockSize;
    FullSize.Y:=((Map.Width Shr 2) + (Map.Height Shr 2)) * BlockSize + GetColumnHeight + BottomMargin;
  End
  Else
  Begin
    FullSize.X:=0;
    FullSize.Y:=0;
  End;
  pbxRender.Width:=FullSize.X;
  pbxRender.Height:=FullSize.Y;
  ResizeWindow;
  HorzScrollBar.Visible:=True;
  VertScrollBar.Visible:=True;
  HorzScrollBar.Increment:=BlockSize;
  VertScrollBar.Increment:=BlockSize;
End;

Procedure tfrmViewer.FreeMap;
Begin
  AskSave;
  FreeAndNil( cMap );
  fSelectionHandler.Context.ClearUndoStack;
  Dirty:=False;
End;

Function tfrmViewer.GetBlockSize : Integer;
Begin
  Result:=BlockGfx[Zoom, BLOCK_SOLID, BLOCK_IMAGE].Width;
End;

Function tfrmViewer.GetCamera : tPoint;
Var
  MapSize : Integer;
Begin
  MapSize:=Map.Width + Map.Height;
  If pbxRender.Width > ClientWidth Then
    Result.X:=HorzScrollBar.Position + (ClientWidth Shr 1)
  Else
    Result.X:=MapSize Shr 1;
  If pbxRender.Height > ClientHeight Then
    Result.Y:=VertScrollBar.Position + (ClientHeight Shr 1)
  Else
    Result.Y:=MapSize Shr 2;
  Result:=GetMapPosition(Result.X,Result.Y,0);
End;

Function tfrmViewer.GetColumnHeight : Integer;
Begin
  Result:=(GetBlockSize * MAP_SIZE_COLUMN) Shr 1;
End;

Function tfrmViewer.GetMapPosition (X,Y,Z : Integer) : tPoint;
Var
  BlockSize : Integer;
  MapSize : tPoint;
Begin
  BlockSize:=GetBlockSize;
  Y:=((Y - GetColumnHeight) * 2) + (Z * BlockSize);
  MapSize.X:=(Map.Width Shr 1) * BlockSize;
  MapSize.Y:=(Map.Height Shr 1) * BlockSize;
  Case Direction Of
    DIR_NORTHWEST:
    Begin
      Result.X:=-MapSize.Y + X + Y;
      Result.Y:=MapSize.Y - X + Y;
    End;
    DIR_NORTHEAST:
    Begin
      Result.X:=MapSize.X + X - Y;
      Result.Y:=-MapSize.X + X + Y;
    End;
    DIR_SOUTHEAST:
    Begin
      Result.X:=(Map.Width * BlockSize) + MapSize.Y - X - Y;
      Result.Y:=MapSize.Y + X - Y;
    End;
    DIR_SOUTHWEST:
    Begin
      Result.X:=MapSize.X - X + Y;
      Result.Y:=MapSize.X + (Map.Height * BlockSize) - X - Y;
    End;
  End;
  If Result.X < 0 Then
    Dec(Result.X,BlockSize);
  If Result.Y < 0 Then
    Dec(Result.Y,BlockSize);
  Result.X:=Result.X Div BlockSize;
  Result.Y:=Result.Y Div BlockSize;
End;

Function tfrmViewer.GetMenuState : tMenuState;
Begin
  Result:=[];
  If ( fSelectionHandler <> nil ) and ( fSelectionHandler.Context.GetUndoStackSize > 0 ) Then
    Include(Result,MS_UNDO);
  If fZoom < BLOCK_COUNT Then
    Include(Result,MS_ZOOMIN);
  If fZoom > 1 Then
    Include(Result,MS_ZOOMOUT);
  If EditLevel > MIN_EDIT_LEVEL Then
    Result:=Result + [MS_PLANELAST,MS_PLANEDOWN];
  If EditLevel < MAX_EDIT_LEVEL Then
    Result:=Result + [MS_PLANEFIRST,MS_PLANEUP];
  if ( fMapSelectionState <> nil ) and fMapSelectionState.AreaValid then
  begin
    Result := Result + [ MS_CUT, MS_COPY, MS_DELETE ];
    if tPasteCommand.ClipboardContainsData then
      Include( Result, MS_PASTE );
    if not ShowOnlyActivePlane then
      Result := Result + [ MS_RAISE, MS_LOWER ];
  end;
End;

function tfrmViewer.GetSelectionRegion : tSelectionRegion;
begin
  if not fMapSelectionState.AreaValid then
    Abort;
  result.Area := fMapSelectionState.Area;
  if ShowOnlyActivePlane then
    result.Plane := EditLevel
  else
    result.Plane := -1;
end;

function tfrmViewer.GetThing( x, y, z : integer ) : tThing;
var
  Idx : integer;
begin
  result := nil;
  if fThingMap.Find( GetThingKey( x, y, z ), Idx ) then
    result := tThing (fThingMap.Objects[ Idx ] );
end;

function tfrmViewer.GetThingKey( x, y, z : integer ) : string;
begin
  result := IntToStr( z * Map.Width + x ) + '_';
  if y >= 0 then
    result := result + IntToStr( y );
end;

procedure tfrmViewer.GetThingsInBlock( x, y, z : integer; List : tList );
var
  Idx, KeyLength : integer;
  Key : string;
  Valid : boolean;
begin
  Valid := true;
  Key := GetThingKey( x, y, z );
  KeyLength := Length( Key );
  List.Clear;
  fThingMap.Find( Key, Idx );
  while ( Idx < fThingMap.Count ) and Valid do
  begin
    if Copy( fThingMap[ Idx ], 1, KeyLength ) = Key then
    begin
      List.Add( fThingMap.Objects[ Idx ] );
      inc( Idx );
    end
    else
      Valid := false;
  end;
end;

procedure tfrmViewer.GetThingsInBlock( Offset, y : integer; List : tList );
begin
  GetThingsInBlock( Offset mod Map.Width, y, Offset div Map.Width, List );
end;

Function tfrmViewer.GetWndPosition (X,Y,Z : Integer) : tPoint;
Var
  BlockSize : Integer;
Begin
  BlockSize:=GetBlockSize;
  With DirectionInfo Do
  Begin
    Case Direction Of
      DIR_NORTHWEST:
      Begin
        Result.X:=Size.Y + X - Y;
        Result.Y:=X + Y;
      End;
      DIR_NORTHEAST:
      Begin
        Result.X:=X + Y;
        Result.Y:=Size.Y - X + Y;
      End;
      DIR_SOUTHEAST:
      Begin
        Result.X:=Size.X - X + Y;
        Result.Y:=Size.X + Size.Y - X - Y;
      End;
      DIR_SOUTHWEST:
      Begin
        Result.X:=Size.X + Size.Y - X - Y;
        Result.Y:=Size.X + X - Y;
      End;
    End;

{   Original version - This bug must have been in here since 1999... Fixed 7/12/2007.
    Result.X:=(Result.X Shr 1) * BlockSize;
    Result.Y:=(Result.Y Shr 2) * BlockSize - (Z * BlockSize Shr 1) + GetColumnHeight;}

    Result.X := Result.X * BlockSize div 2;
    Result.Y:=(Result.Y * BlockSize div 4) - (Z * BlockSize Shr 1) + GetColumnHeight;
  End;
End;

procedure tfrmViewer.HandleMouseEvent( Button : tMouseButton; X, Y, EventCode : Integer );

function CalculateMapAddress( const MapPos : tPoint ) : pBlock;
var
  Offset : Cardinal;
begin
  Offset := ( MapPos.Y * Map.Width ) + MapPos.X;
  result := Map.BlockData;
  Inc( result, Offset );
end;

function UpdateMap( const MapPos : tPoint; pMap : pBlock ) : boolean;
var
  OldBlock, NewBlock : tBlock;
begin
  OldBlock := pMap^;
  NewBlock := OldBlock and not ( 3 shl ( EditLevel * 2 ) );
  If Button = mbLeft Then
    NewBlock := NewBlock Or ( Integer( fBlockType ) shl ( EditLevel * 2 ) );

  result := OldBlock <> NewBlock;
  if result then
  begin
    fSelectionHandler.PushBlockToUndoStack( Map, MapPos );
    pMap^ := NewBlock;
  end;
end;

function AddThing( const MapPos : tPoint; pMap : pBlock ) : boolean;

// Calculate direction to face, based on position relative to map centre
function CalculateQuadrant : integer;
var
  x1, y1, x2, yh : integer;
begin
  x1 := MapPos.X * Map.Height;
  y1 := MapPos.Y * Map.Width;
  x2 := Map.Width * Map.Width - x1 - Map.Width;
  yh := Map.Height div 2;

  if ( ( MapPos.Y < yh ) and ( x2 <= y1 ) ) or ( ( MapPos.Y >= yh ) and ( x2 < y1 ) ) then
    if x1 > y1 then
      result := 3    // West
    else
      result := 2    // North
  else
    if x1 >= y1 then
      result := 0    // South
    else
      result := 1;   // East
end;

var
  ThingInfo : tThingInfo;
begin
  result := false;
  if ( pMap^ and ( 3 shl ( EditLevel * 2 ) ) ) = 0 then    // Only allow things to be created in empty spaces
  begin
    with ThingInfo do
    begin
      Position.x := MapPos.x;
      Position.y := EditLevel;
      Position.z := MapPos.y;
      ThingType := Self.ThingType;
      Orientation := CalculateQuadrant * PI / 2;
      LevelMask := -1;
    end;

    with ThingInfo.Position do
      fThingMap.AddObject( GetThingKey( x, y, z ), Map.addThing( ThingInfo ) );

    ThingInfo.ThingType := tThingType( -1 );  // Indicate that it was added
    fSelectionHandler.PushThingToUndoStack( ThingInfo );

    result := true;
  end;
end;

function DeleteThing( Thing : tThing ) : boolean;
var
  Idx : integer;
begin
  fSelectionHandler.PushThingToUndoStack( Thing.Info );
  for Idx := 0 to fThingMap.Count - 1 do
    if fThingMap.Objects[ Idx ] = Thing then
    begin
      fThingMap.Delete( Idx );
      break;
    end;
  Map.deleteThing( Thing );
  result := true;
end;

function InspectThing( Thing : tThing ) : boolean;
var
  Info : tThingInfo;
begin
  Info := Thing.Info;
  with tfrmThing.Create( Self, Map, Thing ) do
    try
      result := ShowModal = mrOk;
      if result then
        fSelectionHandler.PushThingToUndoStack( Info );
    finally
      Free;
    end;
end;

Var
  MapPos : tPoint;
  ClipRect : tRect;
  pMap : pBlock;
  Thing : tThing;
  Redraw, MapPosValid, EarlyExit, RenderSelection : boolean;

Begin
  MapPos:=GetMapPosition(X,Y,EditLevel);
  MapPosValid := ( MapPos.x >= 0 ) and ( MapPos.x < Map.Width ) and ( MapPos.y >= 0 ) and ( MapPos.y < Map.Height );

  with fMapSelectionState do
  begin
    RenderSelection := false;
    EarlyExit := false;
    case EventCode of
      MOUSE_DOWN:
      begin
        EarlyExit := true;
        if not InDoubleClick then
        begin
          Include( Buttons, Button );
          if not Dragging then
          begin
            if AreaValid then
            begin
              ClipRect := BuildSelectionClipRect;
              RenderSelection := true;
              EarlyExit := false;
            end;
            DragTest := MapPosValid;
            StartValid := MapPosValid;
            Area.TopLeft := MapPos;
            AreaValid := false;
          end;
        end;
        InDoubleClick := false;
      end;
      MOUSE_MOVE:
      begin
        if ( Dragging and ( ( MapPos.x <> Area.Right ) or ( MapPos.y <> Area.Bottom ) ) )
          or ( DragTest and ( ( MapPos.x <> Area.Left ) or ( MapPos.y <> Area.Top ) ) ) then
        begin
          if Dragging then
            RenderDynamicSelection
          else
            SetCaptureControl( pbxRender );
          Area.BottomRight := MapPos;
          Dragging := true;
          DragTest := false;
          RenderDynamicSelection;
        end;
        EarlyExit := true;
      end;
      MOUSE_UP:
      begin
        Exclude( Buttons, Button );
        if Dragging then
        begin
          if Buttons = [] then
          begin
            SetCaptureControl( nil );
            RenderDynamicSelection;
            Area := NormaliseRectangle( Area );
            if Area.Left < 0 then Area.Left := 0;
            if Area.Top < 0 then Area.Top := 0;
            if Area.Right > Map.Width then Area.Right := Map.Width;
            if Area.Bottom > Map.Height then Area.Bottom := Map.Height;
            AreaValid := true;
            RenderSelection := true;
            Dragging := false;
          end
          else
            EarlyExit := true;
        end
        else
          EarlyExit := not StartValid;
        DragTest := false;
      end;
      MOUSE_DOUBLE_CLICK:
      begin
        Dragging := false;
        DragTest := false;
        InDoubleClick := true;
      end;
    end;
  end;

  if ( MapPosValid or RenderSelection ) and not EarlyExit then
  begin
    if MapPosValid then
    begin
      Thing := GetThing( MapPos.x, EditLevel, MapPos.y );
      pMap := CalculateMapAddress( MapPos );
    end
    else
    begin
      Thing := nil;
      pMap := nil;
    end;

    Redraw := false;
    case EventCode of
      MOUSE_DOUBLE_CLICK:
        if Thing <> nil then
        begin
          Redraw := InspectThing( Thing );
          if Redraw then
            ClipRect := BuildCellClipRect( MapPos );
        end;
      MOUSE_DOWN:
        Redraw := RenderSelection;
      MOUSE_UP:
      begin
        if not RenderSelection then
        begin
          if EditMode = EDIT_BLOCK then
          begin
            if Thing = nil then
              Redraw := UpdateMap( MapPos, pMap );
          end
          else
          begin
            if ( Thing = nil ) and ( Button = mbLeft ) then
              Redraw := AddThing( MapPos, pMap )
            else if ( Thing <> nil ) and ( Button = mbRight ) then
              Redraw := DeleteThing( Thing );
          end;
          if Redraw then
            ClipRect := BuildCellClipRect( MapPos );
        end
        else
        begin
          ClipRect := BuildSelectionClipRect;
          Redraw := true;
        end;
      end;
    end;

    If Redraw Then
    Begin
      InvalidateRect(Handle,@ClipRect,True);
      Dirty := Dirty or not RenderSelection;
      if EditMode = EDIT_BLOCK then
        Map.invalidateLightMaps;
      UpdateCaption;
      UpdateMenu;
    end;
  end;
end;

function tfrmViewer.IsPreview : boolean;
begin
  result := ( frmPreview <> nil ) and ( frmPreview.Map = Map );
end;

function tfrmViewer.IsPlaying : boolean;
begin
  result := ( frmGame <> nil ) and ( frmGame.Map = Map );
end;

function tfrmViewer.NormaliseRectangle( const Rect : tRect ) : tRect;
begin
  with Rect do
  begin
    if Left > Right then
    begin
      result.Left := Right;
      result.Right := Left;
    end
    else
    begin
      result.Left := Left;
      result.Right := Right;
    end;
    if Top > Bottom then
    begin
      result.Top := Bottom;
      result.Bottom := Top;
    end
    else
    begin
      result.Top := Top;
      result.Bottom := Bottom;
    end;
  end;

  inc( result.Right );
  inc( result.Bottom );
end;

Procedure tfrmViewer.PerformSave (Const NewFilename : String);
Begin
  if NewFilename = '' then
    Map.saveMap
  else
    Map.saveMap( NewFilename );
  fSelectionHandler.Context.ClearUndoStack;
  Dirty:=False;
  UpdateCaption;
End;

procedure tfrmViewer.PopulateThingMap;
var
  Idx : integer;
  Thing : tThing;
  ThingList : tList;
begin
  fThingMap.Clear;
  ThingList := tList.Create;
  try
    Map.getThings( ThingList );
    for Idx := 0 to ThingList.Count - 1 do
    begin
      Thing := tThing( ThingList[ Idx ] );
      with Thing.Info.Position do
        fThingMap.AddObject( GetThingKey( x, y, z ), Thing );
    end;
  finally
    ThingList.Free;
  end;
end;

procedure tfrmViewer.ProcessSelection( Command : tSelectionCommand; UpdateSelection, RequireSelection, FreeCommand : boolean );
var
  SelectionRegion : tSelectionRegion;
  OldClipRect, NewClipRect : tRect;
  HadSelection : boolean;
begin
  HadSelection := UpdateSelection and fMapSelectionState.AreaValid;
  if HadSelection then
    OldClipRect := BuildSelectionClipRect;

  if RequireSelection then
    SelectionRegion := GetSelectionRegion
  else
  begin
    SelectionRegion.Area := Rect( 0, 0, 1, 1 );
    SelectionRegion.Plane := -1;
  end;

  fSelectionHandler.ProcessSelection( Map, SelectionRegion, Command, FreeCommand );
  if UpdateSelection then
  begin
    fMapSelectionState.Area := SelectionRegion.Area;
    fMapSelectionState.AreaValid := true;
    NewClipRect := BuildSelectionClipRect;
    if HadSelection then
      InvalidateRect( Handle, @OldClipRect, true );
    InvalidateRect( Handle, @NewClipRect, true );
  end;

  UpdateMenu;

  Dirty := Dirty or ( fSelectionHandler.Context.GetUndoStackSize > 0 );

end;

procedure tfrmViewer.RenderDynamicSelection;
var
  Idx : integer;
  Vertex : array [ 0 .. 3 ] of tPoint;
begin
  with NormaliseRectangle( fMapSelectionState.Area ) do
  begin
    Vertex[ 0 ] := GetWndPosition( Left, Top, EditLevel );
    Vertex[ 1 ] := GetWndPosition( Right, Top, EditLevel );
    Vertex[ 2 ] := GetWndPosition( Right, Bottom, EditLevel );
    Vertex[ 3 ] := GetWndPosition( Left, Bottom, EditLevel );
  end;

  with pbxRender.Canvas do
  begin
    Pen.Color := clOlive;
    Pen.Style := psDot;
    Pen.Mode := pmXor;
    if Zoom > 1 then
      Pen.Width := 2
    else
      Pen.Width := 1;
    MoveTo( Vertex[ 3 ].x, Vertex[ 3 ].y );
    for Idx := 0 to 3 do
      LineTo( Vertex[ Idx ].x, Vertex[ Idx ].y );
    Pen.Mode := pmCopy;
  end;
end;

procedure tfrmViewer.RenderStaticSelection( DrawCanvas : tCanvas );
var
  Vertex : array [ 0 .. 3 ] of tPoint;
begin
  if fMapSelectionState.AreaValid then
  begin
    with fMapSelectionState.Area do
    begin
      Vertex[ 0 ] := GetWndPosition( Left, Top, MIN_EDIT_LEVEL );
      Vertex[ 1 ] := GetWndPosition( Right, Top, MIN_EDIT_LEVEL );
      Vertex[ 2 ] := GetWndPosition( Right, Bottom, MIN_EDIT_LEVEL );
      Vertex[ 3 ] := GetWndPosition( Left, Bottom, MIN_EDIT_LEVEL );
    end;

    with DrawCanvas do
    begin
      Pen.Style := psSolid;
      Pen.Color := clGreen;
      Pen.Width := 2;
      Brush.Style := bsSolid;
      Brush.Color := BlendColours( pbxRender.Color, SELECTION_COLOUR );
      Polygon( Vertex );
    end;
  end;
end;

Procedure tfrmViewer.RenderMap (DrawCanvas : tCanvas);
Var
  BlockSize, BlockHalf, BlockQtr : Integer;

procedure DrawLines( Canvas : tCanvas; Start, Finish, Perpendicular : tPoint; Factor : integer );
var
  Step : tPoint;
  Complete : boolean;
begin
  Step.x := ( Perpendicular.x - Start.x ) div Factor;
  Step.y := ( Perpendicular.y - Start.y ) div Factor;

  repeat
    Complete := Start.x = Perpendicular.x;
    Canvas.MoveTo( Start.x, Start.y );
    Canvas.LineTo( Finish.x, Finish.y );
    inc( Start.x, Step.x );
    inc( Start.y, Step.y );
    inc( Finish.x, Step.x );
    inc( Finish.Y, Step.y );
  until Complete;
end;

Procedure DrawBorder;
Var
  North, East, South, West : tPoint;

procedure GetCompassPoints( y : integer );
begin
  North:=GetWndPosition(0,0,y);
  East:=GetWndPosition(Map.Width,0,y);
  South:=GetWndPosition(Map.Width,Map.Height,y);
  West:=GetWndPosition(0,Map.Height,y);
end;

Begin
  With DrawCanvas Do
  Begin
    Pen.Color:=clGreen;
    Pen.Style := psSolid;
    Pen.Mode := pmCopy;
    Pen.Width:=2;
    GetCompassPoints( 0 );
    MoveTo(North.X,North.Y);
    LineTo(East.X,East.Y);
    LineTo(South.X,South.Y);
    LineTo(West.X,West.Y);
    LineTo(North.X,North.Y);

    if ShowGrid then
    begin
      Pen.Color := clGray;
      Pen.Width := 1;
      DrawLines( DrawCanvas, North, West, East, Map.Width );
      DrawLines( DrawCanvas, West, South, North, Map.Height );
    end;
  End;
End;

Procedure Initialise;
Var
  Block : tBitmap;
Begin
  Block:=BlockGfx[Zoom,BLOCK_SOLID,BLOCK_IMAGE];
  BlockSize:=Block.Width;
  BlockHalf:=BlockSize Shr 1;
  BlockQtr:=BlockHalf Shr 1;
End;

Procedure Render (Const BoundRect : tRect);
Var
  BlockRenderInfo : tBlockRenderInfo;
  pScan : pScanLine;
  pMap : pBlock;
  pMapStart : pBlock;
  BlockPos : tPoint;
  Offset : integer;
  SX, SY, X, Y, Diff, LimitLevel : Integer;
  Block, Mask : tBlock;

Begin
  with BlockRenderInfo do
  begin
    Canvas := DrawCanvas;
    ZoomLevel := fZoom;
    EditLevel := Self.EditLevel;
    CameraDirection := Direction;
    Grid := ShowGrid;
    ThingList := tList.Create;
  end;
  try
    if ShowOnlyActivePlane then
    begin
      Mask := 3 shl ( EditLevel * 2 );
      LimitLevel := EditLevel;
    end
    else
    begin
      Mask := tBlock( -1 );
      LimitLevel := -1;
    end;
    pMapStart := Map.BlockData;
    pScan:=ScanBuffer;
    SY:=BoundRect.Top * BlockQtr;
    Inc(pScan,BoundRect.Top);
    For Y:=BoundRect.Top To BoundRect.Bottom Do
    Begin
      pMap:=pScan^.MapAddr;
      If pMap <> Nil Then
      Begin
        SX:=pScan^.Offset;
        X:=pScan^.Length;
        Diff:=(BoundRect.Left - SX) Div 2;
        If Diff > 0 Then
        Begin
          Dec(X,Diff);
          Inc(pMap,Diff * pScan^.Delta);
          Inc(SX,Diff Shl 1);
        End;
        Diff:=BoundRect.Right - SX;
        If Diff < X Then
          X:=Diff;
        SX:=SX * BlockHalf;
        While X > 0 Do
        Begin
          Offset := ( Integer( pMap ) - Integer( pMapStart ) ) div SizeOf( tBlock );
          BlockPos.x := Offset mod Map.Width;
          BlockPos.y := Offset div Map.Width;
          GetThingsInBlock( BlockPos.x, LimitLevel, BlockPos.y, BlockRenderInfo.ThingList );
          Block := pMap^ and Mask;
          If ( Block <> 0 ) or ( BlockRenderInfo.ThingList.Count > 0 ) Then
          begin
            BlockRenderInfo.x := SX;
            BlockRenderInfo.y := SY;
            BlockRenderInfo.Bitmask := Block;
            BlockRenderInfo.Selected := fMapSelectionState.AreaValid and PtInRect( fMapSelectionState.Area, BlockPos );
            DrawMapBlock( BlockRenderInfo );
          end;
          Inc(SX,BlockSize);
          Inc(pMap,pScan^.Delta);
          Dec(X);
        End;
      End;
      Inc(pScan);
      Inc(SY,BlockQtr);
    End;
  finally
    BlockRenderInfo.ThingList.Free;
  end;
End;

Function GetBoundRect : tRect;
Begin
  Result:=DrawCanvas.ClipRect;
  With Result Do
  Begin
    Left:=Left Div BlockHalf;
    If Left > 0 Then
      Dec(Left);
    Top:=Top Div BlockQtr;
    If Top >= BlockQtr Then
      Dec(Top,BlockQtr);
    Right:=(Right Div BlockHalf) + 1;
    Bottom:=(Bottom Div BlockQtr) + 16;
    If Bottom >= ScanLimit Then
      Bottom:=ScanLimit - 1;
  End;
End;

Begin
  If Assigned(Map) Then
  Begin
    Initialise;
    RenderStaticSelection( DrawCanvas );
    DrawBorder;
    Render(GetBoundRect);
  End;
End;

procedure tfrmViewer.SetBlockType( aBlockType : tBlockType );
begin
  fBlockType := aBlockType;
  fEditMode := EDIT_BLOCK;
  UpdateCaption;
end;

Procedure tfrmViewer.SetCamera (MapPos : tPoint);
Var
  WndPos : tPoint;
Begin
  WndPos:=GetWndPosition(MapPos.X,MapPos.Y,0);
  HorzScrollBar.Position:=WndPos.X - (ClientWidth Shr 1);
  VertScrollBar.Position:=WndPos.Y - (ClientHeight Shr 1);
End;

Procedure tfrmViewer.SetDirection (aDirection : tDirection);
Var
  Camera : tPoint;
Begin
  If aDirection <> fDirection Then
  Begin
    Camera:=GetCamera;
    fDirection:=aDirection;
    UpdateDirectionInfo;
    BuildScanBuffer;
    SetCamera(Camera);
    UpdateCaption;
    Invalidate;
  End;
End;

procedure tfrmViewer.SetDirty( aDirty : boolean );
begin
  fDirty := aDirty;
  UpdateCaption;
end;

Procedure tfrmViewer.SetEditLevel (aEditLevel : Integer);
Begin
  If (aEditLevel <> fEditLevel) And (aEditLevel >= MIN_EDIT_LEVEL) And (aEditLevel <= MAX_EDIT_LEVEL) Then
  Begin
    fEditLevel:=aEditLevel;
    InvalidateRect(Handle,Nil,ShowOnlyActivePlane);
    UpdateMenu;
  End;
End;

procedure tfrmViewer.SetShowGrid( aShowGrid : boolean );
begin
  if aShowGrid <> fShowGrid then
  begin
    fShowGrid := aShowGrid;
    InvalidateRect( Handle, Nil, True );
    UpdateMenu;
  end;
end;

procedure tfrmViewer.SetShowOnlyActivePlane( aShowOnlyActivePlane : boolean );
begin
  if aShowOnlyActivePlane <> fShowOnlyActivePlane then
  begin
    fShowOnlyActivePlane := aShowOnlyActivePlane;
    Invalidate;
    UpdateMenu;
  end;
end;

procedure tfrmViewer.SetThingType( aThingType : tThingType );
begin
  fThingType := aThingType;
  fEditMode := EDIT_THING;
  UpdateCaption;
end;

Procedure tfrmViewer.SetZoom (aZoom : Integer);
Var
  Camera : tPoint;
Begin
  If (aZoom <> fZoom) And (aZoom > 0) And (aZoom <= BLOCK_COUNT) Then
  Begin
    Camera:=GetCamera;
    fZoom:=aZoom;
    CalculateWindow;
    SetCamera(Camera);
    UpdateMenu;
  End;
End;

Procedure tfrmViewer.UpdateDirectionInfo;

Procedure SetValue (Var Value : Integer; Offset : Integer);
Begin
  If Value > 0 Then
    Value:=Map.Width + Offset
  Else
  If Value < 0 Then
    Value:=Map.Height + Offset;
End;

Begin
  DirectionInfo:=MasterDirectionInfo[Direction];
  With DirectionInfo Do
  Begin
    SetValue(Origin.X,-1);
    SetValue(Origin.Y,-1);
    SetValue(Size.X,0);
    SetValue(Size.Y,0);
    If Abs(Delta.X) > 1 Then
      Delta.X:=Map.Width * Delta.X Div Abs(Delta.X);
    If Abs(Delta.Y) > 1 Then
      Delta.Y:=Map.Width * Delta.Y Div Abs(Delta.Y);
  End;
End;

(* Protected Methods *)

procedure tfrmViewer.UpdateMenu;
begin
  tfrmMain( Owner ).UpdateMenu;
end;

(* Public Methods *)

procedure tfrmViewer.CopySelection;
begin
  ProcessSelection( tCopyCommand.Create, false );
end;

procedure tfrmViewer.ClearSelection;
begin
  HandleMouseEvent( mbMiddle, 0, 0, MOUSE_DOWN );
  HandleMouseEvent( mbMiddle, 0, 0, MOUSE_UP );
end;

procedure tfrmViewer.CutSelection;
begin
  CopySelection;
  DeleteSelection;
end;

procedure tfrmViewer.DeleteSelection;
begin
  ProcessSelection( tDeleteCommand.Create, true );
end;

procedure tfrmViewer.ExportMap;
begin
  with tfrmExport.create( Self, Map ) do
    try
      if ShowModal = mrOk then
        Map.exportMap( GetFilename, GetExportOptions );
    finally
      free;
    end;
end;

procedure tfrmViewer.LowerSelection;
begin
  ProcessSelection( tShiftCommand.Create( false ) );
end;

Procedure tfrmViewer.MapSizeChange;
Begin
  fSelectionHandler.Context.ClearUndoStack;
  UpdateDirectionInfo;
  PopulateThingMap;
  BuildScanBuffer;
  CalculateWindow;
  if IsPreview then
    frmPreview.Map := Map;
  if IsPlaying then
    frmGame.Map := Map;
End;

procedure tfrmViewer.PasteSelection;
begin
  ProcessSelection( tPasteCommand.Create );
end;

procedure tfrmViewer.RaiseSelection;
begin
  ProcessSelection( tShiftCommand.Create( true ) );
end;

procedure tfrmViewer.RememberMap;
begin
  ProcessSelection( tRememberMapCommand.Create, false, false );
end;

Procedure tfrmViewer.Save;
var
  Attributes : integer;
Begin
  Attributes := FileGetAttr( Map.Filename );
  if Attributes = -1 then
    Attributes := 0;

  If ( Length(Map.Filename) = 0 ) or ( ( Attributes and faReadOnly ) = faReadOnly ) Then
    SaveAs
  Else
    PerformSave(Map.Filename);
End;

Procedure tfrmViewer.SaveAs;
Begin
  dlgSave.Filename:=Map.Filename;
  If dlgSave.Execute Then
    PerformSave(dlgSave.Filename)
  Else
    Abort;
End;

procedure tfrmViewer.SelectAll;
begin
  ClearSelection;
  fMapSelectionState.Area := Rect( 0, 0, Map.Width, Map.Height );
  fMapSelectionState.AreaValid := true;
  InvalidateRect( Handle, nil, true );
  UpdateMenu;
end;

procedure tfrmViewer.UndoAction;
var
  Command : tUndoCommand;
begin
  Command := tUndoCommand.Create;
  try
    ProcessSelection( Command, true, false, false );
    if not Command.IsBlockData then
      PopulateThingMap;
  finally
    Command.Free;
  end;
end;

Procedure tfrmViewer.UpdateCaption;
var
  Title : string;
Begin
  if Assigned(Map) then
  begin
    Title := Map.Header^.Title;
    if Dirty then Title := Title + '*';
    Caption:=Title + ' - Looking ' + DirectionInfo.Desc + ', Placing ' + IfThen( EditMode = EDIT_BLOCK, BlockTypeName[ fBlockType ], ThingTypeName[ fThingType ] );
    if isPreview then
      frmPreview.UpdateCaption;
    if isPlaying then
      frmGame.UpdateCaption;
  end;
End;

(* Destructor *)

Destructor tfrmViewer.Destroy;
Begin
  if IsPreview then
    frmPreview.Close;
  if IsPlaying then
    frmGame.Close;
  FreeAndNil( cMap );
  If Assigned(ScanBuffer) Then
    FreeMem(ScanBuffer);
  fSelectionHandler.Free;
  fMapSelectionState.Free;
  fThingMap.Free;
  Inherited Destroy;
End;

End.
