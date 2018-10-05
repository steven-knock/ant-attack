Unit Main;

Interface

Uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, Menus, Viewer, ImgList, ComCtrls, ToolWin, StdCtrls, GameLog;

Type
  tfrmMain = Class(tForm)
    menMain: TMainMenu;
    mitFile: TMenuItem;
    mitNew: TMenuItem;
    mitOpen: TMenuItem;
    mitSave: TMenuItem;
    mitSaveAs: TMenuItem;
    mitExport: TMenuItem;
    mitClose: TMenuItem;
    mitExit: TMenuItem;
    mitEdit: TMenuItem;
    mitCut: TMenuItem;
    mitCopy: TMenuItem;
    mitPaste: TMenuItem;
    mitDelete: TMenuItem;
    mitProperties: TMenuItem;
    mitSep1: TMenuItem;
    mitSep2: TMenuItem;
    mitSep3: TMenuItem;
    mitSep4: TMenuItem;
    mitSep5: TMenuItem;
    mitSep7: TMenuItem;
    mitSep8: TMenuItem;
    mitWindow: TMenuItem;
    mitTile: TMenuItem;
    mitCascade: TMenuItem;
    mitArrange: TMenuItem;
    dlgOpen: TOpenDialog;
    mitZoomIn: TMenuItem;
    mitZoomOut: TMenuItem;
    mitPerimeter: TMenuItem;
    mitPlaneUp: TMenuItem;
    mitPlaneDown: TMenuItem;
    mitPlaneFirst: TMenuItem;
    mitPlaneLast: TMenuItem;
    mitRotateFore: TMenuItem;
    mitRotateBack: TMenuItem;
    mitUndo: TMenuItem;
    mitPreview: TMenuItem;
    mitSep9: TMenuItem;
    mitAbout: TMenuItem;
    mitPlay: TMenuItem;
    mitLevels: TMenuItem;
    barToolbar: TToolBar;
    btnNew: TToolButton;
    imgToolBar: TImageList;
    btnOpen: TToolButton;
    btnSave: TToolButton;
    btnSep1: TToolButton;
    btnUndo: TToolButton;
    btnCut: TToolButton;
    btnCopy: TToolButton;
    btnPaste: TToolButton;
    btnDelete: TToolButton;
    btnSep2: TToolButton;
    btnSep3: TToolButton;
    btnZoomIn: TToolButton;
    btnZoomOut: TToolButton;
    btnSep4: TToolButton;
    btnPlaneFirst: TToolButton;
    btnPlaneUp: TToolButton;
    btnPlaneDown: TToolButton;
    btnPlaneLast: TToolButton;
    btnSep6: TToolButton;
    btnRotateFore: TToolButton;
    btnRotateBack: TToolButton;
    btnSep7: TToolButton;
    btnProperties: TToolButton;
    btnPreview: TToolButton;
    btnPlay: TToolButton;
    bntSep9: TToolButton;
    btnCube: TToolButton;
    btnPillar: TToolButton;
    btnWater: TToolButton;
    btnSpawnThing: TToolButton;
    btnRescueeThing: TToolButton;
    btnStartThing: TToolButton;
    btnSep10: TToolButton;
    btnAbout: TToolButton;
    mitShowOnlyActivePlane: TMenuItem;
    btnShowOnlyActivePlane: TToolButton;
    mitSep6: TMenuItem;
    mitShowGrid: TMenuItem;
    btnShowGrid: TToolButton;
    btnSep5: TToolButton;
    mitTools: TMenuItem;
    mitRaise: TMenuItem;
    mitLower: TMenuItem;
    btnRaise: TToolButton;
    btnLower: TToolButton;
    btnSep8: TToolButton;
    mitSelectAll: TMenuItem;
    btnSelectAll: TToolButton;
    btnLevels: TToolButton;
    btnPerimeter: TToolButton;
    mitUserGuide: TMenuItem;
    mitHelp: TMenuItem;
    btnUserGuide: TToolButton;
    Procedure FormActivate (Sender : tObject);
    procedure btnCubeClick( Sender : tObject );
    procedure btnPillarClick( Sender : tObject );
    procedure btnRescueeThingClick(Sender: TObject);
    procedure btnSpawnThingClick(Sender: TObject);
    procedure btnStartThingClick(Sender: TObject);
    procedure btnWaterClick( Sender : tObject );
    procedure mitAboutClick( Sender : tObject );
    Procedure mitArrangeClick (Sender : tObject);
    Procedure mitCascadeClick (Sender : tObject);
    Procedure mitCloseClick (Sender : tObject);
    procedure mitCopyClick( Sender : tObject );
    procedure mitCutClick(Sender: TObject);
    procedure mitDeleteClick(Sender: TObject);
    Procedure mitExitClick (Sender : tObject);
    procedure mitExportClick( Sender : tObject );
    procedure mitLevelsClick(Sender: TObject);
    procedure mitLowerClick( Sender : tObject );
    Procedure mitNewClick (Sender : tObject);
    Procedure mitOpenClick (Sender : tObject);
    procedure mitPasteClick( Sender : tObject );
    Procedure mitPlaneDownClick (Sender : tObject);
    Procedure mitPlaneFirstClick (Sender : tObject);
    Procedure mitPlaneLastClick (Sender : tObject);
    Procedure mitPlaneUpClick (Sender : tObject);
    Procedure mitPerimeterClick (Sender : tObject);
    procedure mitPlayClick( Sender : tObject );
    procedure mitPreviewClick( Sender : tObject );
    Procedure mitPropertiesClick (Sender : tObject);
    procedure mitRaiseClick( Sender : tObject );
    Procedure mitRotateBackClick (Sender : tObject);
    Procedure mitRotateForeClick (Sender : tObject);
    Procedure mitSaveClick( Sender : tObject );
    Procedure mitSaveAsClick( Sender : tObject );
    procedure mitSelectAllClick(Sender: TObject);
    procedure mitShowGridClick(Sender: TObject);
    procedure mitShowOnlyActivePlaneClick(Sender: TObject);
    Procedure mitTileClick( Sender : tObject );
    procedure mitUndoClick(Sender: TObject);
    Procedure mitZoomInClick( Sender : tObject );
    Procedure mitZoomOutClick( Sender : tObject );
    procedure mitUserGuideClick(Sender: TObject);
  Private
    frmGameLog : tfrmGameLog;
    NextMapID : Integer;
    Function CurrentChild : tfrmViewer;
    function GetAdjustedClientRect : tRect;
    Procedure WMInitMenu (Var Msg : tMessage); Message WM_INITMENU;
    Function MapWindow (Idx : Integer) : tfrmViewer;
    Procedure OpenMap (Const aFilename : String);
  Public
    Constructor Create (aOwner : tComponent); Override;
    Destructor Destroy; Override;
    Procedure  UpdateMenu;
    property   AdjustedClientRect : tRect read GetAdjustedClientRect;
  End;

Var
  frmMain : tfrmMain;

Implementation

Uses
  About, Common, Game, LevelDetail, Map, MapProp, Perimetr, Preview, Resource, Things, GLHelp, ShellAPI;

{$R *.DFM}

(* Constructor *)

Constructor tfrmMain.Create (aOwner : tComponent);
Begin
  Inherited Create(aOwner);
  frmPreview := nil;
  mitPlaneUp.ShortCut:=ShortCut(VK_ADD,[]);
  mitPlaneDown.ShortCut:=ShortCut(VK_SUBTRACT,[]);
  mitPlaneFirst.ShortCut:=ShortCut(VK_ADD,[ssCtrl]);
  mitPlaneLast.ShortCut:=ShortCut(VK_SUBTRACT,[ssCtrl]);
  mitRotateFore.ShortCut:=ShortCut(VK_TAB,[]);
  mitRotateBack.ShortCut:=ShortCut(VK_TAB,[ssShift]);
End;

(* Events *)

Procedure tfrmMain.FormActivate (Sender : tObject);

procedure PrepareGameLog;
begin
  frmGameLog := tfrmGameLog.Create( Self );
  frmGameLog.Top := Screen.WorkAreaRect.Top;
  frmGameLog.Height := Screen.WorkAreaRect.Bottom - Screen.WorkAreaRect.Top;
  frmGameLog.Left := Screen.WorkAreaRect.Right - frmGameLog.Width;
end;

Const
  First : Boolean = True;
Var
  PIdx, Result : Integer;
  SearchRec : tSearchRec;
Begin
  If First Then
  Begin
    First:=False;
    WindowState := wsMaximized;
    If ParamCount <> 0 Then
    Begin
      For PIdx:=1 To ParamCount Do
      Begin
        Result:=FindFirst(ParamStr(PIdx),faReadOnly,SearchRec);
        Try
          While Result = 0 Do
          Begin
            OpenMap(ExtractFilePath(ParamStr(PIdx)) + SearchRec.Name);
            Result:=FindNext(SearchRec);
          End;
        Finally
          FindClose(SearchRec);
        End;
      End;
    End;
    PrepareGameLog;
  End;
  UpdateMenu;
End;

procedure tfrmMain.btnCubeClick( Sender : tObject );
begin
  CurrentChild.BlockType := BLOCK_SOLID;
end;

procedure tfrmMain.btnPillarClick( Sender : tObject );
begin
  CurrentChild.BlockType := BLOCK_PILLAR;
end;

procedure tfrmMain.btnRescueeThingClick(Sender: TObject);
begin
  CurrentChild.ThingType := THING_RESCUEE;
end;

procedure tfrmMain.btnSpawnThingClick(Sender: TObject);
begin
  CurrentChild.ThingType := THING_SPAWN;
end;

procedure tfrmMain.btnStartThingClick(Sender: TObject);
begin
  CurrentChild.ThingType := THING_START;
end;

procedure tfrmMain.btnWaterClick( Sender : tObject );
begin
  CurrentChild.BlockType := BLOCK_WATER;
end;

procedure tfrmMain.mitAboutClick( Sender : tObject );
begin
  if frmAbout = nil then
    frmAbout := tfrmAbout.create( Self );
end;

Procedure tfrmMain.mitArrangeClick (Sender : tObject);
Begin
  ArrangeIcons;                                             
End;

Procedure tfrmMain.mitCascadeClick (Sender : tObject);
Begin
  Cascade;
End;

procedure tfrmMain.mitCopyClick( Sender : tObject );
begin
  CurrentChild.CopySelection;
end;

procedure tfrmMain.mitCutClick(Sender: TObject);
begin
  CurrentChild.CutSelection;
end;

procedure tfrmMain.mitDeleteClick(Sender: TObject);
begin
  CurrentChild.DeleteSelection;
end;

Procedure tfrmMain.mitExitClick (Sender : tObject);
Var
  Idx : Integer;
Begin
  For Idx:=0 To MDIChildCount - 1 Do
    MapWindow(Idx).Close;
  Close;
End;

procedure tfrmMain.mitExportClick( Sender : tObject );
begin
  CurrentChild.ExportMap;
end;

Procedure tfrmMain.mitCloseClick (Sender : tObject);
Begin
  while MDIChildCount > 0 do
    CurrentChild.Close;
End;

procedure tfrmMain.mitLevelsClick( Sender : tObject );
begin
  with tfrmLevelDetail.Create( self, CurrentChild.Map ) do
    try
      if ShowModal = mrOk then
        CurrentChild.Dirty := true;
    finally
      Free;
    end;
end;

procedure tfrmMain.mitLowerClick( Sender : tObject );
begin
  CurrentChild.LowerSelection;
end;

procedure tfrmMain.mitPasteClick( Sender : tObject );
begin
  CurrentChild.PasteSelection;
end;

Procedure tfrmMain.mitPlaneDownClick (Sender : tObject);
Begin
  CurrentChild.EditLevel:=CurrentChild.EditLevel - 1;
  UpdateMenu;
End;

Procedure tfrmMain.mitPlaneFirstClick (Sender : tObject);
Begin
  CurrentChild.EditLevel:=7;
  UpdateMenu;
End;

Procedure tfrmMain.mitPlaneLastClick (Sender : tObject);
Begin
  CurrentChild.EditLevel:=0;
  UpdateMenu;
End;

Procedure tfrmMain.mitPlaneUpClick (Sender : tObject);
Begin
  CurrentChild.EditLevel:=CurrentChild.EditLevel + 1;
  UpdateMenu;
End;

procedure tfrmMain.mitPlayClick( Sender : tObject );
begin
  if frmGame = nil then
  begin
    try
      frmGame := tfrmGame.Create( Self, CurrentChild.Map, frmGameLog.Log );
    except
      on e : Exception do
      begin
        frmGameLog.Log.Add( 'Error during game creation: ' + e.Message );
        frmGameLog.Show;
        raise;
      end;
    end;
  end
  else
  begin
    frmGame.Show;
    frmGameLog.Show;
  end;
end;

Procedure tfrmMain.mitPreviewClick (Sender : tObject);
Begin
  if frmPreview = nil then
    frmPreview := tfrmPreview.Create(Self,CurrentChild.Map)
  else
    frmPreview.Show;
End;

Procedure tfrmMain.mitNewClick (Sender : tObject);
Var
  Header : tMapHeader;
  Map : Pointer;
Begin
  FillChar( Header, SizeOf( Header ), 0 );
  With Header Do
  Begin
    StrPCopy(Title,'Map ' + IntToStr(NextMapID + 1));
    Width:=MAP_SIZE_DEF;
    Height:=MAP_SIZE_DEF;
    HitPoints:=OPT_DEF_HITPOINTS;
    Grenades:=OPT_DEF_GRENADES;
    AntHitPoints:=OPT_DEF_ANT_HITPOINTS;
    Levels:=OPT_DEF_LEVELS;
    Palette[PAL_GROUND].rgba:=PAL_DEF_GROUND;
    Palette[PAL_LIGHT].rgba:=PAL_DEF_LIGHT;
    Palette[PAL_WATER].rgba:=PAL_DEF_WATER;
    Palette[PAL_DARK].rgba:=PAL_DEF_DARK;
  End;
  With tfrmProperties.CreateMap(Self,@Header) Do
    Try
      If ShowModal = mrOk Then
      Begin
        Inc(NextMapID);
        Map := tMap.create( Header );
        tfrmViewer.Create( Self, Map );
      End;
    Finally
      Free;
    End;
End;

Procedure tfrmMain.mitOpenClick (Sender : tObject);
Begin
  dlgOpen.Filename:='';
  If dlgOpen.Execute Then
    OpenMap(dlgOpen.Filename);
End;

Procedure tfrmMain.mitPerimeterClick (Sender : tObject);
Begin
  With CurrentChild, tfrmPerimeter.Create(Self) Do
    Try
      If (ShowModal = mrOk) And (MessageDlg('Are you sure that you want to apply this wall design to the perimiter of this level?',mtConfirmation,[mbYes,mbNo],0) = mrYes) Then
      Begin
        CurrentChild.RememberMap;
        CreatePerimeter(Map);
        CurrentChild.Repaint;
        CurrentChild.Dirty:=True;
      End;
    Finally
      Free;
    End;
End;

Procedure tfrmMain.mitPropertiesClick (Sender : tObject);
Var
  Map : tMap;
  TempMap : tMapHeader;
Begin
  Map := CurrentChild.Map;
  Move( Map.Header^, TempMap, SizeOf( TempMap ) );
  With tfrmProperties.CreateMap( Self, @TempMap ) Do
    Try
      If ShowModal = mrOk Then
        With CurrentChild Do
        Begin
          UpdateCaption;
          If (TempMap.Width <> Map.Width) Or (TempMap.Height <> Map.Height) Then
          Begin
            Map.resize( TempMap.Width, TempMap.Height );
            MapSizeChange;
            ClearSelection;
          End;
          Move( TempMap, Map.Header^, SizeOf( TempMap ) );
          Dirty:=True;
        End;
    Finally
      Free;
    End;
End;

procedure tfrmMain.mitRaiseClick( Sender : tObject );
begin
  CurrentChild.RaiseSelection;
end;

Procedure tfrmMain.mitRotateBackClick (Sender : tObject);
Begin
  With CurrentChild Do
    If Direction = Low(Direction) Then
      Direction:=High(Direction)
    Else
      Direction:=Pred(Direction);
End;

Procedure tfrmMain.mitRotateForeClick (Sender : tObject);
Begin
  With CurrentChild Do
    If Direction = High(Direction) Then
      Direction:=Low(Direction)
    Else
      Direction:=Succ(Direction);
End;

Procedure tfrmMain.mitSaveClick (Sender : tObject);
Begin
  CurrentChild.Save;
End;

Procedure tfrmMain.mitSaveAsClick (Sender : tObject);
Begin
  CurrentChild.SaveAs;
End;

procedure tfrmMain.mitSelectAllClick(Sender: TObject);
begin
  CurrentChild.SelectAll;
end;

procedure tfrmMain.mitShowGridClick(Sender: TObject);
begin
  CurrentChild.ShowGrid := not CurrentChild.ShowGrid;
end;

procedure tfrmMain.mitShowOnlyActivePlaneClick(Sender: TObject);
begin
  CurrentChild.ShowOnlyActivePlane := not CurrentChild.ShowOnlyActivePlane;
end;

Procedure tfrmMain.mitTileClick (Sender : tObject);
Begin
  Tile;
End;

procedure tfrmMain.mitUndoClick(Sender: TObject);
begin
  CurrentChild.UndoAction;
end;

procedure tfrmMain.mitUserGuideClick(Sender: TObject);
var
  HelpFileName : string;
begin
  HelpFileName := ExtractFilePath( Application.EXEName ) + FILE_USER_GUIDE;
  if ShellExecute( Handle, nil, pChar( HelpFileName ), nil, nil, SW_SHOW ) <= 32 then
    MessageDlg( 'Unable to open help file: ' + HelpFileName, mtInformation, [ mbOk ], 0 );  
end;

Procedure tfrmMain.mitZoomInClick (Sender : tObject);
Begin
  CurrentChild.Zoom:=CurrentChild.Zoom + 1;
  UpdateMenu;
End;

Procedure tfrmMain.mitZoomOutClick (Sender : tObject);
Begin
  CurrentChild.Zoom:=CurrentChild.Zoom - 1;
  UpdateMenu;
End;

(* Private Methods *)

Function tfrmMain.CurrentChild : tfrmViewer;
var
  cForm : tForm;
Begin
  cForm := activeMDIChild;
  if ( cForm = nil ) or not ( cForm is tfrmViewer ) then
    abort;
  result := tfrmViewer( cForm )
End;

function tfrmMain.GetAdjustedClientRect : tRect;
begin
  result := ClientRect;
  AdjustClientRect( result );
end;

Procedure tfrmMain.WMInitMenu (Var Msg : tMessage);
Begin
  UpdateMenu;
End;

Function tfrmMain.MapWindow (Idx : Integer) : tfrmViewer;
Begin
  Result:=MDIChildren[Idx] As tfrmViewer;
End;

Procedure tfrmMain.OpenMap (Const aFilename : String);
var
  NewMap : tMap;
Begin
  NewMap := tMap.create( aFilename );
  Try
    With tfrmViewer.Create( Self, NewMap ) Do
      UpdateMenu;
  Except
    FreeAndNil( NewMap );
    Raise;
  End;
End;

Procedure tfrmMain.UpdateMenu;
Var
  MenuState : tMenuState;
  ValidChild : Boolean;

Function Check (MenuItem : tMenuItems) : Boolean;
Begin
  Result:=MenuItem In MenuState;
End;

Begin
  Try
    MenuState:=CurrentChild.MenuState;
    ValidChild:=True;
  Except
    MenuState:=[];
    ValidChild:=False;
  End;
  mitUndo.Enabled:=Check(MS_UNDO);
  mitSelectAll.Enabled:=ValidChild;
  mitCut.Enabled:=Check(MS_CUT);
  mitCopy.Enabled:=Check(MS_COPY);
  mitPaste.Enabled:=Check(MS_PASTE);
  mitDelete.Enabled:=Check(MS_DELETE);
  mitZoomIn.Enabled:=Check(MS_ZOOMIN);
  mitZoomOut.Enabled:=Check(MS_ZOOMOUT);
  mitPlaneFirst.Enabled:=Check(MS_PLANEFIRST);
  mitPlaneUp.Enabled:=Check(MS_PLANEUP);
  mitPlaneDown.Enabled:=Check(MS_PLANEDOWN);
  mitPlaneLast.Enabled:=Check(MS_PLANELAST);
  mitShowGrid.Enabled:=ValidChild;
  mitShowGrid.Checked:=ValidChild and CurrentChild.ShowGrid;
  mitShowOnlyActivePlane.Enabled:=ValidChild;
  mitShowOnlyActivePlane.Checked:=ValidChild and CurrentChild.ShowOnlyActivePlane;
  mitSave.Enabled:=ValidChild;
  mitSaveAs.Enabled:=ValidChild;
  mitExport.Enabled:=ValidChild;
  mitClose.Enabled:=ValidChild;
  mitRotateFore.Enabled:=ValidChild;
  mitRotateBack.Enabled:=ValidChild;
  mitRaise.Enabled:=Check(MS_RAISE);
  mitLower.Enabled:=Check(MS_LOWER);
  mitLevels.Enabled:=ValidChild;
  mitPerimeter.Enabled:=ValidChild;
  mitProperties.Enabled:=ValidChild;
  mitPreview.Enabled:=ValidChild;
  mitPlay.Enabled:=ValidChild;
  mitAbout.Enabled:=frmAbout = nil;

  btnUndo.Enabled:=mitUndo.Enabled;
  btnSelectAll.Enabled:=mitSelectAll.Enabled;
  btnCut.Enabled:=mitCut.Enabled;
  btnCopy.Enabled:=mitCopy.Enabled;
  btnPaste.Enabled:=mitPaste.Enabled;
  btnDelete.Enabled:=mitDelete.Enabled;
  btnZoomIn.Enabled:=mitZoomIn.Enabled;
  btnZoomOut.Enabled:=mitZoomOut.Enabled;
  btnPlaneFirst.Enabled:=mitPlaneFirst.Enabled;
  btnPlaneUp.Enabled:=mitPlaneUp.Enabled;
  btnPlaneDown.Enabled:=mitPlaneDown.Enabled;
  btnPlaneLast.Enabled:=mitPlaneLast.Enabled;
  btnShowGrid.Enabled:=mitShowGrid.Enabled;
  btnShowGrid.Down:=mitShowGrid.Checked;
  btnShowOnlyActivePlane.Enabled:=mitShowOnlyActivePlane.Enabled;
  btnShowOnlyActivePlane.Down:=mitShowOnlyActivePlane.Checked;
  btnSave.Enabled:=mitSave.Enabled;
  btnRotateFore.Enabled:=mitRotateFore.Enabled;
  btnRotateBack.Enabled:=mitRotateBack.Enabled;
  btnRaise.Enabled:=mitRaise.Enabled;
  btnLower.Enabled:=mitLower.Enabled;
  btnLevels.Enabled:=mitLevels.Enabled;
  btnPerimeter.Enabled:=mitPerimeter.Enabled;
  btnProperties.Enabled:=mitProperties.Enabled;
  btnCube.Enabled:=ValidChild;
  btnPillar.Enabled:=ValidChild;
  btnWater.Enabled:=ValidChild;
  btnSpawnThing.Enabled:=ValidChild;
  btnRescueeThing.Enabled:=ValidChild;
  btnStartThing.Enabled:=ValidChild;
  btnPreview.Enabled:=mitPreview.Enabled;
  btnPlay.Enabled:=mitPlay.Enabled;
  btnAbout.Enabled:=mitAbout.Enabled;

  btnCube.Down := ValidChild and ( CurrentChild.EditMode = EDIT_BLOCK ) and ( CurrentChild.BlockType = BLOCK_SOLID );
  btnPillar.Down := ValidChild and ( CurrentChild.EditMode = EDIT_BLOCK ) and ( CurrentChild.BlockType = BLOCK_PILLAR );
  btnWater.Down := ValidChild and ( CurrentChild.EditMode = EDIT_BLOCK ) and ( CurrentChild.BlockType = BLOCK_WATER );
  btnSpawnThing.Down := ValidChild and ( CurrentChild.EditMode = EDIT_THING ) and ( CurrentChild.ThingType = THING_SPAWN );
  btnRescueeThing.Down := ValidChild and ( CurrentChild.EditMode = EDIT_THING ) and ( CurrentChild.ThingType = THING_RESCUEE );
  btnStartThing.Down := ValidChild and ( CurrentChild.EditMode = EDIT_THING ) and ( CurrentChild.ThingType = THING_START );
End;

(* Destructor *)

Destructor tfrmMain.Destroy;
Begin
  Inherited Destroy;
End;

End.
