unit Scene;

interface

uses
  Classes, Common, GameState, Geometry;

type
  tSceneEntity = class( tObject )
  private
    fEntityTypeID : tEntityTypeID;
    fLocation : tPoint3d;
    fOrientation : _float;
    fAnimation : cardinal;
    fAnimationTime : _float;
  public
    constructor Create;
    destructor  Destroy; override;
    property    EntityTypeID : tEntityTypeID read fEntityTypeID;
    property    Location : tPoint3d read fLocation;
    property    Orientation : _float read fOrientation;
    property    Animation : cardinal read fAnimation;
    property    AnimationTime : _float read fAnimationTime;
  end;

  tSceneGameInformation = class( tGameInformation )
  private
    fPhysicalEntityList : tObjectList;
    EntityTypes : tEntityTypeArray;
  protected
    function GetIsAntParalysed : boolean; override;
    function GetLevel : integer; override;
    function GetPhysicalEntityList : tList; override;
    function GetRescuer : tPlayerEntity; override;
    function GetRescuee : tPlayerEntity; override;
    function GetRescueeHealth : _float; override;
    function GetRescueeOxygen : _float; override;
    function GetRescueeStamina : _float; override;
    function GetRescuerHealth : _float; override;
    function GetRescuerGrenades : integer; override;
    function GetRescuerOxygen : _float; override;
    function GetRescuerStamina : _float; override;
    function GetRescuerDirectionStrength : _float; override;
    function GetTime : _float; override;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   Refresh( EntityList : tList );
  end;

  tScene = class( tObject )
  private
    EntityList : tObjectList;
    fSun : tSphericalCoordinate;
    fInformation : tSceneGameInformation;
  public
    constructor Create;
    destructor  Destroy; override;
    function    AddEntity : tSceneEntity;
    procedure   DeleteEntity( Entity : tSceneEntity );
    function    GetEntity( Index : integer ) : tSceneEntity;
    function    GetEntityCount : integer;
    procedure   Load( const Filename : string );
    procedure   Save( const Filename : string );
    procedure   Update;
    property    Information : tSceneGameInformation read fInformation;
    property    Sun : tSphericalCoordinate read fSun;
  end;

implementation

uses
  INIFiles, SysUtils, Map, Model, GameModel;

const
  INI_SECTION = 'Ant Attack Scene';
  INI_ENTITY_COUNT = 'Entity Count';
  INI_SUN_LONGITUDE = 'Sun.Longitude';
  INI_SUN_LATITUDE = 'Sun.Latitude';

  INI_ENTITY_SECTION = 'Entity %d';
  INI_ENTITY_TYPE_ID = 'EntityType.ID';
  INI_LOCATION_X = 'Location.x';
  INI_LOCATION_Y = 'Location.y';
  INI_LOCATION_Z = 'Location.z';
  INI_ORIENTATION = 'Orientation';
  INI_ANIMATION = 'Animation.Sequence';
  INI_ANIMATION_TIME = 'Animation.Time';

(* tSceneEntity *)

constructor tSceneEntity.Create;
begin
  inherited;
  fLocation := tPoint3d.Create;
end;

destructor tSceneEntity.Destroy;
begin
  fLocation.Free;
  inherited;
end;

(* tScene *)

constructor tScene.Create;
begin
  inherited;
  fInformation := tSceneGameInformation.Create;
  EntityList := tObjectList.Create;
end;

destructor tScene.Destroy;
begin
  fInformation.Free;
  EntityList.Free;
  inherited;
end;

function tScene.AddEntity : tSceneEntity;
begin
  result := tSceneEntity.Create;
  EntityList.Add( result );
end;

procedure tScene.DeleteEntity( Entity : tSceneEntity );
begin
  if EntityList.Remove( Entity ) < 0 then
    Entity.Free;
end;

function tScene.GetEntity( Index : integer ) : tSceneEntity;
begin
  result := tSceneEntity( EntityList[ Index ] );
end;

function tScene.GetEntityCount : integer;
begin
  result := EntityList.Count;
end;

procedure tScene.Load( const Filename : string );

procedure LoadEntity( INIFile : tINIFile; EntityID : integer );
var
  Section : string;
  Entity : tSceneEntity;
begin
  Section := Format( INI_ENTITY_SECTION, [ EntityID ] );
  Entity := tSceneEntity.Create;
  try
    with Entity, INIFile do
    begin
      fEntityTypeID := tEntityTypeID( ReadInteger( Section, INI_ENTITY_TYPE_ID, 0 ) );
      fLocation.x := ReadFloat( Section, INI_LOCATION_X, 0 );
      fLocation.y := ReadFloat( Section, INI_LOCATION_Y, 0 );
      fLocation.z := ReadFloat( Section, INI_LOCATION_Z, 0 );
      fOrientation := ReadFloat( Section, INI_ORIENTATION, 0 ) * PI / 180;
      fAnimation := ReadInteger( Section, INI_ANIMATION, 0 );
      fAnimationTime := ReadFloat( Section, INI_ANIMATION_TIME, 0 );
    end;
    EntityList.Add( Entity );
  except
    Entity.Free;
    raise;
  end;
end;

var
  Idx : integer;
  EntityCount : integer;
  INIFile : tINIFile;
begin
  EntityList.Clear;
  INIFile := tINIFile.Create( Filename );
  try
    EntityCount := INIFile.ReadInteger( INI_SECTION, INI_ENTITY_COUNT, 0 );
    fSun.Longitude := INIFile.ReadFloat( INI_SECTION, INI_SUN_LONGITUDE, 0 ) * PI / 180;
    fSun.Latitude := INIFile.ReadFloat( INI_SECTION, INI_SUN_LATITUDE, 0 ) * PI / 180;
    for Idx := 1 to EntityCount do
      LoadEntity( INIFile, Idx );
  finally
    INIFile.Free;
  end;
  Update;
end;

procedure tScene.Save( const Filename : string );

procedure SaveEntity( INIFile : tINIFile; ID : integer; Entity : tSceneEntity );
var
  Section : string;
begin
  Section := Format( INI_ENTITY_SECTION, [ ID ] );
  with Entity, INIFile do
  begin
    WriteInteger( Section, INI_ENTITY_TYPE_ID, integer( EntityTypeID ) );
    WriteFloat( Section, INI_LOCATION_X, Location.x );
    WriteFloat( Section, INI_LOCATION_Y, Location.y );
    WriteFloat( Section, INI_LOCATION_Z, Location.z );
    WriteFloat( Section, INI_ORIENTATION, Orientation * 180 / PI );
    WriteInteger( Section, INI_ANIMATION, Animation );
    WriteFloat( Section, INI_ANIMATION_TIME, AnimationTime );
  end;
end;

var
  Idx : integer;
  INIFile : tINIFile;
begin
  DeleteFile( Filename );
  INIFile := tINIFile.Create( Filename );
  try
    INIFile.WriteInteger( INI_SECTION, INI_ENTITY_COUNT, EntityList.Count );
    INIFile.WriteFloat( INI_SECTION, INI_SUN_LONGITUDE, Sun.Longitude * 180 / PI );
    INIFile.WriteFloat( INI_SECTION, INI_SUN_LATITUDE, Sun.Latitude * 180 / PI );
    for Idx := 1 to EntityList.Count do
      SaveEntity( INIFile, Idx, tSceneEntity( EntityList[ Idx - 1 ] ) );
  finally
    INIFile.Free;
  end;
end;

procedure tScene.Update;
begin
  Information.Refresh( EntityList );
end;

(* tSceneGameInformation *)

constructor tSceneGameInformation.Create;

procedure DefineHumanModel( EntityTypeID : tEntityTypeID; GameModel : tModel );
begin
  with EntityTypes[ EntityTypeID ] do
  begin
    OwnModel := true;
    Model := GameModel;
  end;
end;

var
  MapHeader : tMapHeader;
begin
  inherited;
  fPhysicalEntityList := tObjectList.Create;
  FillChar( MapHeader, SizeOf( MapHeader ), 0 );
  tEntityType.CreateEntityTypes( MapHeader, EntityTypes );
  DefineHumanModel( TYPE_RESCUER, CreateMaleModel );
  DefineHumanModel( TYPE_RESCUEE, CreateFemaleModel );
end;

destructor tSceneGameInformation.Destroy;
begin
  tEntityType.FreeEntityTypes( EntityTypes );
  fPhysicalEntityList.Free;
  inherited;
end;

function tSceneGameInformation.GetIsAntParalysed : boolean;
begin
  result := false;
end;

function tSceneGameInformation.GetLevel : integer;
begin
  result := 1;
end;

function tSceneGameInformation.GetPhysicalEntityList : tList;
begin
  result := fPhysicalEntityList;
end;

function tSceneGameInformation.GetRescuer : tPlayerEntity;
begin
  result := nil;
end;

function tSceneGameInformation.GetRescuee : tPlayerEntity;
begin
  result := nil;
end;

function tSceneGameInformation.GetRescueeHealth : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescueeOxygen : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescueeStamina : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescuerHealth : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescuerGrenades : integer;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescuerOxygen : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescuerStamina : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetRescuerDirectionStrength : _float;
begin
  result := 0;
end;

function tSceneGameInformation.GetTime : _float;
begin
  result := 0;
end;

procedure tSceneGameInformation.Refresh( EntityList : tList );
var
  Idx : integer;
  Entity : tPhysicalEntity;
  EntityType : tEntityType;
  SceneEntity : tSceneEntity;
begin
  fPhysicalEntityList.Clear;
  for Idx := 0 to EntityList.Count - 1 do
  begin
    SceneEntity := tSceneEntity( EntityList[ Idx ] );
    with SceneEntity do
    begin
      EntityType := EntityTypes[ SceneEntity.EntityTypeID ];
      Entity := tPhysicalEntity( EntityType.CreateEntity( nil ) );
      if Entity is tPhysicalEntity then
      begin
        Entity.Location.setLocation( Location );
        Entity.Orientation := Orientation;
        Entity.Animation := Animation;
        Entity.AnimationTime := -AnimationTime;
        fPhysicalEntityList.Add( Entity );
      end
      else
        Entity.Free;
    end;
  end;
end;

end.
