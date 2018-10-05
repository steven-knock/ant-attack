unit GameModel;

interface

uses
  Model;

function CreateAntModel : tModel;
function CreateGrenadeModel : tModel;
function CreateMaleModel : tModel;
function CreateFemaleModel : tModel;
function CreateHeartModel : tModel;
function CreateExplosionModel : tModel;
function CreateDirtModel : tModel;
function CreateBloodModel : tModel;

const
  ANIMATION_ANT_STAND   = 0;
  ANIMATION_ANT_WALK    = 1;
  ANIMATION_ANT_BITE    = 2;
  ANIMATION_ANT_DIE     = 3;
  ANIMATION_ANT_EXPLODE = 4;
  ANIMATION_ANT_LOOK    = 5;

  ANIMATION_HUMAN_STAND     = 0;
  ANIMATION_HUMAN_WAIT      = 1;
  ANIMATION_HUMAN_THINK     = 2;
  ANIMATION_HUMAN_WAVE      = 3;
  ANIMATION_HUMAN_RUN       = 4;
  ANIMATION_HUMAN_FIRE      = 5;
  ANIMATION_HUMAN_BITE_BASE = 6;
  ANIMATION_HUMAN_BITE_COUNT= 3;
  ANIMATION_HUMAN_JUMP      = 9;
  ANIMATION_HUMAN_FALL      = 10;
  ANIMATION_HUMAN_DIE_1     = 11;
  ANIMATION_HUMAN_DIE_2     = 12;
  ANIMATION_HUMAN_DIE_3     = 13;
  ANIMATION_HUMAN_QUIESCENT = 14;
  ANIMATION_HUMAN_WAKE      = 15;

implementation

uses
  Classes, SysUtils, Windows, MD2Model, Resource, SpriteModel;

const
  // Polygonal Models
  ID_ANT = 0;
  ID_GRENADE = 1;
  ID_MALE = 2;
  ID_FEMALE = 3;

  // Sprite Models
  ID_HEART = 0;
  ID_DIRT = 1;
  ID_EXPLOSION = 2;
  ID_BLOOD = 3;

function GetModelResource( ID : cardinal ) : tStream;
begin
  if FindResource( hResourceInstance, pChar( ID ), pChar( RT_RCDATA ) ) <> 0 then
    result := tResourceStream.CreateFromID( hResourceInstance, ID, RT_RCDATA )
  else
    raise eResNotFound.Create( 'Cannot find resource ' + IntToStr( ID ) );
end;

function CreateMD2Model( ID : cardinal ) : tMD2Model;
var
  ModelData : tStream;
  ModelBuilder : tModelBuilder;
begin
  ModelData := GetModelResource( RES_MODEL_BASE + ID );
  try
    ModelBuilder := tModelManager.Create;
    try
      result := tMD2Model( ModelBuilder.CreateModel( ModelData ) );
      if result.TextureCount = 0 then
        result.AddResourceTexture( RES_MODEL_BASE + ID );
    finally
      ModelBuilder.Free;
    end;
  finally
    ModelData.Free;
  end;
end;

function CreateSpriteModel( ID : cardinal ) : tSpriteModel;
var
  ModelData : tStream;
  ModelBuilder : tModelBuilder;
begin
  ModelData := GetModelResource( RES_SPRITE_BASE + ID );
  try
    ModelBuilder := tModelManager.Create;
    try
      result := tSpriteModel( ModelBuilder.CreateModel( ModelData ) );
    finally
      ModelBuilder.Free;
    end;
  finally
    ModelData.Free;
  end;
end;

function CreateAntModel : tModel;
var
  Model : tMD2Model;
begin
  Model := CreateMD2Model( ID_ANT );
  try
    Model.DefaultFPS := 20;
    Model.Scale.setLocation( 0.07, 0.07, 0.14 );

    Model.DefineAnimation( 0, 0 );              // Stand
    Model.DefineAnimation( 0, 7, 0, true );     // Walk
    Model.DefineAnimation( 9, 18 );             // Bite
    Model.DefineAnimation( 19, 28 );            // Die
    Model.DefineAnimation( 29, 44 );            // Explode
    Model.DefineAnimation( 45, 64, 0, true );   // Look

    result := Model;
  except
    Model.Free;
    raise;
  end;
end;

function CreateGrenadeModel : tModel;
var
  Model : tMD2Model;
begin
  Model := CreateMD2Model( ID_GRENADE );
  try
    Model.Scale.setLocation( 0.001, 0.001, 0.001 );
    Model.DefineAnimation( 0, 0 );        // Static
    result := Model;
  except
    Model.Free;
    raise;
  end;
end;

function CreatePlayerModel( ID : integer ) : tMD2Model;
var
  Model : tMD2Model;
begin
  Model := CreateMD2Model( ID );
  try
    Model.Orientation.rotateY( -PI / 2 );
    Model.Scale.setLocation( 0.015, 0.015, 0.015 );
    Model.Translation.y := 0.375;

    Model.DefineAnimation( 0, 0 );              // Stand
    Model.DefineAnimation( 0, 39, 1, true );    // Wait
    Model.DefineAnimation( 72, 83, 1, true );   // Think
    Model.DefineAnimation( 112, 122, 1, true ); // Wave
    Model.DefineAnimation( 40, 45, 0, true );   // Run
    Model.DefineAnimation( 46, 53, 0, true );   // Fire
    Model.DefineAnimation( 54, 57, 2 );         // Bitten 1
    Model.DefineAnimation( 58, 61, 2 );         // Bitten 3
    Model.DefineAnimation( 62, 65, 2 );         // Bitten 3
    Model.DefineAnimation( 66, 71 );            // Jump
    Model.DefineAnimation( 66, 66 );            // Fall
    Model.DefineAnimation( 178, 183, 3 );       // Die 1
    Model.DefineAnimation( 184, 189, 3 );       // Die 2
    Model.DefineAnimation( 190, 197, 3 );       // Die 3
    Model.DefineAnimation( 177, 177 );          // Quiescent
    Model.DefineAnimation( 177, 172 );          // Wake

    result := Model;
  except
    Model.Free;
    raise;
  end;
end;

function CreateMaleModel : tModel;
begin
  result := CreatePlayerModel( ID_MALE );
  result.Scale.x := result.Scale.x * 0.8;
  result.Scale.y := result.Scale.y * 0.8;
  result.Translation.z := -0.1;
end;

function CreateFemaleModel : tModel;
begin
  result := CreatePlayerModel( ID_FEMALE );
end;

function CreateHeartModel : tModel;
begin
  result := CreateSpriteModel( ID_HEART );
end;

function CreateExplosionModel : tModel;
begin
  result := CreateSpriteModel( ID_EXPLOSION );
end;

function CreateDirtModel : tModel;
begin
  result := CreateSpriteModel( ID_DIRT );
end;

function CreateBloodModel : tModel;
begin
  result := CreateSpriteModel( ID_BLOOD );
end;

end.
