unit RescueeIntelligence;

interface

uses
  Geometry, GameState, Intelligence, Sense;

type
  tRescueeIntelligence = class( tArtificialIntelligence )
  private
    JustJumped : boolean;
    RescueeSense : tRescueeSense;
    RescuerIsTarget : boolean;
    StaminaAdjustment : _float;
    WakeTime : _float;
    HeartTime : _float;
    procedure   PerformJump;
    function    UpdateSoundAndAnimation : cardinal;
  protected
    procedure   BuildPath( Destination : tPoint3d ); override;
    procedure   CheckIfWoken;
    procedure   ConsiderDecision( const BestOption : tIntelligenceOption ); override;
    procedure   ConsiderEntity( var CurrentOption : tIntelligenceOption ); override;
    procedure   FocusOnPoint( Point : tPoint3d ); override;
    function    GetChannelCount : cardinal; override;
    function    GetStateDescription( State : cardinal ) : string; override;
    function    GetThinkDelay : _float; override;
    procedure   JumpToPoint( Point : tPoint3d ); override;
    procedure   LaunchHeart;
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); override;
    destructor  Destroy; override;
    procedure   ProduceDeathSound; override;
    procedure   ProducePainSound; override;
    procedure   Think; override;
  end;

  tHeartIntelligence = class( tIntelligence )
  public
    procedure Think; override;
  end;

implementation

uses
  Math, GameModel, GameSound;

const
  HEART_DELAY = 5;
  HEART_ESCAPE = 12;

(* tRescueeIntelligence *)

constructor tRescueeIntelligence.Create( GameState : tGameState; Entity : tPhysicalEntity );
begin
  inherited;
  MaximumRadiansPerTurn := PI / 8;
  RescueeSense := tRescueeSense.Create;
end;

destructor tRescueeIntelligence.Destroy;
begin
  RescueeSense.Free;
  inherited;
end;

procedure tRescueeIntelligence.BuildPath( Destination : tPoint3d );
var
  RescuerIsValid : boolean;
begin
  RescuerIsValid := RescuerIsTarget and ( GameState.Rescuer <> nil );
  Path.Allow3d := true;
  Path.AllowPartial := RescuerIsValid;
  Path.AllowSwimming := true;
  inherited;
end;

procedure tRescueeIntelligence.CheckIfWoken;
var
  Idx : integer;
begin
  for Idx := 0 to Entity.TouchingList.Count - 1 do
    if Entity.TouchingList[ Idx ] = GameState.Rescuer then
    begin
      WakeTime := GameState.Time + Entity.EntityType.Model.Animation[ ANIMATION_HUMAN_WAKE ].Length;
      break;
    end;
end;

procedure tRescueeIntelligence.ConsiderDecision( const BestOption : tIntelligenceOption );
begin
  RescuerIsTarget := BestOption.Priority = 1;
end;

procedure tRescueeIntelligence.ConsiderEntity( var CurrentOption : tIntelligenceOption );
begin
  with CurrentOption do
  begin
    case Target.EntityType.ID of
      TYPE_RESCUER:
      begin
        Priority := 1;
        Valid := true;
      end;
      TYPE_SOUND, TYPE_SMELL:
      begin
        if Target.OwnerTypeID = TYPE_RESCUER then
        begin
          Priority := 2;
          Factor := ( GameState.Time - Target.CreateTime ) / tSensoryEntity( Target ).GetCurrentMagnitude;
          Valid := true;
        end;
      end;
    end;
  end;
end;

procedure tRescueeIntelligence.FocusOnPoint( Point : tPoint3d );
const
  TIGHT_TURNING = PI / 4;
var
  Focus : tPoint3d;
  Magnitude : _float;
  Distance : _float;
  RescuerDistance : _float;
  Angle : _float;
  Turn : _float;
  Slowdown : boolean;
begin
  Focus := tPoint3d.Create( Point );
  try
    FaceTarget( Focus, Angle, Turn );

    if RescuerIsTarget and ( GameState.Rescuer <> nil ) then
    begin
      RescuerDistance := GameState.Rescuer.Location.distanceSq( Entity.Location );
      if GameState.Rescuer.Airborne then
        RescuerDistance := RescuerDistance - Sqr( Entity.Location.y - GameState.Rescuer.Location.y );   // Remove y component from distance calculation so rescuee doesn't move underneath rescuer when he jumps
    end
    else
      RescuerDistance := 100000;

    if RescuerDistance > 1 then
    begin
      Magnitude := Entity.EntityType.MaximumForce * GetEffectiveStamina;
      if Abs( Turn ) > TIGHT_TURNING then
        Magnitude := Magnitude * 0.2;

      Distance := Focus.magnitudeSq;
      if Distance <= 1 then
      begin
        Slowdown := true;
        Distance := Sqrt( Distance );
      end
      else if RescuerDistance <= 2 * 2 then
      begin
        Slowdown := true;
        Distance := Sqrt( RescuerDistance ) - 1;
      end
      else
        SlowDown := false;

      // This code largely taken from AntIntelligence - too messy to generalise
      if Slowdown then    // Slow down when approaching the centre point
      begin
        Magnitude := Magnitude * Sin( PI * Distance / 2 );    // Reduce force gradually, in the shape of a sine curve, still applying ~70% of force 50% away from destination
        Entity.Force.translate( Magnitude * Sin( Angle ), 0, Magnitude * Cos( Angle ) );
      end
      else
        Entity.Force.translate( Magnitude * Sin( Entity.Orientation ), 0, Magnitude * Cos( Entity.Orientation ) );

      StaminaAdjustment := Magnitude / Entity.EntityType.MaximumForce;
    end;
  finally
    Focus.Free;
  end;
end;

function tRescueeIntelligence.GetChannelCount : cardinal;
begin
  result := 3;
end;

function tRescueeIntelligence.GetStateDescription( State : cardinal ) : string;
begin
  result := 'Run like the devil';
end;

function tRescueeIntelligence.GetThinkDelay : _float;
begin
  result := 0.1 + 0.3 * Random;
end;

procedure tRescueeIntelligence.JumpToPoint( Point : tPoint3d );
var
  Focus : tPoint3d;
  Angle, Turn : _float;
  Magnitude : _float;
  SinA, CosA : _float;

procedure CalculateJumpForce;
var
  Clearance : _float;
  uy, uysq : _float;
  qf, t : _float;
  sx, ux : _float;
  fx, fy : _float;
  Mass : _float;
  MaximumForce : _float;
begin
  // 1. Calculate maximum height above destination on our jumping curve
  if Focus.y  >= -0.5 then
    Clearance := Focus.y + 0.4    // If jumping up, need to add clearance
  else
    Clearance := 0.25;   // Otherwise, less clearance is required

  // 2. Calculate initial Y velocity to achieve the clearance position
  uysq := 2 * GRAVITY * Clearance;
  uy := Sqrt( uysq );

  // 3. Calculate time taken to land on destination square (quadratic)
  qf := Sqrt( uysq - 2 * GRAVITY * Focus.y );
  t := Max( ( uy + qf ) / GRAVITY, ( uy - qf ) / GRAVITY );

  // 4. Calculate horizontal velocity
  sx := Sqrt( ( Focus.x * Focus.x ) + ( Focus.z * Focus.z ) );
  ux := sx / t;

  // 5. We have the velocity - now calculate the forces required (not sure why time is not part of this. Force seems to be momentum rather than force (i.e kg * m / s).
  Mass := Entity.EntityType.Mass;
  MaximumForce := Entity.EntityType.MaximumJumpForce;
  fx := Mass * ux;
  fy := Mass * uy;
  if fx > MaximumForce then
    fx := MaximumForce;
  if fy > MaximumForce then
    fy := MaximumForce;

  // 6. Set the calculated force
  Entity.Force.translate( fx * SinA, fy, fx * CosA );

  // 7. Airborne set to avoid any friction on the runway.
  Entity.Airborne := true;

  ProduceSound( 1, SOUND_JUMP, HUMAN_JUMP_SOUND_MAGNITUDE );

  JustJumped := true;
end;

const
  FACING_TARGET = PI / 32;

begin
  Focus := tPoint3d.Create( Point );
  try
    FaceTarget( Focus, Angle, Turn );
    if Abs( Turn ) < FACING_TARGET then
    begin
      if ( not Entity.Airborne or ( Entity.WasTouchingBlock and not Entity.TouchingBlock ) ) and not JustJumped then
      begin
        SinA := Sin( Angle );
        CosA := Cos( Angle );
        if Entity.Airborne then   // Allow us to move slightly in mid-air to scramble up on blocks similar to RescuerIntelligence
        begin
          Magnitude := Entity.EntityType.MaximumForce * 0.5;
          Entity.Force.setLocation( SinA * Magnitude, 0, CosA * Magnitude );
        end
        else
          CalculateJumpForce;
      end
      else
        JustJumped := false;
      tRescuee( Entity ).Jumping := true;
    end;
  finally
    Focus.Free;
  end;
end;

procedure tRescueeIntelligence.LaunchHeart;
var
  Velocity : tPoint3d;
begin
  if HeartTime < GameState.Time then
  begin
    HeartTime := GameState.Time + HEART_DELAY;
    Velocity := tPoint3d.Create( 1, 0, 0 );
    try
      Velocity.rotateY( 2 * PI * Random );
      GameState.AddHeart( Entity, Entity.Location, Velocity );
    finally
      Velocity.Free;
    end;
  end;
end;

procedure tRescueeIntelligence.PerformJump;
var
  Point : tPoint3d;
begin
  if JumpDestinationNodeIndex >= 0 then
  begin
    with Path.Node[ JumpDestinationNodeIndex ].Location do
      Point := tPoint3d.Create( x + 0.5, y, z + 0.5 );
    try
      JumpToPoint( Point );
    finally
      Point.Free;
    end;
  end;
end;

procedure tRescueeIntelligence.ProduceDeathSound;
begin
  ProduceSound( 0, SOUND_DEAD, HUMAN_DEATH_SOUND_MAGNITUDE );
  StopSound( 1 );
  StopSound( 2 );
end;

procedure tRescueeIntelligence.ProducePainSound;
begin
  ProduceSound( 0, tHumanSoundType( Ord( SOUND_PAIN1 ) + Random( 3 ) ), HUMAN_PAIN_SOUND_MAGNITUDE );
end;

procedure tRescueeIntelligence.Think;
var
  Animation : cardinal;
begin
  inherited;
  case Entity.State of
    STATE_MOBILE:
    begin
      if not Entity.Airborne then
      begin
        tRescuee( Entity ).Jumping := false;
        Entity.ExternallyLaunched := false;
        StaminaAdjustment := 0;
        if IsTimeToThink then
        begin
          KickIfStuck;
          RescueeSense.sense( Entity, GameState, SensedEntityList );
          ConsiderEntities;
        end;
        if UseTarget then
          FocusOnPoint( Target )
        else
          TraversePath;
        Animation := UpdateSoundAndAnimation;
        AdjustStamina( STAMINA_RATE - 1.7 * StaminaAdjustment * STAMINA_RATE );
      end
      else if tRescuee( Entity ).Jumping then
      begin
        PerformJump;
        Animation := ANIMATION_HUMAN_JUMP;
      end
      else
      begin
        if not Entity.ExternallyLaunched then
          Entity.DampLateralMovement;
        Animation := ANIMATION_HUMAN_FALL;
      end;
    end;
    STATE_QUIESCENT:
    begin
      if WakeTime = 0 then
      begin
        Animation := ANIMATION_HUMAN_QUIESCENT;
        CheckIfWoken;
        LaunchHeart;
      end
      else
      begin
        if WakeTime < GameState.Time then
        begin
          Entity.State := STATE_MOBILE;
          Animation := ANIMATION_HUMAN_STAND;
        end
        else
          Animation := ANIMATION_HUMAN_WAKE;
      end;
    end;
    STATE_DEAD:
      Animation := ANIMATION_HUMAN_DIE_2;
  else
    Animation := Entity.Animation;
  end;
  Entity.SetAnimation( Animation );
  ProduceSmell;
end;

function tRescueeIntelligence.UpdateSoundAndAnimation : cardinal;
const
  MINIMUM_MAGNITUDE = 4;
begin
  if Entity.Force.magnitudeSq > MINIMUM_MAGNITUDE * MINIMUM_MAGNITUDE then
  begin
    result := ANIMATION_HUMAN_RUN;
    ProduceSound( 2, SOUND_RUN, HUMAN_RUN_SOUND_MAGNITUDE, true );
  end
  else
  begin
    if ( GameState.Rescuer.Location.distanceSq( Entity.Location ) > 4 * 4 ) and Entity.IsAnimationComplete and ( ( Random( 2 ) = 0 ) ) then
      result := ANIMATION_HUMAN_WAVE
    else
      result := ANIMATION_HUMAN_WAIT;
    StopSound( 2 );
  end;
end;

(* tHeartIntelligence *)

procedure tHeartIntelligence.Think;
begin
  Entity.Airborne := true;
  Entity.Velocity.y := 1;
  if Entity.Location.y > HEART_ESCAPE then
    Entity.State := STATE_DEAD;
end;

end.
