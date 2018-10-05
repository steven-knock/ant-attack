unit RescuerIntelligence;

interface

uses
  Geometry, GameState, PlayerInput, Intelligence;

type
  tRescuerIntelligence = class( tSmellyNoisyIntelligence )
  private
    fPlayerInput : tPlayerInput;
    NextFireTime : _float;
    GrenadeStartTime : _float;
    GrenadeLaunchPoint : tPoint3d;
    GrenadeVelocity : tPoint3d;
    AtmosphereLocation : tPoint3d;
    procedure   ProduceAtmosphereSound;
  protected
    function    GetChannelCount : cardinal; override;
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); override;
    destructor  Destroy; override;
    procedure   ProduceDeathSound; override;
    procedure   ProducePainSound; override;
    procedure   Think; override;
    property    PlayerInput : tPlayerInput read fPlayerInput write fPlayerInput;
  end;

  tGrenadeIntelligence = class( tNoisyIntelligence )
  private
    MadeSound : boolean;
  public
    procedure ResetSound; override;
    procedure Think; override;
  end;

  tExplosionIntelligence = class( tNoisyIntelligence )
  public
    procedure Think; override;
  end;

implementation

uses
  Classes, Math, Types, Common, GameModel, GameSound, Log, Map, Raycaster;

const
  PLAYER_FIRE_DELAY = 0.25;      // Time in seconds between grenades

  GRENADE_FORCE_BUILD_UP = 22;   // Newtons per second
  GRENADE_FORCE_MAXIMUM = 35;    // Maximum throwing force
  GRENADE_FORCE_MINUMUM = 0.5;   // Mimunum throwing force

  GRENADE_ROLL_SOUND_MAGNITUDE = 1;

  EXPLOSION_SOUND_MAGNITUDE = 50;

  EXPLOSION_FORCE = 1180;
  EXPLOSION_RANGE = 3.75;
  EXPLOSION_DAMAGE = 15;

(* tRescuerIntelligence *)

constructor tRescuerIntelligence.Create( GameState : tGameState; Entity : tPhysicalEntity );
begin
  inherited;
  AtmosphereLocation := tPoint3d.Create;
  GrenadeLaunchPoint := tPoint3d.Create;
  GrenadeVelocity := tPoint3d.Create;
  GrenadeStartTime := -1;
end;

destructor tRescuerIntelligence.Destroy;
begin
  GrenadeVelocity.Free;
  GrenadeLaunchPoint.Free;
  AtmosphereLocation.Free;
  inherited;
end;

function tRescuerIntelligence.GetChannelCount : cardinal;
begin
  result := 4;
end;

procedure tRescuerIntelligence.ProduceAtmosphereSound;
var
  Angle : _float;
begin
  Angle := GameState.Time * PI / 2;
  with AtmosphereLocation do
  begin
    x := Sin( Angle );
    z := Cos( Angle );
    y := Cos( Angle / 4 );
    translate( Entity.Location );
  end;
  ProduceSound( 3, SOUND_ATMOSPHERE, 0, true, AtmosphereLocation ); 
end;

procedure tRescuerIntelligence.ProduceDeathSound;
begin
  ProduceSound( 0, SOUND_DEAD, HUMAN_DEATH_SOUND_MAGNITUDE );
  StopSound( 1 );
  StopSound( 2 );
end;

procedure tRescuerIntelligence.ProducePainSound;
begin
  ProduceSound( 0, tHumanSoundType( Ord( SOUND_PAIN1 ) + Random( 3 ) ), HUMAN_PAIN_SOUND_MAGNITUDE );
end;

procedure tRescuerIntelligence.Think;
const
  Offset = 0.3;
var
  Rescuer : tRescuer;
  MovementForce : _float;
  Magnitude : _float;
  Orientation : _float;
  StaminaFactor : _float;
  StaminaAdjustment : _float;
  Anim : cardinal;
begin
  inherited;

  Rescuer := tRescuer( Entity );
  StaminaFactor := GetEffectiveStamina;
  if Rescuer.Airborne then
    StaminaAdjustment := 0
  else
    StaminaAdjustment := STAMINA_RATE;

  if Rescuer.State = STATE_ESCAPED then
  begin
    MovementForce := 1.0;
    GrenadeStartTime := -1;
  end
  else if Rescuer.State = STATE_MOBILE then
    MovementForce := PlayerInput.MovementForce * StaminaFactor
  else
  begin
    if Rescuer.State = STATE_DEAD then
      Rescuer.SetAnimation( ANIMATION_HUMAN_DIE_2 );
    exit;
  end;

  Anim := Rescuer.Animation;
  if MovementForce > 0 then
  begin
    if not Rescuer.Airborne then
    begin
      Anim := ANIMATION_HUMAN_RUN;
      Magnitude := 1.0;
    end
    else if Rescuer.WasTouchingBlock and not Rescuer.TouchingBlock then
      Magnitude := 0.5
    else
      Magnitude := 0.0;

    if Magnitude > 0 then
    begin
      Magnitude := MovementForce * Rescuer.EntityType.MaximumForce * IfThen( Rescuer.Airborne, 0.1, 1.0 );
      Orientation := Rescuer.Orientation + PlayerInput.MovementAngle;
      Rescuer.Force.translate( Magnitude * Sin( Orientation ), 0, Magnitude * Cos( Orientation ) );

      if MovementForce > 0.5 then
        ProduceSound( 2, SOUND_RUN, HUMAN_RUN_SOUND_MAGNITUDE, true )
      else
        ProduceSound( 2, SOUND_WALK, HUMAN_WALK_SOUND_MAGNITUDE, true );

      StaminaAdjustment := StaminaAdjustment - 1.7 * STAMINA_RATE * MovementForce;
    end;
  end
  else
    if not Rescuer.Airborne then
      Anim := ANIMATION_HUMAN_WAIT;

  if Rescuer.Airborne or ( MovementForce = 0 ) then
    StopSound( 2 );

  with Rescuer do
  begin
    if not Airborne then
    begin
      Jumping := false;
      ExternallyLaunched := false;
    end
    else if not Jumping then
    begin
      if not ExternallyLaunched and ( MovementForce = 0 ) then    // Damp horizontal movement if player wishes to drop down close to a block
        Rescuer.DampLateralMovement;
      Anim := ANIMATION_HUMAN_FALL;
    end
    else
      Anim := ANIMATION_HUMAN_JUMP;

    if ( PlayerInput.JumpForce > 0 ) and not Airborne then
    begin
      Jumping := true;
      Force.y := PlayerInput.JumpForce * EntityType.MaximumJumpForce;
      Velocity.scale( 0.4 );
      ProduceSound( 1, SOUND_JUMP, HUMAN_JUMP_SOUND_MAGNITUDE );
      StaminaAdjustment := StaminaAdjustment - STAMINA_RATE * 10;
    end;
  end;

  if not PlayerInput.GrenadeActive then
  begin
    if ( GrenadeStartTime >= 0 ) and ( Rescuer.Grenades > 0 ) then
    begin
      Magnitude := ( GameState.Time - GrenadeStartTime ) * GRENADE_FORCE_BUILD_UP;
      if ( Magnitude >= GRENADE_FORCE_MINUMUM ) and ( GameState.Time >= NextFireTime ) then
      begin
        if Magnitude > GRENADE_FORCE_MAXIMUM then
          Magnitude := GRENADE_FORCE_MAXIMUM;
        GrenadeLaunchPoint.setLocation( -Offset, Rescuer.EntityType.EyeOffset, Offset );
        GrenadeLaunchPoint.rotateY( Rescuer.Orientation );
        GrenadeLaunchPoint.translate( Rescuer.Location );

        GrenadeVelocity.setLocation( 0, 0, Magnitude );
        GrenadeVelocity.rotateX( PlayerInput.GrenadeTrajectory );
        GrenadeVelocity.rotateY( Rescuer.Orientation );

        GameState.AddGrenade( Rescuer, GrenadeLaunchPoint, GrenadeVelocity ).DetonationTime := GameState.Time + 2 + Magnitude / 20;
        ProduceSound( 1, SOUND_THROW, HUMAN_THROW_SOUND_MAGNITUDE );

        NextFireTime := GameState.Time + PLAYER_FIRE_DELAY;
      end;
      GrenadeStartTime := -1;
    end;
  end
  else if GrenadeStartTime = -1 then
    GrenadeStartTime := GameState.Time;

  AdjustStamina( StaminaAdjustment );

  Rescuer.SetAnimation( Anim );
  ProduceSmell;

  ProduceAtmosphereSound;
end;

(* tGrenadeIntelligence *)

procedure tGrenadeIntelligence.ResetSound;
begin
  inherited;
  MadeSound := false;
end;

procedure tGrenadeIntelligence.Think;
begin
  inherited;
  if Entity.Airborne then
    Entity.Orientation := Entity.ID + ( 8 * PI * ( GameState.Time - Entity.CreateTime ) )
  else if ( Entity.Velocity.magnitudeSq <> 0 ) and not MadeSound then
  begin
    ProduceSound( 0, SOUND_GRENADE, GRENADE_ROLL_SOUND_MAGNITUDE );
    MadeSound := true;
  end;
  if ( GameState.Time >= tGrenade( Entity ).DetonationTime ) or ( Entity.State = STATE_DEAD ) then
  begin
    GameState.AddExplosion( Entity );
    Entity.State := STATE_UNUSED;
  end;
end;

(* tExplosionIntelligence *)

procedure tExplosionIntelligence.Think;
var
  Idx, BIdx, YIdx : integer;
  MapPos : tIntPoint3d;
  Target : tPhysicalEntity;
  Raycaster : tRaycaster;
  Force, Scan, BBPoint : tPoint3d;
  Distance : _float;
  Magnitude : _float;
  FirstHit : boolean;
  EntityList : tList;
begin
  inherited;
  Entity.Velocity.y := 2;
  if Entity.State = STATE_MOBILE then
  begin
    EntityList := tList.Create;
    try
      if GameState.OccupancyMap.GetEntities( Entity.Location, EXPLOSION_RANGE, EntityList, Entity ) > 0 then
      begin
        BBPoint := nil;
        Scan := nil;
        Raycaster := nil;
        FirstHit := true;
        Force := tPoint3d.Create;
        try
          for Idx := 0 to EntityList.Count - 1 do
          begin
            Target := tPhysicalEntity( EntityList[ Idx ] );
            Distance := Entity.Location.distanceSq( Target.Location );
            if FirstHit then
            begin
              BBPoint := tPoint3d.Create;
              Scan := tPoint3d.Create;
              Raycaster := tRaycaster.Create;
              FirstHit := false;
            end;

            // Cast rays to each point on the bounding box to determine how much damage is done. Perform this for two positions. A ray not reaching the target does no damage.
            Scan.SetLocation( Entity.Location );
            Magnitude := 0;
            MapPos.x := Trunc( Scan.x );
            MapPos.y := Trunc( Scan.y );
            MapPos.z := Trunc( Scan.z );
            for YIdx := 0 to 1 do
            begin
              with MapPos do
                if GameState.Map.coordinatesInMap( x, y, z ) and ( GameState.Map.Block[ x, y, z ] >= BLOCK_PILLAR ) then   // Do not calculate explosion if the source is in a solid area
                  continue;
              for BIdx := 0 to 7 do
              begin
                Target.BoundingBox.getPoint( BIdx, BBPoint );
                BBPoint.translate( Target.Location );
                if Raycaster.traceRay( GameState.Map, Scan, BBPoint ) then
                  Magnitude := Magnitude + ( 1 / 16 );
              end;
              Scan.y := Scan.y + 0.8;
              MapPos.y := Trunc( Scan.y );
            end;

            Magnitude := Magnitude * ( 1 - ( Distance / Sqr( EXPLOSION_RANGE ) ) );   // Magnitude is based on a x^2 curve, so the damage falls away rapidly from the centre rather than linearly
            Force.setLocation( Target.Location );
            Force.subtract( Entity.Location );
            Force.y := Force.y + 1;
            Force.normalise;
            Force.scale( EXPLOSION_FORCE * Magnitude );
            Target.ApplyForce( Force );
            Target.TakeDamage( EXPLOSION_DAMAGE * Magnitude, Entity.EntityType.ID );

            if GameState.SharedStateData.IsLogEnabled then
              GameState.SharedStateData.Log( LOG_AI, 'Explosion %d caused %g damage to entity %d (type %s)', [ Entity.ID, EXPLOSION_DAMAGE * Magnitude, Target.ID, EntityTypeDescription[ Target.EntityType.ID ] ] );
          end;
        finally
          Force.Free;
          Raycaster.Free;
          Scan.Free;
          BBPoint.Free;
        end;
      end;
    finally
      EntityList.Free;
    end;
    ProduceSound( 0, SOUND_EXPLOSION, EXPLOSION_SOUND_MAGNITUDE );
    Entity.State := STATE_EMERGING;
  end
  else
  begin
    if GameState.Time - Entity.CreateTime > Entity.EntityType.Model.Animation[ Entity.Animation ].Length + 1 then     // Remove after animation finishes and add a second to allow sound effect to complete 
      Entity.State := STATE_UNUSED;
  end;
end;

end.
