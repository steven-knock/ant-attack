unit GameState;

interface

uses
  Classes, Types, Common, Map, Geometry, PlayerInput, SharedStateData, Model;

type
  tEntityTypeID = ( TYPE_RESCUER, TYPE_RESCUEE, TYPE_ANT, TYPE_GRENADE, TYPE_EXPLOSION, TYPE_SOUND, TYPE_SMELL, TYPE_DIRT, TYPE_HEART, TYPE_BLOOD, TYPE_UNKNOWN );

  tEntityType = class;
  tIntelligence = class;
  tIntelligenceClass = class of tIntelligence;
  tEntityCollisionHandler = class;
  tEntity = class;
  tEntityClass = class of tEntity;
  tGameState = class;
  tGameStateInformation = class;
  tOccupancyMap = class;

  tEntityTypeArray = array [ tEntityTypeID ] of tEntityType;

  tEntityType = class( tObject )
  private
    fID : tEntityTypeID;
    fHitPoints : integer;
    fBoundingBox : tBoundingBox;
    fFOV : cardinal;
    fMaximumForce : _float;
    fMaximumJumpForce : _float;
    fMass : _float;
    fFriction : _float;
    fParalysisThreshold : _float;
    fIntelligenceClass : tIntelligenceClass;
    fEyeOffset : _float;
    fVisible : boolean;
    fHuman : boolean;
    fSolid : boolean;
    fLungCapacity : _float;
    fHeartCapacity : _float;
    fEntityClass : tEntityClass;
    fModel : tModel;
    fOwnModel : boolean;
    fSoundSource : boolean;
    function    GetDescription : string;
    class procedure InitialisePlayerEntityType( const MapHeader : tMapHeader; var EntityType : tEntityType; EntityIntelligenceClass : tIntelligenceClass );
    procedure   SetModel( Model : tModel );
  public
    constructor Create( ID : tEntityTypeID; EntityClass : tEntityClass );
    destructor  Destroy; override;
    function    CreateEntity( GameState : tGameState ) : tEntity;
    class procedure CreateEntityTypes( const MapHeader : tMapHeader; var EntityTypes : tEntityTypeArray );
    class procedure FreeEntityTypes( var EntityTypes : tEntityTypeArray );
    function    GetCollisionFriction( EntityType : tEntityType ) : _float;
    property    ID : tEntityTypeID read fID;
    property    HitPoints : integer read fHitPoints write fHitPoints;
    property    Human : boolean read fHuman write fHuman;
    property    BoundingBox : tBoundingBox read fBoundingBox;
    property    Description : string read GetDescription;
    property    MaximumForce : _float read fMaximumForce write fMaximumForce;
    property    MaximumJumpForce : _float read fMaximumJumpForce write fMaximumJumpForce;
    property    Mass : _float read fMass write fMass;
    property    FOV : cardinal read fFOV write fFOV;
    property    Friction : _float read fFriction write fFriction;
    property    ParalysisThreshold : _float read fParalysisThreshold write fParalysisThreshold;
    property    IntelligenceClass : tIntelligenceClass read fIntelligenceClass write fIntelligenceClass;
    property    Solid : boolean read fSolid write fSolid;
    property    LungCapacity : _float read fLungCapacity write fLungCapacity;
    property    HeartCapacity : _float read fHeartCapacity write fHeartCapacity;
    property    EyeOffset : _float read fEyeOffset write fEyeOffset;
    property    Visible : boolean read fVisible write fVisible;
    property    EntityClass : tEntityClass read fEntityClass;
    property    Model : tModel read fModel write SetModel;
    property    OwnModel : boolean read fOwnModel write fOwnModel;
    property    SoundSource : boolean read fSoundSource write fSoundSource;
  end;

  tEntity = class( tObject )
  private
    fGameState : tGameState;
    fID : cardinal;
    fEntityType : tEntityType;
    fOwnerTypeID : tEntityTypeID;
    fLocation : tPoint3d;
    fCreateTime : _float;
  protected
    property    GameState : tGameState read fGameState;
    constructor Create( EntityType : tEntityType; GameState : tGameState ); virtual;
  public
    destructor  Destroy; override;
    function    GetDistanceFromCentreSq : _float;
    function    GetMapSquare : tIntPoint3d;
    function    IsExpired : boolean; virtual; abstract;
    property    ID : cardinal read fID;
    property    CreateTime : _float read fCreateTime;
    property    EntityType : tEntityType read fEntityType;
    property    Location : tPoint3d read fLocation;
    property    OwnerTypeID : tEntityTypeID read fOwnerTypeID;
  end;

  tPhysicalEntityState = ( STATE_MOBILE, STATE_QUIESCENT, STATE_EMERGING, STATE_ESCAPED, STATE_PARALYSED, STATE_DEAD, STATE_UNUSED );

  tPhysicalEntity = class( tEntity )
  private
    fDeadTime : _float;
    fIntelligence : tIntelligence;
    fHitPoints : _float;
    fLastDamageCause : tEntityTypeID;
    fOxygen : _float;
    fStamina : _float;
    fForce : tPoint3d;
    fState : tPhysicalEntityState;
    fVelocity : tPoint3d;
    fOrientation : _float;
    fAirborne : boolean;
    fTouchingBlock : boolean;
    fTouchingList : tList;
    fWasTouchingBlock : boolean;
    fExternallyLaunched : boolean;      // Used to indicate that this entity has been propelled vertically by an external force
    fAnimation : cardinal;
    fAnimationTime : _float;
    procedure   SetOrientation( Orientation : _float );
  protected
    constructor Create( EntityType : tEntityType; GameState : tGameState ); override;
    function    GetBoundingBox : tBoundingBox; virtual;
    procedure   SetState( State : tPhysicalEntityState ); virtual;
  public
    destructor  Destroy; override;
    procedure   ApplyForce( const Force : tPoint3d ); virtual;
    procedure   DampLateralMovement;
    function    GetAngleFromFace( const Target : tPoint3d ) : _float; overload;
    function    GetAngleFromFace( const Target : tPoint3d; Difference : tPoint3d ) : _float; overload;
    procedure   GetBoundingBoxPoints( var Point : array of tPoint3d; Rotate : boolean = false; Location : tPoint3d = nil );
    function    GetDecay : _float;
    function    GetMapRectangle : tRect;
    procedure   InitialiseFromThing( Thing : tThing );
    function    IsActive : boolean;
    function    IsAnimationComplete : boolean;
    function    IsEntityReachable( Entity : tPhysicalEntity; OverrideLocation : tPoint3d = nil ) : boolean;
    function    IsExpired : boolean; override;
    function    IsPointReachable( Target : tPoint3d ) : boolean;
    procedure   SetAnimation( Animation : cardinal );
    procedure   TakeDamage( Damage : _float; Cause : tEntityTypeId );
    property    BoundingBox : tBoundingBox read GetBoundingBox;
    property    DeadTime : _float read fDeadTime write fDeadTime;
    property    Intelligence : tIntelligence read fIntelligence;
    property    HitPoints : _float read fHitPoints;
    property    LastDamageCause : tEntityTypeID read fLastDamageCause;
    property    Oxygen : _float read fOxygen;
    property    Stamina : _float read fStamina write fStamina;
    property    Force : tPoint3d read fForce;
    property    Velocity : tPoint3d read fVelocity;
    property    Orientation : _float read fOrientation write SetOrientation;
    property    State : tPhysicalEntityState read fState write SetState;
    property    Airborne : boolean read fAirborne write fAirborne;
    property    TouchingList : tList read fTouchingList write fTouchingList;
    property    TouchingBlock : boolean read fTouchingBlock write fTouchingBlock;
    property    WasTouchingBlock : boolean read fWasTouchingBlock write fWasTouchingBlock;
    property    ExternallyLaunched : boolean read fExternallyLaunched write fExternallyLaunched;
    property    Animation : cardinal read fAnimation write fAnimation;
    property    AnimationTime : _float read fAnimationTime write fAnimationTime;
  end;

  tDeformablePhysicalEntity = class( tPhysicalEntity )
  private
    fBoundingBox : tBoundingBox;
  protected
    constructor Create( EntityType : tEntityType; GameState : tGameState ); override;
    function    GetBoundingBox : tBoundingBox; override;
    function    GetDeadSize : tFloatPoint2d; virtual; abstract;
  public
    destructor  Destroy; override;
  end;

  tPlayerEntity = class( tDeformablePhysicalEntity )
  private
    fGender : tGender;
    fFireDelay : integer;
    fGrenades : integer;
    fJumping : boolean;
    fVisibility : _float;
  protected
    function    GetDeadSize : tFloatPoint2d; override;
    constructor Create( EntityType : tEntityType; GameState : tGameState ); override;
  public
    property    Gender : tGender read fGender;
    property    FireDelay : integer read fFireDelay write fFireDelay;
    property    Grenades : integer read fGrenades write fGrenades;
    property    Jumping : boolean read fJumping write fJumping;
    property    Visibility : _float read fVisibility;
  end;

  tRescuer = class( tPlayerEntity );

  tRescuee = class( tPlayerEntity );

  tAnt = class( tDeformablePhysicalEntity )
  private
    fGameInformation : tGameStateInformation;
  protected
    constructor Create( EntityType : tEntityType; GameState : tGameState ); override;
    function    GetDeadSize : tFloatPoint2d; override;
    procedure   SetState( State : tPhysicalEntityState ); override;
  end;

  tGrenade = class( tPhysicalEntity )
  private
    fDetonationTime : _float;
    fOrigin : tPoint3d;
  protected
    constructor Create( EntityType : tEntityType; GameState : tGameState ); override;
  public
    destructor  Destroy; override;
    procedure   ApplyForce( const Force : tPoint3d ); override;
    property    DetonationTime : _float read fDetonationTime write fDetonationTime;
    property    Origin : tPoint3d read fOrigin write fOrigin;
  end;

  tExplosion = class( tPhysicalEntity )
  end;

  tHeart = class( tPhysicalEntity )
  end;

  tSensoryEntity = class( tEntity )
  private
    fLifeTime : _float;
    fMagnitude : _float;
  public
    function    GetCurrentMagnitude : _float;
    function    IsExpired : boolean; override;
    property    LifeTime : _float read fLifeTime;
    property    Magnitude : _float read fMagnitude;
  end;

  tSound = class( tSensoryEntity )
  end;

  tSmell = class( tSensoryEntity )
  end;

  tParticle = class( tPhysicalEntity )
  private
    fLifeTime : _float;
  public
    function    IsExpired : boolean; override;
    property    LifeTime : _float read fLifeTime;
  end;

  tEntityMover = class( tObject )
  private
    Acceleration : tPoint3d;
    Velocity : tPoint3d;
    Location : tPoint3d;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   MoveEntity( Entity : tPhysicalEntity; Interval : _float );
  end;

  tGameInformation = class( tObject )
  protected
    function GetIsAntParalysed : boolean; virtual; abstract;
    function GetLevel : integer; virtual; abstract;
    function GetPhysicalEntityList : tList; virtual; abstract;
    function GetRescuer : tPlayerEntity; virtual; abstract;
    function GetRescuee : tPlayerEntity; virtual; abstract;
    function GetRescueeHealth : _float; virtual; abstract;
    function GetRescueeOxygen : _float; virtual; abstract;
    function GetRescueeStamina : _float; virtual; abstract;
    function GetRescuerHealth : _float; virtual; abstract;
    function GetRescuerGrenades : integer; virtual; abstract;
    function GetRescuerOxygen : _float; virtual; abstract;
    function GetRescuerStamina : _float; virtual; abstract;
    function GetRescuerDirectionStrength : _float; virtual; abstract;
    function GetTime : _float; virtual; abstract;
  public
    property IsAntParalysed : boolean read GetIsAntParalysed;
    function IsRescueePresent : boolean;
    function IsRescuerPresent : boolean;
    property Level : integer read GetLevel;
    property PhysicalEntityList : tList read GetPhysicalEntityList;
    property Rescuer : tPlayerEntity read GetRescuer;
    property Rescuee : tPlayerEntity read GetRescuee;
    property RescueeHealth : _float read GetRescueeHealth;
    property RescueeOxygen : _float read GetRescueeOxygen;
    property RescueeStamina : _float read GetRescueeStamina;
    property RescuerGrenades : integer read GetRescuerGrenades;
    property RescuerHealth : _float read GetRescuerHealth;
    property RescuerOxygen : _float read GetRescuerOxygen;
    property RescuerStamina : _float read GetRescuerStamina;
    property RescuerDirectionStrength : _float read GetRescuerDirectionStrength;
    procedure ResetRenderingData; virtual;
    property Time : _float read GetTime;
  end;

  tGameStateInformation = class( tGameInformation )
  private
    GameState : tGameState;
    fIsAntParalysed : boolean;
    function GetEntityHealth( Entity : tPhysicalEntity ) : _float;
    function GetEntityOxygen( Entity : tPhysicalEntity ) : _float;
    function GetEntityStamina( Entity : tPhysicalEntity ) : _float;
  protected
    constructor Create( GameState : tGameState );
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
    procedure ResetRenderingData; override;
  end;

  tGameState = class( tObject )
  private
    fSharedStateData : tSharedStateData;
    fRescuer : tRescuer;
    fRescuee : tRescuee;
    fSpawnPointList : tList;
    fEntityList : tObjectList;
    fPhysicalEntityList : tList;
    fFirstPerson : boolean;
    fGameInformation : tGameStateInformation;
    fTime : _float;
    fNextSpawnTime : _float;
    fNextEntityID : cardinal;
    fAntCount : integer;
    fLevel : integer;
    fEntityTypes : tEntityTypeArray;
    fPlayerModel : array [ tGender ] of tModel;
    fBlockCollisionHandler : tEntityCollisionHandler;
    fInterEntityCollisionHandler : tEntityCollisionHandler;
    fEntityMover : tEntityMover;
    fOccupancyMap : tOccupancyMap;
    fThingList : tList;
    fUsedThings : tList;
    fPlayerInput : tPlayerInput;
    function    AddEntity( EntityTypeID : tEntityTypeID ) : tEntity;
    function    AddSensoryEntity( EntityTypeID : tEntityTypeId; Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSensoryEntity;
    procedure   CalculatePlayerVisibility;
    procedure   CheckForDeadEntities;
    procedure   CheckForDrowningEntities;
    function    FindClosestSpawnPoint : tThing;
    function    GetMap : tMap;
    function    GetThing( ThingType : tThingType ) : tThing;
    procedure   InitialiseGame;
    procedure   InitialiseParticipants;
    procedure   InitialiseSpawnPoints;
    function    IsFirstPerson : boolean;
    procedure   LogEntity( Entity : tEntity );
    procedure   ProcessEntityCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d );
    procedure   PurgeEntities;
    procedure   SetLevel( Level : integer );
    procedure   SetNextSpawnTime;
    procedure   SpawnAnts;
  public
    constructor Create( SharedStateData : tSharedStateData; PlayerInput : tPlayerInput );
    destructor  Destroy; override;
    function    AddAnt( Thing : tThing ) : tPhysicalEntity;
    function    AddExplosion( Source : tPhysicalEntity ) : tExplosion;
    function    AddGrenade( Source : tPlayerEntity; Location, Velocity : tPoint3d ) : tGrenade;
    function    AddHeart( Source : tPhysicalEntity; Location, Velocity : tPoint3d ) : tHeart;
    function    AddParticle( Source : tPhysicalEntity; EntityTypeID : tEntityTypeID; Location, Velocity : tPoint3d; LifeTime : _float ) : tParticle;
    function    AddPlayer( EntityTypeID : tEntityTypeID; Location : tPoint3d ) : tPlayerEntity;
    function    AddSmell( Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSmell;
    function    AddSound( Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSound;
    procedure   GetMapCentrePoint( Point : tPoint3d );
    function    GetNextEntityID : cardinal;
    procedure   InitialiseLevel;
    function    IsEntityInMap( Entity : tEntity ) : boolean;
    procedure   ProcessEntities( Interval : _float );
    procedure   RemoveEntity( Entity : tEntity ); overload;
    procedure   RemoveEntity( Idx : integer ); overload;
    property    EntityList : tObjectList read fEntityList;
    property    PhysicalEntityList : tList read fPhysicalEntityList;
    property    FirstPerson : boolean read IsFirstPerson write fFirstPerson;
    property    Information : tGameStateInformation read fGameInformation;
    property    Level : integer read fLevel write SetLevel;
    property    Rescuer : tRescuer read fRescuer;
    property    Rescuee : tRescuee read fRescuee;
    property    Map : tMap read GetMap;
    property    OccupancyMap : tOccupancyMap read fOccupancyMap;
    property    SharedStateData : tSharedStateData read fSharedStateData;
    property    Time : _float read fTime;
  end;

  tIntelligence = class( tObject )
  private
    fGameState : tGameState;
    fEntity : tPhysicalEntity;
  protected
    procedure   AdjustStamina( Adjustment : _float );
    function    GetEffectiveStamina : _float;
    property    Entity : tPhysicalEntity read fEntity;
    property    GameState : tGameState read fGameState;
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); virtual;
    procedure   Think; virtual;
  end;

  tEntityCollisionHandler = class( tObject )
  public
    procedure ProcessCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d ); virtual; abstract;
  end;

  tOccupancyMap = class( tObject )
  public
    procedure AddEntity( Entity : tPhysicalEntity ); virtual; abstract;
    procedure Clear; virtual; abstract;
    function  GetEntities( x, z : integer; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; overload; virtual; abstract;
    function  GetEntities( Origin : tPoint3d; Radius : _float; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; overload; virtual; abstract;
    function  GetEntities( const Rect : tRect; EntityList : tList; IgnoreEntity : tPhysicalEntity = nil ) : integer; overload; virtual; abstract;
  end;

const
  EntityTypeDescription : array [ tEntityTypeID ] of string = ( 'Rescuer', 'Rescuee', 'Ant', 'Grenade', 'Explosion', 'Sound', 'Smell', 'Dirt', 'Heart', 'Blood', 'Unknown' );

  GRAVITY = 9.81 * 2;

implementation

uses
  ApplicationStateData, Cube, Intelligence, AntIntelligence, RescuerIntelligence, RescueeIntelligence, BlockCollisions, GameModel, Log, Math, Messaging, Occupancy, Raycaster, Sense, SysUtils;

const
  MESSAGE_TIME = 2.0;
  AIRBORNE_EPSILON = 0.01;

  DEAD_LINGER_TIME = 20;
  DECAY_TIME = 5;

  OXYGEN_GAIN_RATE = 0.02;
  OXYGEN_LOSS_RATE = 0.03;

(* tEntityType *)

constructor tEntityType.Create( ID : tEntityTypeID; EntityClass : tEntityClass );
begin
  inherited Create;
  fID := ID;
  fBoundingBox := tBoundingBox.Create;
  fIntelligenceClass := tIntelligence;
  fFOV := 60;
  fEntityClass := EntityClass;
  fSolid := true;
  fHitPoints := 1;
  fMass := 1;
  fOwnModel := true;
end;

destructor tEntityType.Destroy;
begin
  fBoundingBox.Free;
  if OwnModel then
    fModel.Free;
  inherited;
end;

function tEntityType.CreateEntity( GameState : tGameState ) : tEntity;
begin
  result := EntityClass.Create( Self, GameState );
end;

class procedure tEntityType.CreateEntityTypes( const MapHeader : tMapHeader; var EntityTypes : tEntityTypeArray );
begin
  EntityTypes[ TYPE_RESCUER ] := Create( TYPE_RESCUER, tRescuer );
  InitialisePlayerEntityType( MapHeader, EntityTypes[ TYPE_RESCUER ], tRescuerIntelligence );

  EntityTypes[ TYPE_RESCUEE ] := Create( TYPE_RESCUEE, tRescuee );
  InitialisePlayerEntityType( MapHeader, EntityTypes[ TYPE_RESCUEE ], tRescueeIntelligence );

  EntityTypes[ TYPE_ANT ] := Create( TYPE_ANT, tAnt );
  with EntityTypes[ TYPE_ANT ] do
  begin
    HitPoints := MapHeader.AntHitPoints;
    Mass := 60;
    MaximumForce := 1.2 * Mass * 2;
    Friction := 0.5;
    ParalysisThreshold := 50;   // Force required to cause paralysis
    FOV := 90;
    BoundingBox.Initialise( 0.8, 0.9, 0.8, 0 );
    LungCapacity := 35;
    EyeOffset := 0.4;
    IntelligenceClass := tAntIntelligence;
    Visible := true;
    Model := CreateAntModel;
    SoundSource := true;
  end;

  EntityTypes[ TYPE_GRENADE ] := Create( TYPE_GRENADE, tGrenade );
  with EntityTypes[ TYPE_GRENADE ] do
  begin
    HitPoints := 3;
    Mass := 7;
    BoundingBox.Initialise( 0.1, 0.1, 0.2, 0 );
    Friction := 0.075;
    IntelligenceClass := tGrenadeIntelligence;
    Visible := true;
    Model := CreateGrenadeModel;
    SoundSource := true;
  end;

  EntityTypes[ TYPE_EXPLOSION ] := Create( TYPE_EXPLOSION, tExplosion );
  with EntityTypes[ TYPE_EXPLOSION ] do
  begin
    HitPoints := 1000;
    Mass := 0;      // We don't want gravity to affect our explosion
    BoundingBox.Initialise( 2.4, 2.4, 2.4, 0 );
    IntelligenceClass := tExplosionIntelligence;
    Visible := true;
    Solid := false;
    Model := CreateExplosionModel;
    SoundSource := true;
  end;

  EntityTypes[ TYPE_SOUND ] := Create( TYPE_SOUND, tSound );

  EntityTypes[ TYPE_SMELL ] := Create( TYPE_SMELL, tSmell );

  EntityTypes[ TYPE_DIRT ] := Create( TYPE_DIRT, tParticle );
  with EntityTypes[ TYPE_DIRT ] do
  begin
    Mass := 2;
    BoundingBox.Initialise( 0.2, 0.4, 0.2, 0 );
    Visible := true;
    Solid := false;
    Model := CreateDirtModel;
  end;

  EntityTypes[ TYPE_HEART ] := Create( TYPE_HEART, tHeart );
  with EntityTypes[ TYPE_HEART ] do
  begin
    BoundingBox.Initialise( 0.2, 0.175, 0.2, 0.2 );
    IntelligenceClass := tHeartIntelligence;
    Visible := true;
    Solid := false;
    Model := CreateHeartModel;
  end;

  EntityTypes[ TYPE_BLOOD ] := Create( TYPE_BLOOD, tParticle );
  with EntityTypes[ TYPE_BLOOD ] do
  begin
    BoundingBox.Initialise( 0.1, 0.1, 0.1, 0.005 );
    Mass := 2;
    Visible := true;
    Solid := false;
    Model := CreateBloodModel;
  end;
end;

class procedure tEntityType.InitialisePlayerEntityType( const MapHeader : tMapHeader; var EntityType : tEntityType; EntityIntelligenceClass : tIntelligenceClass );
begin
  with EntityType do
  begin
    HitPoints := MapHeader.HitPoints;
    Mass := 70;
    MaximumForce := 1.6 * Mass * 2;
    MaximumJumpForce := 3.5 * Mass * 2;
    Friction := 0.6;
    BoundingBox.Initialise( 0.25, 0.8, 0.25, 0 );
    LungCapacity := 10;
    HeartCapacity := 20;
    EyeOffset := 0.75;
    IntelligenceClass := EntityIntelligenceClass;
    Visible := true;
    Human := true;
    OwnModel := false;
    SoundSource := true;
  end;
end;

class procedure tEntityType.FreeEntityTypes( var EntityTypes : tEntityTypeArray );
var
  EntityTypeID : tEntityTypeID;
begin
  for EntityTypeID := Low( tEntityTypeID ) to High( tEntityTypeID ) do
    EntityTypes[ EntityTypeID ].Free;
end;

function tEntityType.GetCollisionFriction( EntityType : tEntityType ) : _float;
begin
  result := 0.5 * ( 1 - Friction ) * ( 1 - EntityType.Friction );
end;

function tEntityType.GetDescription : string;
begin
  result := EntityTypeDescription[ ID ];
end;

procedure tEntityType.SetModel( Model : tModel );
begin
  if OwnModel then
    FreeAndNil( fModel );
  fModel := Model;
end;

(* tEntity *)

constructor tEntity.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited Create;
  if GameState <> nil then
  begin
    fGameState := GameState;
    fID := GameState.GetNextEntityID;
    fCreateTime := GameState.Time;
  end;
  fEntityType := EntityType;
  fLocation := tPoint3d.create;
  fOwnerTypeID := TYPE_UNKNOWN;
end;

destructor tEntity.Destroy;
begin
  fLocation.Free;
  inherited;
end;

function tEntity.GetDistanceFromCentreSq : _float;
var
  x, y, z : _float;
begin
  x := Frac( Location.x );
  y := Frac( Location.y );
  z := Frac( Location.z );
  result := ( x * x ) + ( y * y ) + ( z * z );
end;

function tEntity.GetMapSquare : tIntPoint3d;
begin
  with Location do
  begin
    result.x := Floor( x );
    result.y := Floor( y );
    result.z := Floor( z );
  end;
end;

(* tPhysicalEntity *)

constructor tPhysicalEntity.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited;
  if GameState <> nil then
    fIntelligence := EntityType.fIntelligenceClass.Create( GameState, Self );
  fHitPoints := fEntityType.HitPoints;
  fOxygen := fEntityType.LungCapacity;
  fStamina := fEntityType.HeartCapacity;
  fForce := tPoint3d.create;
  fVelocity := tPoint3d.create;
  fTouchingList := tList.Create;
  fAnimationTime := CreateTime;
end;

destructor tPhysicalEntity.Destroy;
begin
  fTouchingList.Free;
  fVelocity.Free;
  fForce.Free;
  fIntelligence.Free;
  inherited;
end;

procedure tPhysicalEntity.ApplyForce( const Force : tPoint3d );
begin
  Self.Force.translate( Force );
  if Force.y > 0 then   // We don't want to damp the movement thinking we have just walked off of a wall - so we flag the entity as being externally launched
  begin
    Airborne := true;
    ExternallyLaunched := true;
  end;
end;

procedure tPhysicalEntity.DampLateralMovement;
const
  HORIZONTAL_DAMPING = 0.75;
begin
  Velocity.x := Velocity.x * HORIZONTAL_DAMPING;
  Velocity.z := Velocity.z * HORIZONTAL_DAMPING;
end;

function tPhysicalEntity.GetAngleFromFace( const Target : tPoint3d ) : _float;
var
  Difference : tPoint3d;
begin
  Difference := tPoint3d.Create;
  try
    result := GetAngleFromFace( Target, Difference );
  finally
    Difference.Free;
  end;
end;

function tPhysicalEntity.GetAngleFromFace( const Target : tPoint3d; Difference : tPoint3d ) : _float;
begin
  Difference.setLocation( Target );
  Difference.subtract( Location );

  if Difference.z = 0 then
    if Difference.x >= 0 then
      result := PI / 2
    else
      result := -PI / 2
  else
    result := ArcTan2( Difference.x, Difference.z );

  result := normaliseBearing( Orientation - result );
end;

function tPhysicalEntity.GetBoundingBox : tBoundingBox;
begin
  result := EntityType.BoundingBox;
end;

procedure tPhysicalEntity.GetBoundingBoxPoints( var Point : array of tPoint3d; Rotate : boolean; Location : tPoint3d );
var
  Idx : integer;
  BBPoint : tPoint3d;
begin
  if Location = nil then
    Location := Self.Location;

  for Idx := 0 to 7 do
  begin
    BBPoint := Point[ Idx ];
    BoundingBox.GetPoint( Idx, BBPoint );
    BBPoint.Translate( Location );
  end;

  if Rotate then
    for Idx := 0 to 7 do
      Point[ Idx ].rotateY( Orientation );
end;

function tPhysicalEntity.GetMapRectangle : tRect;
var
  BB : tBoundingBox;
begin
  BB := BoundingBox;
  result.Left := Floor( Location.x + BB.Left );
  result.Right := Floor( Location.x + BB.Right );
  result.Top := Floor( Location.z + BB.Far );
  result.Bottom := Floor( Location.z + BB.Near );
end;

procedure tPhysicalEntity.InitialiseFromThing( Thing : tThing );
begin
  with Thing.Info do
  begin
    with Position do
      Self.Location.setLocation( x + 0.5, y, z + 0.5 );
    Self.Orientation := Orientation;
    if Thing.Info.ThingType = THING_SPAWN then
      Self.Location.y := Self.Location.y - 1;
  end;
end;

function tPhysicalEntity.IsActive : boolean;
begin
  result := State = STATE_MOBILE;
end;

function tPhysicalEntity.IsAnimationComplete : boolean;
begin
  result := ( EntityType.Model <> nil ) and ( GameState.Time - AnimationTime >= EntityType.Model.Animation[ Animation ].Length );
end;

function tPhysicalEntity.IsEntityReachable( Entity : tPhysicalEntity; OverrideLocation : tPoint3d ) : boolean;
var
  dx, dz : _float;
  x1, x2 : _float;
  y1, y2 : _float;
  z1, z2 : _float;
  tx, tz : _float;
  t : _float;
  bb1 : tBoundingBox;
  Target : tPoint3d;
begin
  if OverrideLocation = nil then
    OverrideLocation := Entity.Location;

  x1 := Location.x;
  x2 := OverrideLocation.x;
  y1 := Location.y;
  y2 := OverrideLocation.y;
  z1 := Location.z;
  z2 := OverrideLocation.z;
  bb1 := BoundingBox;

  if Floor( y1 ) <> Floor( y2 ) then
  begin
    result := false;
    exit;
  end;

  dx := x2 - x1;                  // Calculates the parametric distance between current x and target x, based on the current entity's bounding box reaching the target point
  if dx > 0 then                  // Note that this doesn't include the target's bounding box (e.g, tx := (dx - bb1.Right + bb2.Left). This was included,
    tx := ( dx - bb1.Right ) / dx // but it caused problems because entities hanging in the air could be deemed reachable.
  else if dx < 0 then
    tx := ( dx - bb1.Left ) / dx
  else
    tx := 0;

  dz := z2 - z1;      // Do the same for Z
  if dz > 0 then
    tz := ( dz - bb1.Near ) / dz
  else if dz < 0 then
    tz := ( dz - bb1.Far ) / dz
  else
    tz := 0;

  if ( tx > 0 ) or ( tz > 0 ) then      // If we are not already too close ( values will be negative if so )
  begin
    if tx > tz then
      t := tx
    else
      t := tz;
    Target := tPoint3d.Create( x1 + dx * t, y1 + ( y2 - y1 ) * t, z1 + dz * t );
    try
      result := IsPointReachable( Target );
    finally
      Target.Free;
    end;
  end
  else
    result := true;
end;

function tPhysicalEntity.IsExpired : boolean;
begin
  result := ( STATE = STATE_UNUSED ) or ( ( State = STATE_DEAD ) and ( GameState.Time - DeadTime >= DEAD_LINGER_TIME ) and not EntityType.Human );
end;

function tPhysicalEntity.IsPointReachable( Target : tPoint3d ) : boolean;
var
  Idx : integer;
  sy, fy : integer;
  Start, Finish : tPoint3d;
  BB : tBoundingBox;
  Raycaster : tRaycaster;
  Horizontal, Vertical : array [ 0 .. 1 ] of _float;
begin
  sy := Floor( Location.y );
  fy := Floor( Target.y );
  if sy = fy then
  begin
    Raycaster := tRaycaster.Create;
    try
      BB := BoundingBox;
      Start := tPoint3d.Create;
      try
        Finish := tPoint3d.Create;
        try
          if sy > 0 then
          begin
            Start.setLocation( Location );
            Start.y := Start.y - 1;
            Finish.setLocation( Target );
            Finish.y := Finish.y - 1;
            result := Raycaster.traceRay( GameState.Map, Start, Finish, nil, false );   // Trace underground to ensure everything is solid
          end
          else
            result := true;
          if result then
          begin
            Horizontal[ 0 ] := BB.Left;
            Horizontal[ 1 ] := BB.Right;
            Vertical[ 0 ] := BB.Far;
            Vertical[ 1 ] := BB.Near;
            Idx := 0;
            repeat
              Start.setLocation( Horizontal[ Idx and 1 ], BB.Top / 2, Vertical[ Idx shr 1 ] );
              // We don't need to rotate by the orientation, because the collision detection works with axis-aligned bounding boxes
              // Start.rotateY( Orientation );
              Finish.setLocation( Start );
              Start.translate( Location );
              Finish.translate( Target );
              result := Raycaster.traceRay( GameState.Map, Start, Finish );
              inc( Idx );
            until ( Idx = 4 ) or not result;
          end;
        finally
          Finish.Free;
        end;
      finally
        Start.Free;
      end;
    finally
      Raycaster.Free;
    end;
  end
  else
    result := false;
end;

procedure tPhysicalEntity.SetAnimation( Animation : cardinal );
var
  Model : tModel;
begin
  Model := EntityType.Model;
  if ( fAnimation <> Animation ) and ( Model <> nil ) and ( IsAnimationComplete or ( Model.Animation[ fAnimation ].GroupID <> Model.Animation[ Animation ].GroupID ) ) then
  begin
    fAnimation := Animation;
    fAnimationTime := GameState.Time;
  end;
end;

function tPhysicalEntity.GetDecay : _float;
begin
  if ( State = STATE_DEAD ) and ( GameState.Time - DeadTime >= DEAD_LINGER_TIME - DECAY_TIME ) then
    result := ( DEAD_LINGER_TIME - GameState.Time + DeadTime ) / DECAY_TIME
  else
    result := 1;
end;

procedure tPhysicalEntity.SetOrientation( Orientation : _float );
begin
  fOrientation := NormaliseBearing( Orientation );
end;

procedure tPhysicalEntity.SetState( State : tPhysicalEntityState );
begin
  fState := State;
end;

procedure tPhysicalEntity.TakeDamage( Damage : _float; Cause : tEntityTypeId );
var
  NoisyIntelligence : tNoisyIntelligence;
begin
  if GameState.SharedStateData.Invulnerable and ( self is tPlayerEntity ) then
    exit;

  if fHitPoints > 0 then
  begin
    fHitPoints := fHitPoints - Damage;
    if fHitPoints < 0.001 then
      fHitPoints := 0;
    fLastDamageCause := Cause;
    if EntityType.SoundSource then
    begin
      NoisyIntelligence := tNoisyIntelligence( Intelligence );
      if fHitPoints > 0 then
      begin
        if Damage > 0.5 then
          NoisyIntelligence.ProducePainSound;
      end
      else
        NoisyIntelligence.ProduceDeathSound;
    end;
  end;
end;

(* tDeformablePhysicalEntity *)

constructor tDeformablePhysicalEntity.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited;
  fBoundingBox := tBoundingBox.Create;
end;

destructor tDeformablePhysicalEntity.Destroy;
begin
  fBoundingBox.Free;
  inherited;
end;

function tDeformablePhysicalEntity.GetBoundingBox : tBoundingBox;
var
  Size : tFloatPoint2d;
begin
  if State = STATE_DEAD then
  begin
    Size := GetDeadSize;
    Size.y := Size.y * GetDecay;
    fBoundingBox.Assign( EntityType.BoundingBox );
    if Size.y <> 0 then
      fBoundingBox.Top := Size.y;
    if Size.x <> 0 then
    begin
      fBoundingBox.Left := -Size.x;
      fBoundingBox.Right := Size.x;
      fBoundingBox.Far := -Size.x;
      fBoundingBox.Near := Size.x;
    end;
    result := fBoundingBox;
  end
  else
    result := EntityType.BoundingBox;
end;

(* tPlayerEntity *)

constructor tPlayerEntity.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited;
  fVisibility := 1;
end;

function tPlayerEntity.GetDeadSize : tFloatPoint2d;
begin
  result.x := 0.35;
  result.y := 0.1;
end;

(* tAnt *)

constructor tAnt.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited;
  if GameState <> nil then
    fGameInformation := GameState.fGameInformation;
end;

function tAnt.GetDeadSize : tFloatPoint2d;
begin
  result.x := 0;
  result.y := 0.55;
end;

procedure tAnt.SetState( State : tPhysicalEntityState );
begin
  inherited;
  if State = STATE_PARALYSED then
    fGameInformation.fIsAntParalysed := true;
end;

(* tGrenade *)

constructor tGrenade.Create( EntityType : tEntityType; GameState : tGameState );
begin
  inherited;
  fOrigin := tPoint3d.Create;
end;

procedure tGrenade.ApplyForce( const Force : tPoint3d );
begin
  inherited;
  tNoisyIntelligence( Intelligence ).ResetSound;
end;

destructor tGrenade.Destroy;
begin
  fOrigin.Free;
  inherited;
end;

(* tSensoryEntity *)

function tSensoryEntity.GetCurrentMagnitude : _float;
var
  Delta : _float;
begin
  Delta := GameState.Time - CreateTime;
  if Delta < LifeTime then
    result := Magnitude * ( 1 - Delta / LifeTime )
  else
    result := 0;
end;

function tSensoryEntity.IsExpired : boolean;
begin
  result := GameState.Time - CreateTime >= LifeTime;
end;

(* tParticle *)

function tParticle.IsExpired : boolean;
begin
  result := GameState.Time - CreateTime >= LifeTime;
end;

(* tIntelligence *)

constructor tIntelligence.Create( GameState : tGameState; Entity : tPhysicalEntity );
begin
  inherited Create;
  fGameState := GameState;
  fEntity := Entity;
end;

procedure tIntelligence.AdjustStamina( Adjustment : _float );
var
  MaximumStamina, MinimumStamina : _float;
begin
  with Entity do
  begin
    Stamina := Stamina + Adjustment;

    MaximumStamina := EntityType.HeartCapacity;
    if GameState.Rescuer.State = STATE_ESCAPED then
      MinimumStamina := MaximumStamina
    else
      MinimumStamina := 0;

    if Stamina > MaximumStamina then
      Stamina := MaximumStamina
    else if Stamina < MinimumStamina then
      Stamina := MinimumStamina;
  end;
end;

function tIntelligence.GetEffectiveStamina : _float;
begin
  result := 0;
  if Entity.EntityType.HeartCapacity > 0 then
    result := Min( 1, 1.5 * Entity.Stamina / Entity.EntityType.HeartCapacity );
end;

procedure tIntelligence.Think;
begin
end;

(* tEntityMover *)

constructor tEntityMover.Create;
begin
  inherited;
  Acceleration := tPoint3d.Create;
  Velocity := tPoint3d.Create;
  Location := tPoint3d.Create;
end;

destructor tEntityMover.Destroy;
begin
  Location.Free;
  Velocity.Free;
  Acceleration.Free;
  inherited;
end;

procedure tEntityMover.MoveEntity( Entity : tPhysicalEntity; Interval : _float );
begin
  if Entity.EntityType.Mass = 0 then
    exit;

  if not Entity.Airborne then
    Entity.Velocity.scale( 1.0 - Entity.EntityType.Friction );

  Acceleration.setLocation( Entity.Force );
  Acceleration.scale( 1 / Interval );
  Acceleration.scale( 1 / Entity.EntityType.Mass );
  Acceleration.y := Acceleration.y - GRAVITY;

  Velocity.setLocation( Entity.Velocity );
  Velocity.scale( Interval );

  Location.setLocation( Acceleration );
  Location.scale( Interval * Interval );
  Location.translate( Velocity );

  Entity.Location.translate( Location );

  Velocity.setLocation( Acceleration );
  Velocity.scale( Interval );
  Entity.Velocity.translate( Velocity );

  Entity.Force.Reset;
end;

(* tGameInformation *)

function tGameInformation.IsRescuerPresent : boolean;
begin
  result := Rescuer <> nil;
end;

function tGameInformation.IsRescueePresent : boolean;
begin
  result := Rescuee <> nil;
end;

procedure tGameInformation.ResetRenderingData;
begin
end;

(* tGameStateInformation *)

constructor tGameStateInformation.Create( GameState : tGameState );
begin
  inherited Create;
  Self.GameState := GameState;
end;

function tGameStateInformation.GetEntityHealth( Entity : tPhysicalEntity ) : _float;
begin
  if Entity <> nil then
    result := Entity.HitPoints / Entity.EntityType.HitPoints
  else
    result := 0;
end;

function tGameStateInformation.GetEntityOxygen( Entity : tPhysicalEntity ) : _float;
begin
  if Entity <> nil then
    result := Entity.Oxygen / Entity.EntityType.LungCapacity
  else
    result := 0;
end;

function tGameStateInformation.GetEntityStamina( Entity : tPhysicalEntity ) : _float;
begin
  if Entity <> nil then
    result := Entity.Stamina / Entity.EntityType.HeartCapacity
  else
    result := 0;
end;

function tGameStateInformation.GetIsAntParalysed : boolean;
begin
  result := fIsAntParalysed;
end;

function tGameStateInformation.GetLevel : integer;
begin
  result := GameState.Level;
end;

function tGameStateInformation.GetPhysicalEntityList : tList;
begin
  result := GameState.PhysicalEntityList;
end;

function tGameStateInformation.GetRescuer : tPlayerEntity;
begin
  result := GameState.Rescuer;
end;

function tGameStateInformation.GetRescuee : tPlayerEntity;
begin
  result := GameState.Rescuee;
end;

function tGameStateInformation.GetRescuerGrenades : integer;
begin
  result := GameState.Rescuer.Grenades;
end;

function tGameStateInformation.GetRescueeHealth : _float;
begin
  result := GetEntityHealth( GameState.Rescuee );
end;

function tGameStateInformation.GetRescueeOxygen : _float;
begin
  result := GetEntityOxygen( GameState.Rescuee );
end;

function tGameStateInformation.GetRescueeStamina : _float;
begin
  result := GetEntityStamina( GameState.Rescuee );
end;

function tGameStateInformation.GetRescuerHealth : _float;
begin
  result := GetEntityHealth( GameState.Rescuer );
end;

function tGameStateInformation.GetRescuerOxygen : _float;
begin
  result := GetEntityOxygen( GameState.Rescuer );
end;

function tGameStateInformation.GetRescuerStamina : _float;
begin
  result := GetEntityStamina( GameState.Rescuer );
end;

function tGameStateInformation.GetRescuerDirectionStrength : _float;
begin
  if IsRescueePresent then
    result := ( PI - Abs( GameState.Rescuer.GetAngleFromFace( GameState.Rescuee.Location ) ) ) / PI
  else
    result := 0;
end;

function tGameStateInformation.GetTime : _float;
begin
  result := GameState.Time;
end;

procedure tGameStateInformation.ResetRenderingData;
begin
  fIsAntParalysed := false;
end;

(* tGameState *)

constructor tGameState.Create( SharedStateData : tSharedStateData; PlayerInput : tPlayerInput );
begin
  inherited Create;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - ENTER' );


SharedStateData.Log( LOG_ALL, 'tGameState.Create - CREATE SIMPLE OBJECTS' );

  fSharedStateData := SharedStateData;
  fPlayerInput := PlayerInput;
  fBlockCollisionHandler := tBlockCollisions.Create( Self );
  fInterEntityCollisionHandler := tInterEntityCollisions.Create( Self );
  fEntityMover := tEntityMover.Create;
  fOccupancyMap := tEntityOccupancyMap.Create;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - CREATE ENTITY TYPES' );

  tEntityType.CreateEntityTypes( Map.Header^, fEntityTypes );
  fEntityList := tObjectList.Create;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - CREATE MALE MODEL' );

  fPlayerModel[ GENDER_MALE ] := CreateMaleModel;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - CREATE FEMALE MODEL' );

  fPlayerModel[ GENDER_FEMALE ] := CreateFemaleModel;
  fPhysicalEntityList := tList.Create;
  fSpawnPointList := tList.Create;
  fThingList := tList.Create;
  fUsedThings := tList.Create;
  fFirstPerson := false;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - CREATE GAME STATE INFORMATION' );

  fGameInformation := tGameStateInformation.Create( Self );

SharedStateData.Log( LOG_ALL, 'tGameState.Create - INITIALISE GAME' );

  InitialiseGame;

SharedStateData.Log( LOG_ALL, 'tGameState.Create - EXIT' );
end;

destructor tGameState.Destroy;
begin
  tEntityType.FreeEntityTypes( fEntityTypes );
  fGameInformation.Free;
  fPlayerModel[ GENDER_MALE ].Free;
  fPlayerModel[ GENDER_FEMALE ].Free;
  fOccupancyMap.Free;
  fEntityMover.Free;
  fInterEntityCollisionHandler.Free;
  fBlockCollisionHandler.Free;
  fUsedThings.Free;
  fThingList.Free;
  fSpawnPointList.Free;
  fEntityList.Free;
  fPhysicalEntityList.Free;
  inherited;
end;

function tGameState.AddAnt( Thing : tThing ) : tPhysicalEntity;
begin
  result := tPhysicalEntity( AddEntity( TYPE_ANT ) );
  result.InitialiseFromThing( Thing );
  if Thing.Info.ThingType = THING_SPAWN then
  begin
    result.State := STATE_EMERGING;
    SetNextSpawnTime;
  end;
  LogEntity( result );
  inc( fAntCount );
end;

function tGameState.AddExplosion( Source : tPhysicalEntity ) : tExplosion;
begin
  result := tExplosion( AddEntity( TYPE_EXPLOSION ) );
  result.fOwnerTypeID := Source.OwnerTypeID;
  result.fLocation.setLocation( Source.Location );
  LogEntity( result );
end;

function tGameState.AddGrenade( Source : tPlayerEntity; Location, Velocity : tPoint3d ) : tGrenade;
begin
  if Source.Grenades > 0 then
  begin
    Source.Grenades := Source.Grenades - 1;
    result := tGrenade( AddEntity( TYPE_GRENADE ) );
    result.fOwnerTypeID := Source.EntityType.ID;
    result.fOrigin.setLocation( Source.Location );
    result.fLocation.setLocation( Location );
    result.fVelocity.setLocation( Velocity );
    LogEntity( result );
  end
  else
    result := nil;
end;

function tGameState.AddHeart( Source : tPhysicalEntity; Location, Velocity : tPoint3d ) : tHeart;
begin
  result := tHeart( AddEntity( TYPE_HEART ) );
  result.fOwnerTypeID := Source.EntityType.ID;
  result.fLocation.setLocation( Location );
  result.fVelocity.setLocation( Velocity );
  LogEntity( result );
end;

function tGameState.AddParticle( Source : tPhysicalEntity; EntityTypeID : tEntityTypeID; Location, Velocity : tPoint3d; LifeTime : _float ) : tParticle;
begin
  result := tParticle( AddEntity( EntityTypeID ) );
  result.fOwnerTypeID := Source.EntityType.ID;
  result.fLocation.setLocation( Location );
  result.fVelocity.setLocation( Velocity );
  result.fLifeTime := LifeTime;
  LogEntity( result );
end;

function tGameState.AddPlayer( EntityTypeID : tEntityTypeID; Location : tPoint3d ) : tPlayerEntity;
begin
  result := tPlayerEntity( AddEntity( EntityTypeID ) );
  result.Grenades := Map.Header^.Grenades;
  if Location <> nil then
    result.fLocation.setLocation( Location );
end;

function tGameState.AddSensoryEntity( EntityTypeID : tEntityTypeId; Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSensoryEntity;
begin
  result := tSensoryEntity( AddEntity( EntityTypeID ) );
  result.fOwnerTypeID := Source.EntityType.ID;
  result.fLocation.setLocation( Source.Location );
  result.fMagnitude := Magnitude;
  result.fLifeTime := LifeTime;
  LogEntity( result );
end;

function tGameState.AddSmell( Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSmell;
begin
  result := tSmell( AddSensoryEntity( TYPE_SMELL, Source, Magnitude, LifeTime ) );
end;

function tGameState.AddSound( Source : tPhysicalEntity; Magnitude, LifeTime : _float ) : tSound;
begin
  result := tSound( AddSensoryEntity( TYPE_SOUND, Source, Magnitude, LifeTime ) );
end;

function tGameState.AddEntity( EntityTypeID : tEntityTypeID ) : tEntity;
var
  EntityType : tEntityType;
begin
  EntityType := fEntityTypes[ EntityTypeID ];
  result := EntityType.CreateEntity( Self );
  fEntityList.Add( result );
  if EntityType.Visible then
    fPhysicalEntityList.Add( result );
end;

procedure tGameState.CalculatePlayerVisibility;
var
  Raycaster : tRaycaster;
  AmbientVisibility : _float;
  Start, Finish : tPoint3d;

procedure CalculateVisibility( Player : tPlayerEntity );
const
  RAYS = 4;
var
  Idx : integer;
  YStep : _float;
begin
  if Player <> nil then
  begin
    if AmbientVisibility < 1 then
    begin
      YStep := ( Player.BoundingBox.Bottom + Player.BoundingBox.Top ) / ( RAYS + 1 );
      Player.fVisibility := 0;
      Start.setLocation( Player.Location );
      for Idx := 1 to RAYS do
      begin
        Start.y := Start.y + YStep;
        if Raycaster.traceRay( Map, Start, Finish ) then
          Player.fVisibility := Player.fVisibility + 1;
      end;
      Player.fVisibility := AmbientVisibility + Player.fVisibility / RAYS;
    end
    else
      Player.fVisibility := AmbientVisibility;

    if Player.fVisibility > 1 then
      Player.fVisibility := 1;
  end;
end;

begin
  Raycaster := tRaycaster.Create;
  try
    Start := tPoint3d.Create( tApplicationStateData( SharedStateData ).Renderer.LightMapManager.LightPosition );
    try
      Finish := tPoint3d.Create( Start );
      try
        Start.normalise;
        AmbientVisibility := 0.1 + Start.y * 0.8;     // Calculate Ambient Visibility based on height of sun in the sky
        CalculateVisibility( Rescuer );
        CalculateVisibility( Rescuee );
      finally
        Finish.Free;
      end;
    finally
      Start.Free;
    end;
  finally
    Raycaster.Free;
  end;
end;

procedure tGameState.CheckForDeadEntities;
var
  Idx : integer;
  PhysicalEntity : tPhysicalEntity;
begin
  for Idx := 0 to PhysicalEntityList.Count - 1 do
  begin
    PhysicalEntity := tPhysicalEntity( PhysicalEntityList[ Idx ] );
    if ( PhysicalEntity.State < STATE_DEAD ) and ( PhysicalEntity.HitPoints <= 0 ) then
    begin
      PhysicalEntity.State := STATE_DEAD;
      PhysicalEntity.DeadTime := Time;
    end;
  end;
end;

procedure tGameState.CheckForDrowningEntities;
var
  Idx : integer;
  PhysicalEntity : tPhysicalEntity;
  Point : tPoint3d;
begin
  Point := tPoint3d.Create;
  try
    for Idx := 0 to PhysicalEntityList.Count - 1 do
    begin
      PhysicalEntity := tPhysicalEntity( PhysicalEntityList[ Idx ] );
      if ( PhysicalEntity.State < STATE_DEAD ) and ( PhysicalEntity.EntityType.LungCapacity > 0 ) then
      begin
        Point.setLocation( PhysicalEntity.Location );
        Point.y := Point.y + PhysicalEntity.EntityType.EyeOffset;
        if not Map.isPointInWater( Point ) then
        begin
          PhysicalEntity.fOxygen := PhysicalEntity.Oxygen + OXYGEN_GAIN_RATE;
          if PhysicalEntity.Oxygen > PhysicalEntity.EntityType.LungCapacity then
            PhysicalEntity.fOxygen := PhysicalEntity.EntityType.LungCapacity;
        end
        else
        begin
          PhysicalEntity.fOxygen := PhysicalEntity.Oxygen - OXYGEN_LOSS_RATE;
          if PhysicalEntity.Oxygen < 0 then
            PhysicalEntity.TakeDamage( PhysicalEntity.HitPoints, TYPE_UNKNOWN );
        end;
      end;
    end;
  finally
    Point.Free;
  end;
end;

// This routine finds the three closest spawn points and chooses one of them at random
function tGameState.FindClosestSpawnPoint : tThing;
var
  Idx : integer;
  SIdx : integer;
  PIdx : integer;
  Distance : _float;
  SpawnPoint : tThing;
  BestDistance : array [ 0 .. 2 ] of _float;
  BestSpawnPoint : array [ 0 .. 2 ] of tThing;
begin
  result := nil;
  if Rescuer <> nil then
  begin
    for SIdx := Low( BestDistance ) to High( BestDistance ) do
      BestDistance[ SIdx ] := 1000000000;
    BestSpawnPoint[ 0 ] := nil;

    for Idx := 0 to fSpawnPointList.Count - 1 do
    begin
      SpawnPoint := tThing( fSpawnPointList[ Idx ] );
      Distance := Sqr( Rescuer.Location.x - SpawnPoint.Info.Position.x ) + Sqr( Rescuer.Location.z - SpawnPoint.Info.Position.z );
      SIdx := 0;
      repeat
        if Distance < BestDistance[ SIdx ] then
        begin
          for PIdx := High( BestDistance ) - 1 downto SIdx do
          begin
            BestDistance[ PIdx + 1 ] := BestDistance[ PIdx ];
            BestSpawnPoint[ PIdx + 1 ] := BestSpawnPoint[ PIdx ];
          end;
          BestDistance[ SIdx ] := Distance;
          BestSpawnPoint[ SIdx ] := SpawnPoint;
          break;
        end;
        inc( SIdx );
      until SIdx > High( BestDistance );
    end;

    if fSpawnPointList.Count < Length( BestDistance ) then
      Idx := fSpawnPointList.Count
    else
      Idx := Length( BestDistance );
    result := BestSpawnPoint[ Random( Idx ) ];
  end;
end;

procedure tGameState.GetMapCentrePoint( Point : tPoint3d );
begin
  Point.setLocation( Map.Width div 2 + 0.5, 0, Map.Height div 2 + 0.5 );
end;

function tGameState.GetNextEntityID : cardinal;
begin
  inc( fNextEntityID );
  result := fNextEntityID;
end;

function tGameState.GetMap : tMap;
begin
  result := SharedStateData.Map;
end;

function tGameState.GetThing( ThingType : tThingType ) : tThing;

procedure GetThings;
begin
  SharedStateData.Map.getThings( ThingType, fLevel, fThingList );
end;

procedure RemoveThings( Source, Target : tList );
var
  Idx : integer;
begin
  for Idx := 0 to Source.Count - 1 do
    Target.Remove( Source[ Idx ] );
end;

var
  Idx : integer;
begin
  result := nil;
  GetThings;
  if fThingList.Count > 0 then
  begin
    RemoveThings( fUsedThings, fThingList );
    if fThingList.Count = 0 then
    begin
      GetThings;
      RemoveThings( fThingList, fUsedThings );
    end;
    Idx := Random( fThingList.Count );
    result := fThingList[ Idx ];
    fUsedThings.Add( result );
  end;
end;

procedure tGameState.InitialiseGame;
begin
  fLevel := 1;
  fUsedThings.Clear;
  InitialiseLevel;
end;

procedure tGameState.InitialiseLevel;
begin
  fTime := 0;
  fAntCount := 0;
  fEntityList.Clear;
  fPhysicalEntityList.Clear;
  SetNextSpawnTime;
  InitialiseParticipants;
  InitialiseSpawnPoints;
  fSharedStateData.AddMessage( 'Level ' + IntToStr( Level ), 12, 3000 ).SetPosition( 0, -0.7 ).SetFadeTime( 1000 ).SetColour( 255, 255, 255, 255 );
end;

procedure tGameState.InitialiseParticipants;

function InitialiseParticipant( EntityTypeID : tEntityTypeID; Gender : tGender; InitialState : tPhysicalEntityState; ThingType : tThingType; PlayerInput : tPlayerInput ) : boolean;
var
  Thing : tThing;
  PlayerEntity : tPlayerEntity;
begin
  Thing := GetThing( ThingType );
  result := Thing <> nil;
  if result or ( EntityTypeID = TYPE_RESCUER ) then
  begin
    PlayerEntity := AddPlayer( EntityTypeID, nil );
    PlayerEntity.fGender := Gender;
    PlayerEntity.EntityType.Model := fPlayerModel[ Gender ];
    with PlayerEntity do
    begin
      State := InitialState;
      FireDelay := 0;

      if result then
        PlayerEntity.InitialiseFromThing( Thing );
      LogEntity( PlayerEntity );
    end;
  end
  else
    PlayerEntity := nil;

  if EntityTypeID = TYPE_RESCUER then
    fRescuer := tRescuer( PlayerEntity )
  else
    fRescuee := tRescuee( PlayerEntity );

  // v1.0.6 - Have an initial "think" to avoid glitches when rendering new state before first think.
  if PlayerEntity <> nil then
  begin
    if PlayerInput <> nil then
      tRescuerIntelligence( PlayerEntity.Intelligence ).PlayerInput := PlayerInput;
    PlayerEntity.Intelligence.Think;
  end;
end;

procedure InitialisePrePlacedAnts;
var
  Idx : integer;
  AntList : tList;
begin
  AntList := tList.Create;
  try
    Map.getThings( THING_ANT, Level, AntList );
    Idx := 0;
    while ( Idx < AntList.Count ) and ( fAntCount < Map.Level[ Level ].Info.AntCount ) do
    begin
      AddAnt( tThing( AntList[ Idx ] ) );
      inc( Idx );
    end;
  finally
    AntList.Free;
  end;
end;

begin
  if not InitialiseParticipant( TYPE_RESCUER, SharedStateData.RescuerGender, STATE_MOBILE, THING_START, fPlayerInput ) then
  begin
    fRescuer.Location.SetLocation( Map.Width div 2 + 0.5, MAP_SIZE_COLUMN + 1, Map.Height div 2 + 0.5 );
    fRescuer.Orientation := PI * 3 / 4;
  end;

  InitialiseParticipant( TYPE_RESCUEE, SharedStateData.RescueeGender, STATE_QUIESCENT, THING_RESCUEE, nil );

  InitialisePrePlacedAnts;
end;

procedure tGameState.InitialiseSpawnPoints;
begin
  Map.getThings( THING_SPAWN, Level, fSpawnPointList );
end;

function tGameState.IsEntityInMap( Entity : tEntity ) : boolean;
begin
  with Entity.Location do
    result := ( x >= -1 ) and ( x <= Map.Width ) and ( z >= -1 ) and ( z <= Map.Height );    // Include a one unit border around the map that must be cleared
end;

function tGameState.IsFirstPerson : boolean;
begin
  result := ( fFirstPerson or Map.isFlagSet( MAP_FLAG_1ST_PERSON_ONLY ) ) and ( Rescuer.State <> STATE_DEAD );
end;

procedure tGameState.LogEntity( Entity : tEntity );
begin
  if SharedStateData.IsLogEnabled then
    SharedStateData.Log( LOG_GAME, 'Entity created: ID=%d, Type=%s, Location=%s, OwnerType=%s', [ Entity.ID, EntityTypeDescription[ Entity.EntityType.ID ], Entity.Location.toString, EntityTypeDescription[ Entity.OwnerTypeID ] ] );
end;

procedure tGameState.ProcessEntityCollisions( Entity : tPhysicalEntity; LastLocation : tPoint3d );
begin
  if Entity.EntityType.Solid then
  begin
    fBlockCollisionHandler.ProcessCollisions( Entity, LastLocation );
    fInterEntityCollisionHandler.ProcessCollisions( Entity, LastLocation );
  end;
end;

procedure tGameState.ProcessEntities( Interval : _float );
var
  Idx, Count : integer;
  PhysicalEntity : tPhysicalEntity;
  LastLocation : tPoint3d;
begin
  fTime := fTime + Interval;
  LastLocation := tPoint3d.Create;
  try
    Count := PhysicalEntityList.Count - 1;

    // 1. Build Occupancy Map
    OccupancyMap.Clear;
    for Idx := 0 to Count do
      OccupancyMap.AddEntity( tPhysicalEntity( PhysicalEntityList[ Idx ] ) );

    // 2. Calculate Player Visibility
    CalculatePlayerVisibility;

    // 3. Spawn Ants
    SpawnAnts;

    // 4. Perform physics and collision handling
    for Idx := 0 to Count do
    begin
      PhysicalEntity := tPhysicalEntity( PhysicalEntityList[ Idx ] );
      LastLocation.SetLocation( PhysicalEntity.Location );
      fEntityMover.MoveEntity( PhysicalEntity, Interval );
      ProcessEntityCollisions( PhysicalEntity, LastLocation );
    end;

    // 5. Execute AI Procedures
    for Idx := 0 to Count do
    begin
      PhysicalEntity := tPhysicalEntity( PhysicalEntityList[ Idx ] );
      PhysicalEntity.Intelligence.Think;
      PhysicalEntity.TouchingList.Clear;
    end;

    CheckForDrowningEntities;
    CheckForDeadEntities;
    PurgeEntities;
  finally
    LastLocation.Free;
  end;
end;

procedure tGameState.PurgeEntities;
var
  Idx : integer;
  Entity : tEntity;
begin
  for Idx := EntityList.Count - 1 downto 0 do
  begin
    Entity := tEntity( EntityList[ Idx ] );
    if Entity.IsExpired then
    begin
      if Entity.EntityType.Visible then
      begin
        if Entity.EntityType.ID = TYPE_ANT then
          dec( fAntCount );
        PhysicalEntityList.Remove( Entity );
      end;
      EntityList.Delete( Idx );
    end;
  end;
end;

procedure tGameState.RemoveEntity( Entity : tEntity );
begin
  if Entity.EntityType.Visible then
    fPhysicalEntityList.Remove( Entity );
  fEntityList.Remove( Entity );
end;

procedure tGameState.RemoveEntity( Idx : integer );
var
  Entity : tEntity;
begin
  Entity := fEntitylist[ Idx ];
  if Entity.EntityType.Visible then
    fPhysicalEntityList.Remove( Entity );
  fEntityList.Delete( Idx );
end;

procedure tGameState.SetLevel( Level : integer );
begin
  if fLevel <> Level then
  begin
    fLevel := Level;
    InitialiseLevel;
  end;
end;

procedure tGameState.SetNextSpawnTime;
begin
  fNextSpawnTime := fTime + Map.Level[ Level ].Info.SpawnInterval * ( 1 + 2 * Random );
end;

procedure tGameState.SpawnAnts;
var
  Idx : integer;
  SpawnPoint : tThing;
  EntityList : tList;
  SpawnPointBusy : boolean;
begin
  if ( fTime >= fNextSpawnTime ) and ( fAntCount < Map.Level[ Level ].Info.AntCount ) and ( fSpawnPointList.Count > 0 ) then
  begin
    SpawnPoint := FindClosestSpawnPoint;

    SpawnPointBusy := false;
    EntityList := tList.Create;
    try
      OccupancyMap.GetEntities( SpawnPoint.Info.Position.x, SpawnPoint.Info.Position.z, EntityList, nil );
      // Check to see whether another ant is emerging from this spawn point
      for Idx := 0 to EntityList.Count - 1 do
        if tPhysicalEntity( EntityList[ Idx ] ).State = STATE_EMERGING then
        begin
          SpawnPointBusy := true;
          break;
        end;
    finally
      EntityList.Free;
    end;

    if not SpawnPointBusy then
      AddAnt( SpawnPoint );
  end;
end;

end.
