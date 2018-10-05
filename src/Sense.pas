unit Sense;

interface

uses
  Classes, GameState, Geometry, Raycaster, Intelligence;

type
  tSense = class( tObject )
  protected
    procedure senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList ); virtual; abstract;
  public
    procedure sense( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList );
  end;

  tDeafDumbBlindSense = class( tSense )
  protected
    procedure senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList ); override;
  end;

  tCreatureSense = class( tSense )
  private
    Raycaster : tRaycaster;
    EntityEye : tPoint3d;
    TargetLocation : tPoint3d;
    SoundCount : integer;
    SmellCount : integer;
    SightCount : integer;
    MaximumSightRange : _float;
    MaximumSoundFactor : _float;
    MaximumSmellFactor : _float;
  protected
    function    getMaximumSightRange : _float; virtual; abstract;  // How many units this creature can see - higher figure indicats a better range
    function    getMaximumSoundFactor : _float; virtual; abstract; // How loud must a sound be to be detected - lower figure indicates a stronger sense of hearing
    function    getMaximumSmellFactor : _float; virtual; abstract; // How strong must a smell be to be detected - lower figure indicates a stronger sense of smell
    function    senseEntity( Entity : tPhysicalEntity; Target : tEntity; GameState : tGameState ) : boolean; virtual;
    procedure   senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList ); override;
  public
    constructor Create;
    destructor  Destroy; override;
  end;

  tRescueeSense = class( tCreatureSense )
  protected
    function    senseEntity( Entity : tPhysicalEntity; Target : tEntity; GameState : tGameState ) : boolean; override;
    function    getMaximumSightRange : _float; override;
    function    getMaximumSoundFactor : _float; override;
    function    getMaximumSmellFactor : _float; override;
  end;

  tAntSense = class( tCreatureSense )
  private
    Intelligence : tIntelligence;
    function    GetAlertnessFactor : _float;
  protected
    function    getMaximumSightRange : _float; override;
    function    getMaximumSoundFactor : _float; override;
    function    getMaximumSmellFactor : _float; override;
    procedure   senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList ); override;
  public
    constructor Create( Intelligence : tIntelligence );
  end;

implementation

uses
  Log, Math, Sound, AntIntelligence;

(* tSense *)

procedure tSense.sense( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList );
begin
  SensedEntityList.Clear;
  senseEntities( Entity, GameState, SensedEntityList );
end;

(* tDeafDumbBlindSense *)

procedure tDeafDumbBlindSense.senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList );
begin
end;

(* tCreatureSense *)

constructor tCreatureSense.Create;
begin
  inherited;
  Raycaster := tRaycaster.Create;
  EntityEye := tPoint3d.Create;
  TargetLocation := tPoint3d.Create;
end;

destructor tCreatureSense.Destroy;
begin
  TargetLocation.Free;
  EntityEye.Free;
  Raycaster.Free;
  inherited;
end;

function tCreatureSense.senseEntity( Entity : tPhysicalEntity; Target : tEntity; GameState : tGameState ) : boolean;
var
  FOV : _float;
  Angle : _float;
  Magnitude : _float;
  Visibility : _float;
  PhysicalTarget : tPhysicalEntity;
  Sound : tSound;
  Smell : tSmell;
begin
  result := false;
  case Target.EntityType.ID of
    TYPE_SOUND:
    begin
      Sound := tSound( Target );
      Magnitude := Sound.GetCurrentMagnitude;
      if ( Magnitude * Magnitude ) / Entity.Location.distanceSq( Sound.Location ) >= MaximumSoundFactor then
      begin
        result := true;
        inc( SoundCount );
      end;
    end;
    TYPE_SMELL:
    begin
      Smell := tSmell( Target );
      Magnitude := Smell.GetCurrentMagnitude;
      if ( Magnitude * Magnitude ) / Entity.Location.distanceSq( Smell.Location ) >= MaximumSmellFactor then
      begin
        result := true;
        inc( SmellCount );
      end;
    end;
    else if Target.EntityType.Visible then
    begin
      PhysicalTarget := tPhysicalEntity( Target );
      if PhysicalTarget.IsActive then
      begin
        if Target.EntityType.Human then
          Visibility := tPlayerEntity( Target ).Visibility * tPlayerEntity( Target ).Visibility
        else
          Visibility := 1;
        if Entity.Location.distanceSq( Target.Location ) <= MaximumSightRange * Visibility then
        begin
          Angle := Entity.GetAngleFromFace( Target.Location, TargetLocation );
          FOV := Entity.EntityType.FOV / 2;
          if ( Angle >= -FOV ) and ( Angle <= FOV ) then
          begin
            TargetLocation.setLocation( Target.Location );
            TargetLocation.y := TargetLocation.y + Target.EntityType.EyeOffset;
            if Raycaster.traceRay( GameState.Map, EntityEye, TargetLocation ) then
            begin
              result := true;
              inc( SightCount );
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure tCreatureSense.senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList );
var
  Idx : integer;
  Target : tEntity;
begin
  MaximumSightRange := GetMaximumSightRange * GetMaximumSightRange;
  MaximumSoundFactor := GetMaximumSoundFactor * GetMaximumSoundFactor;
  MaximumSmellFactor := GetMaximumSmellFactor * GetMaximumSmellFactor;

  SoundCount := 0;
  SmellCount := 0;
  SightCount := 0;

  EntityEye.setLocation( Entity.Location );
  EntityEye.translate( 0, Entity.EntityType.EyeOffset, 0 );

  for Idx := 0 to GameState.EntityList.Count - 1 do
  begin
    Target := tEntity( GameState.EntityList[ Idx ] );
    if ( Target <> Entity ) and senseEntity( Entity, Target, GameState ) then
      SensedEntityList.Add( Target );
  end;

  if GameState.SharedStateData.IsLogEnabled then
    GameState.SharedStateData.Log( LOG_SENSE, 'Entity %d sensed %d sounds, %d smells, %d sights', [ Entity.ID, SoundCount, SmellCount, SightCount ] );
end;

(* tRescueeSense *)

function tRescueeSense.getMaximumSightRange : _float;
begin
  result := 20;
end;

function tRescueeSense.getMaximumSoundFactor : _float;
begin
  result := 1;
end;

function tRescueeSense.getMaximumSmellFactor : _float;
begin
  result := 0.1;
end;

function tRescueeSense.senseEntity( Entity : tPhysicalEntity; Target : tEntity; GameState : tGameState ) : boolean;
begin
  if ( Target.EntityType.ID = TYPE_RESCUER ) and ( tPhysicalEntity( Target ).State = STATE_ESCAPED ) then
    result := true
  else
    result := inherited senseEntity( Entity, Target, GameState );
end;

(* tAntSense *)

constructor tAntSense.Create( Intelligence : tIntelligence );
begin
  inherited Create;
  Self.Intelligence := Intelligence;
end;

function tAntSense.GetAlertnessFactor : _float;
const
  Factor : array [ tAntIntelligenceState ] of _float = ( 0.4, 0.3, 0.75, 1 );
begin
  result := Factor[ tAntIntelligence( Intelligence ).State ];
end;

function tAntSense.getMaximumSightRange : _float;
begin
  result := 60 * GetAlertnessFactor;
end;

function tAntSense.getMaximumSoundFactor : _float;
begin
  result := 0.8 / GetAlertnessFactor;
end;

function tAntSense.getMaximumSmellFactor : _float;
begin
  result := 0.1 / GetAlertnessFactor;
end;

procedure tAntSense.senseEntities( Entity : tPhysicalEntity; GameState : tGameState; SensedEntityList : tList );
begin
  if GameState.Rescuer.State <> STATE_ESCAPED then
    inherited senseEntities( Entity, GameState, SensedEntityList );
end;

end.
