unit ChooseMap;

interface

uses
  ApplicationStateData, Map;

type
  tChooseMapHandler = class( tApplicationStateHandler )
  private
    fFirst : boolean;
    fPreviousMap : tMap;
    fPreviousMapIndex : integer;
  public
    constructor Create( aApplicationStateData : tApplicationStateData );
    procedure   Finalise; override;
    procedure   Initialise; override;
    procedure   Process; override;
  end;

implementation

Uses
  SysUtils, AvailableMapList, Colour, Math, Geometry, Renderer, Messaging, SharedStateData;

constructor tChooseMapHandler.Create( aApplicationStateData : tApplicationStateData );
begin
  inherited Create( aApplicationStateData, STATE_CHOOSE_MAP, [ KEY_LEFT, KEY_RIGHT, KEY_SELECT ] );
end;

procedure tChooseMapHandler.Finalise;
begin
  if fPreviousMap <> nil then
  begin
    ApplicationStateData.Renderer.Map := fPreviousMap;      // Restore previous map if user pressed escape
    ApplicationStateData.MapList.CurrentIndex := fPreviousMapIndex;
  end;
  ApplicationStateData.Renderer.LightMapManager.prepareLevelLightMap( 1, false );   // Restore Level Lighting
end;

procedure tChooseMapHandler.Initialise;
begin
  fFirst := true;
  with ApplicationStateData.Renderer do
  begin
    with RenderStatus do
    begin
      nFOV := 90;
      nFog := 0;
      nLightMap := LM_NONE;
      bOrthographic := true;
      bTextureFloor := false;
      bSun := false;
      bCacheVisibility := false;
    end;
    fPreviousMap := Map;
    fPreviousMapIndex := ApplicationStateData.MapList.CurrentIndex;
  end;
end;

procedure tChooseMapHandler.Process;
var
  Count : integer;
  cMap : tMap;
  Sin45 : _float;
  MapList : tAvailableMapList;
begin
  ApplicationStateData.RenderRequired := false;
  MapList := ApplicationStateData.MapList;
  Count := MapList.Count;
  if Count > 0 then
  begin
    if KEY_LEFT in ApplicationStateData.KeysPressed then
      if MapList.CurrentIndex > 0 then
        MapList.CurrentIndex := MapList.CurrentIndex - 1
      else
        MapList.CurrentIndex := Count - 1;
    if KEY_RIGHT in ApplicationStateData.KeysPressed then
      if MapList.CurrentIndex < Count - 1 then
        MapList.CurrentIndex := MapList.CurrentIndex + 1
      else
        MapList.CurrentIndex := 0;
    if KEY_SELECT in ApplicationStateData.KeysPressed then
    begin
      ApplicationStateData.State := STATE_ATTRACT;
      fPreviousMap := nil;
    end;
    if KEY_ESCAPE in ApplicationStateData.KeysPressed then
      ApplicationStateData.State := STATE_ATTRACT;

    cMap := MapList.Map[ MapList.CurrentIndex ];
    with ApplicationStateData.Renderer do
    begin
      if ( Map <> cMap ) or fFirst then
      begin
        Sin45 := Sin( PI / 4 );
        ApplicationStateData.Form.Map := cMap;
        RenderStatus.nFarDistance := ( ( 1 + Sin45 ) * MAP_SIZE_COLUMN ) + ( Max( cMap.Width, cMap.Height ) * 2 );
        RenderStatus.nScale := RenderStatus.nFarDistance * Sin45 / 2;
        Camera.setLocation( cMap.Width + 1, RenderStatus.nScale + 1, cMap.Height + 1 );
        with Camera.Orientation do
        begin
          reset;
          rotateX( PI / 4 );
          rotateY( PI / -4 );
        end;
        ApplicationStateData.MessageList.ClearCategory( Ord( State ) );
        RenderMapTitle;
        ApplicationStateData.AddMessage( '<' + IntToStr( MapList.CurrentIndex + 1 ) + '/' + IntToStr( MapList.Count ) + '>', 14 ).SetPosition( 0.9, 0.85 ).SetAlignment( 1, 0 ).SetColour( COLOUR_RACING_GREEN );
        LightMapManager.LightPosition.setLocation( -4, 3, -1 );
        ApplicationStateData.RenderRequired := true;
      end;
    end;
  end;
  fFirst := false;
end;

end.
