program AntAttack;

uses
  Forms,
  Resource in 'Resource.pas',
  Common in 'Common.pas',
  Cube in 'Cube.pas',
  GameEngine in 'GameEngine.pas',
  GameState in 'GameState.pas',
  Intelligence in 'Intelligence.pas',
  LightMap in 'LightMap.pas',
  Map in 'Map.pas',
  PlayerInput in 'PlayerInput.pas',
  Raycaster in 'Raycaster.pas',
  Renderer in 'Renderer.pas',
  BlockCollisions in 'BlockCollisions.pas',
  Game in 'Game.pas' {frmGame},
  RenderedForm in 'RenderedForm.pas',
  AvailableMapList in 'AvailableMapList.pas',
  ChooseMap in 'ChooseMap.pas',
  GamePlayHandler in 'GamePlayHandler.pas',
  Messaging in 'Messaging.pas',
  Introduction in 'Introduction.pas',
  ApplicationStateData in 'ApplicationStateData.pas',
  Sound in 'Sound.pas',
  AntIntelligence in 'AntIntelligence.pas',
  GameLog in 'GameLog.pas' {frmGameLog},
  GameModel in 'GameModel.pas',
  Log in 'Log.pas',
  MD2Model in 'MD2Model.pas',
  MDIChildForm in 'MDIChildForm.pas',
  Model in 'Model.pas',
  ModelBase in 'ModelBase.pas',
  Occupancy in 'Occupancy.pas',
  Path in 'Path.pas',
  RescueeIntelligence in 'RescueeIntelligence.pas',
  RescuerIntelligence in 'RescuerIntelligence.pas',
  Sense in 'Sense.pas',
  SharedStateData in 'SharedStateData.pas',
  AttractHandler in 'AttractHandler.pas',
  HelpHandler in 'HelpHandler.pas',
  Colour in 'Colour.pas',
  GameSound in 'GameSound.pas',
  WavSample in 'WavSample.pas',
  SpriteModel in 'SpriteModel.pas',
  SysUtils,
  Windows;

{$R *.res}

begin
  Application.Initialize;
  try
    Application.Title := 'Ant Attack';
    Application.CreateForm(TfrmGame, frmGame);
    Application.Run;
  except
    on E : Exception do
      Application.MessageBox( pChar( E.Message ), nil, MB_ICONSTOP );
  end;
end.
