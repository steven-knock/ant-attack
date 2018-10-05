unit LevelDetail;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Map, StdCtrls, ComCtrls, Common, LightMap, Progress;

type
  tInterruptableLightMapPacker = class( tPackLightMapSurfaceIterator )
  private
    fAborted : boolean;
    frmProgress : tfrmProgress;
    BasePosition : integer;
  public
    constructor Create( cLightMapManager : tLightMapManager; Stream : tStream; frmProgress : tfrmProgress; BasePosition : integer );
    function    visitSurface( cSurface : tSurfaceSpecification ) : boolean; Override;
    property    Aborted : boolean read fAborted write fAborted;
  end;

  tfrmLevelDetail = class( tForm )
    grpLevel: TGroupBox;
    lstLevels: TListView;
    btnCancel: TButton;
    grpShadow: TGroupBox;
    btnInterpolate: TButton;
    btnLightMap: TButton;
    btnEdit: TButton;
    btnOK: TButton;
    procedure btnEditClick( Sender : tObject );
    procedure btnInterpolateClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure lstLevelsClick(Sender: TObject);
    procedure lstLevelsDblClick( Sender : tObject );
    procedure btnLightMapClick(Sender: TObject);
  private
    fMap : tMap;
    fMapLevelList : tObjectList;
    fLightMapPacker : tInterruptableLightMapPacker;
    procedure btnCancelClick(Sender: TObject);
    function  GetMapLevel( Level : integer ) : tMapLevel;
    procedure PopulateList;
    procedure RefreshListView;
    property  Map : tMap read fMap;
  public
    constructor Create( aOwner : tComponent; aMap : tMap ); reintroduce;
    destructor  Destroy; override;
  end;

implementation

{$R *.dfm}

uses
  Math, LevelEdit;

constructor tfrmLevelDetail.Create( aOwner : tComponent; aMap : tMap );
begin
  inherited Create( aOwner );
  fMap := aMap;
  fMapLevelList := tObjectList.Create;
  btnInterpolate.Enabled := fMap.Header^.Levels > 2;
  PopulateList;
end;

destructor tfrmLevelDetail.Destroy;
begin
  fLightMapPacker.Free;
  fMapLevelList.Free;
  inherited;
end;

procedure tfrmLevelDetail.btnEditClick( Sender : tObject );
var
  ListItem : tListItem;
  MapLevel : tMapLevel;
begin
  ListItem := lstLevels.Selected;
  if ListItem <> nil then
  begin
    MapLevel := ListItem.Data;
    with tfrmLevelEdit.Create( Self, MapLevel ) do
      try
        if ShowModal = mrOk then
          RefreshListView;
      finally
        Free;
      end;
  end;
end;

procedure tfrmLevelDetail.btnInterpolateClick(Sender: TObject);
var
  Idx : integer;
  MapLevel : tMapLevel;
begin
  for Idx := 2 to Map.Header^.Levels - 1 do
  begin
    MapLevel := GetMapLevel( Idx );
    MapLevel.Info.LightPosition := Map.interpolateLight( Idx, Map.Header^.Levels, GetMapLevel( 1 ).Info.LightPosition, GetMapLevel( Map.Header^.Levels ).Info.LightPosition );
    MapLevel.InvalidateLightMap;
  end;
  RefreshListView;
end;

procedure tfrmLevelDetail.btnOKClick(Sender: TObject);
var
  Idx : integer;
  Master : pMapLevelInfo;
begin
  for Idx := 1 to Map.Header^.Levels do
  begin
    Master := @Map.Level[ Idx ].Info;
    with GetMapLevel( Idx ).Info do
    begin
      Master^.AntCount := AntCount;
      Master^.SpawnInterval := SpawnInterval;
      Master^.DrawDistance := DrawDistance;
      Master^.LightPosition := LightPosition;
      Master^.LightMapSize := LightMapSize;     // This may have changed to indicate that it is now invalid
    end;
  end;
  ModalResult := mrOk;
end;

procedure tfrmLevelDetail.lstLevelsClick(Sender: TObject);
begin
  btnEdit.Enabled := lstLevels.Selected <> nil;
end;

procedure tfrmLevelDetail.lstLevelsDblClick( Sender : tObject );
begin
  btnEditClick( Sender );
end;

function tfrmLevelDetail.GetMapLevel( Level : integer ) : tMapLevel;
begin
  result := fMapLevelList[ Level - 1 ];
end;

procedure tfrmLevelDetail.PopulateList;
var
  Idx : integer;
  MapLevel : tMapLevel;
begin
  fMapLevelList.Clear;
  for Idx := 1 to Map.Header^.Levels do
  begin
    MapLevel := tMapLevel.Create;
    fMapLevelList.Add( MapLevel );
    MapLevel.Info := Map.Level[ Idx ].Info;
  end;
  RefreshListView;
end;

procedure tfrmLevelDetail.RefreshListView;
var
  Idx, SelectedIdx : integer;
  MapLevel : tMapLevel;
begin
  SelectedIdx := lstLevels.ItemIndex;
  lstLevels.Clear;
  for Idx := 1 to fMapLevelList.Count do
  begin
    MapLevel := GetMapLevel( Idx );
    lstLevels.AddItem( IntToStr( Idx ), MapLevel );
    with lstLevels.Items[ Idx - 1 ].SubItems, MapLevel.Info do
    begin
      Add( IntToStr( AntCount ) );
      Add( IntToStr( SpawnInterval ) );
      Add( IntToStr( DrawDistance ) );
      Add( SingleToStr( RadToDeg( LightPosition.Latitude ) ) + '°' );
      Add( SingleToStr( RadToDeg( LightPosition.Longitude ) ) + '°' );
    end;
  end;
  if SelectedIdx >= 0 then
    lstLevels.ItemIndex := SelectedIdx;
end;

procedure tfrmLevelDetail.btnLightMapClick(Sender: TObject);

procedure BuildDirtyLevelList( MapList : tList );
var
  Idx : cardinal;
  MapLevel : tMapLevel;
begin
  MapList.Clear;
  for Idx := 1 to Map.Header^.Levels do
  begin
    MapLevel := GetMapLevel( Idx );
    if MapLevel.IsLightMapOutOfDate then
      MapList.Add( pointer( Idx ) );
  end;
end;

var
  Idx : integer;
  LightMapManager : tLightMapManager;
  Stream : tMemoryStream;
  DirtyLevelList : tList;
  Buffer : tList;
  BufferSize : tList;
  Memory : Pointer;
  frmProgress : tfrmProgress;
  Aborted : boolean;
  LevelIndex : cardinal;
  LightMapSize : cardinal;
begin
  DirtyLevelList := tList.Create;
  try
    BuildDirtyLevelList( DirtyLevelList );
    if DirtyLevelList.Count > 0 then
    begin
      Buffer := tList.Create;
      try
        BufferSize := tList.Create;
        try
          frmProgress := tfrmProgress.Create( Self, 'Creating Light Maps', DirtyLevelList.Count * Map.Height + 1 );
          try
            frmProgress.OnCancel := btnCancelClick;
            frmProgress.Show;
            LightMapManager := tLightMapManager.Create;
            try
              LightMapManager.initialise( Map );
              Aborted := false;
              Idx := 0;
              repeat
                LevelIndex := cardinal( DirtyLevelList[ Idx ] );
                frmProgress.SetInformation( 'Calculating Level ' + IntToStr( LevelIndex ) );

                LightMapManager.setLightSphericalPosition( GetMapLevel( LevelIndex ).Info.LightPosition );
                Stream := tMemoryStream.Create;
                try
                  fLightMapPacker := tInterruptableLightMapPacker.Create( LightMapManager, Stream, frmProgress, Idx * Map.Height );
                  try
                    LightMapManager.iterateSurfaces( fLightMapPacker );
                    GetMem( Memory, Stream.Position );
                    Buffer.Add( Memory );
                    BufferSize.Add( Pointer( Stream.Position ) );
                    Move( Stream.Memory^, Memory^, Stream.Position );
                  finally
                    Aborted := fLightMapPacker.Aborted;
                    fLightMapPacker.Free;
                    fLightMapPacker := nil;
                  end;
                finally
                  Stream.Free;
                end;
                inc ( Idx );
              until ( Idx >= DirtyLevelList.Count ) or Aborted;
            finally
              LightMapManager.Free;
            end;

            if not Aborted then
            begin
              for Idx := 0 to DirtyLevelList.Count - 1 do
              begin
                LevelIndex := cardinal( DirtyLevelList[ Idx ] );
                LightMapSize := cardinal( BufferSize[ 0 ] );
                GetMapLevel( LevelIndex ).Info.LightMapSize := LightMapSize;
                Map.Level[ LevelIndex ].SetLightMapData( Buffer[ 0 ], LightMapSize );
                Buffer.Delete( 0 );
                BufferSize.Delete( 0 );
              end;
            end;
          finally
            frmProgress.Free;
          end;
        finally
          BufferSize.Free;
        end;
      finally
        for Idx := 0 to Buffer.Count - 1 do
          FreeMem( Buffer[ Idx ] );
        Buffer.Free;
      end;
      if not Aborted then
      begin
        MessageDlg( 'Light Map Generation Complete', mtInformation, [ mbOk ], 0 );
        btnOkClick( Self );
      end;
    end
    else
      MessageDlg( 'All Light Maps are up-to-date', mtInformation, [ mbOk ], 0 );
  finally
    DirtyLevelList.Free;
  end;
end;

procedure tfrmLevelDetail.btnCancelClick(Sender: TObject);
begin
  if Assigned( fLightMapPacker ) then
    fLightMapPacker.Aborted := true;
end;

(* tInterruptableLightMapPacker *)

constructor tInterruptableLightMapPacker.Create( cLightMapManager : tLightMapManager; Stream : tStream; frmProgress : tfrmProgress; BasePosition : integer );
begin
  inherited Create( cLightMapManager, Stream );
  Self.frmProgress := frmProgress;
  Self.BasePosition := BasePosition; 
end;

function tInterruptableLightMapPacker.visitSurface( cSurface : tSurfaceSpecification ) : boolean;
begin
  inherited visitSurface( cSurface );
  frmProgress.SetPosition( BasePosition + cSurface.z );
  Application.ProcessMessages;
  result := not Aborted;
end;

end.
