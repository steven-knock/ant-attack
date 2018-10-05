Program MapMaker;

uses
  Forms,
  Main in 'Main.pas' {frmMain},
  Viewer in 'Viewer.pas' {frmViewer},
  Common in 'Common.pas',
  MapProp in 'MapProp.pas' {frmProperties},
  Perimetr in 'Perimetr.pas' {frmPerimeter},
  Things in 'Things.pas' {frmThing},
  Preview in 'Preview.pas' {frmPreview},
  About in 'About.pas' {frmAbout},
  LightMap in 'LightMap.pas',
  ExportMap in 'ExportMap.pas' {frmExport},
  Raycaster in 'Raycaster.pas',
  Renderer in 'Renderer.pas',
  Game in 'Game.pas' {frmGame},
  Map in 'Map.pas',
  Resource in 'Resource.pas',
  RenderedForm in 'RenderedForm.pas',
  GameEngine in 'GameEngine.pas',
  Intelligence in 'Intelligence.pas',
  PlayerInput in 'PlayerInput.pas',
  GameState in 'GameState.pas',
  Cube in 'Cube.pas',
  BlockCollisions in 'BlockCollisions.pas',
  LevelDetail in 'LevelDetail.pas' {frmLevelDetail},
  LevelEdit in 'LevelEdit.pas' {frmLevelEdit},
  MDIChildForm in 'MDIChildForm.pas',
  Selection in 'Selection.pas',
  Progress in 'Progress.pas' {frmProgress},
  GamePlayHandler in 'GamePlayHandler.pas',
  Introduction in 'Introduction.pas',
  Messaging in 'Messaging.pas',
  SharedStateData in 'SharedStateData.pas',
  ApplicationStateData in 'ApplicationStateData.pas',
  ChooseMap in 'ChooseMap.pas',
  Sense in 'Sense.pas',
  Sound in 'Sound.pas',
  Path in 'Path.pas',
  GameLog in 'GameLog.pas' {frmGameLog},
  Log in 'Log.pas',
  AntIntelligence in 'AntIntelligence.pas',
  RescuerIntelligence in 'RescuerIntelligence.pas',
  RescueeIntelligence in 'RescueeIntelligence.pas',
  Occupancy in 'Occupancy.pas',
  Model in 'Model.pas',
  ModelBase in 'ModelBase.pas',
  MD2Model in 'MD2Model.pas',
  GameModel in 'GameModel.pas',
  AttractHandler in 'AttractHandler.pas',
  AvailableMapList in 'AvailableMapList.pas',
  SpriteModel in 'SpriteModel.pas',
  Colour in 'Colour.pas',
  GameSound in 'GameSound.pas',
  WavSample in 'WavSample.pas',
  Scene in 'Scene.pas';

{$R *.RES}
{$R map.res}

Begin
  Application.Initialize;
  Application.Title := 'Ant Attack - Map Editor';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
End.
