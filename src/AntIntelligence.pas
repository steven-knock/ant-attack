unit AntIntelligence;

interface

uses
  Classes, Geometry, GameState, Intelligence, Sense;

type
  tAntIntelligenceState = ( ANT_STATE_EMERGE, ANT_STATE_PATROL, ANT_STATE_INVESTIGATE, ANT_STATE_PURSUE );

  tAntIntelligence = class( tArtificialIntelligence )
  private
    fState : tAntIntelligenceState;
    AntSense : tSense;
    EntityList : tList;
    EmergeTime : _float;
    ParticleLocation : tPoint3d;
    ParticleVelocity : tPoint3d;
    ParalyseTime : _float;
    BiteTime : _float;
    BiteTestTime : _float;
    procedure   BuildExplorationPath;
    function    ConsiderCollisions : boolean;
    procedure   EvadeOtherAnts;
    function    IsBiting : Boolean;
    function    IsHumanInBiteRange( Human : tEntity ) : boolean;
    procedure   PerformBite;
    procedure   ProduceBlood( Target : tPhysicalEntity; Particles : integer );
    procedure   ProduceDirt;
    procedure   UpdateSoundAndAnimation;
  protected
    procedure   ConsiderDecision( const BestOption : tIntelligenceOption ); override;
    procedure   ConsiderEntity( var CurrentOption : tIntelligenceOption ); override;
    procedure   FocusOnPoint( Point : tPoint3d ); override;
    function    GetChannelCount : cardinal; override;
    function    GetSmellMagnitude : _float; override;
    function    GetSmellLifetime : _float; override;
    function    GetStateDescription( State : cardinal ) : string; override;
    function    GetThinkDelay : _float; override;
    procedure   JumpToPoint( Point : tPoint3d ); override;
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); override;
    destructor  Destroy; override;
    procedure   ProduceDeathSound; override;
    procedure   ProducePainSound; override;
    procedure   Think; override;
    property    State : tAntIntelligenceState read fState;
  end;

implementation

uses
  GameModel, GameSound, Log, Math, Map;

const
  StateForce : array [ tAntIntelligenceState ] of _float = ( 0.175, 0.5, 0.8, 1.0 );
  StateDescription : array [ tAntIntelligenceState ] of string = ( 'Emerge', 'Patrol', 'Investigate', 'Pursue' );
  ExplorationArea = 32;

(*
  Ant Artifical Intelligence:

  --Very High Level Overview--

    Periodically, when it IsTimeToThink, the ant uses its sense to build a list of all Physical Entities that it is aware of.

    It then passes this list to ConsiderEntities which examines each sensed entity and assigns a priority to it.

    The location of the entity with the lowest (best) priority is then examined:
      if the entity can be reached directly, then it becomes the Target and the UseTarget field is set to TRUE.
      otherwise, a path is built to the entity's location and UseTarget is set to FALSE.

    If the Ant cannot sense anything worth investigating, and if their Path is nil, then they build an exploration path and follow that.

    Then, each cycle the Ant either moves towards its target or follows its path.


  --Path Traversal--

    When building a path, all of the other sensed ants are added to an avoidance list that excludes their squares from the new path.

    When following a path, the Ant constantly looks at each successive node in the path to see whether it can be reached directly.
      If so, it becomes the current node towards which the Ant will travel.

    If the current node can no longer be reached directly (perhaps because the Ant has been knocked off course), then the Ant will
      retrace through the nodes in the path until it can find one that can be reached directly, and this becomes the current node.
      Naturally, in the following cycle, the Ant will start looking ahead again to see whether it can take a short cut.


  --Direct Point Tracking--

    Even when following the path, Direct Point Tracking is used to move the ant towards the current node in the path.

    The angle between the target point and the Ant's orientation are compared, and the Ant rotated if necessary to point towards the target.
      The maximum amount that the Ant can rotate in a cycle is limited.
      If the amount of rotation exceeds a certain threshold then the force with which the ant will move is reduced.

    When the ant comes within 1 unit of the nagivation target (not an attack target), its movement force is reduced accordingly to
      enable it to arrive very slowly at the target point, which is necessary for navigating through small gaps.


  --Entity Avoidance--

    Three routines are concerned with ensuring that the ants try to avoid buming into each other, but that they aren't too passive.
      EvadeOtherAnts is used when following a path, and not pursuing a human. Normally, ants try to take short cuts through their
        path rather than "joining-the-dots" of each square. However, if an ant gets too close to another ant then it is told to enter "sticky mode"
        whereby it calculates a new path and sticks closely to it until it is more isolated.

      FocusOnTarget is the routine that moves an ant towards its current target, and it also contains code that looks ahead to see whether the ant is
        likely to bump into another ant if it kept moving forwards. If so, the ant stops, although to keep it from looking too static the ant can randomly
        jostle a little bit.

      ConsiderCollisions is called before FocusOnTarget. It checks to see whether the ant collided with another ant and, if so, it appies a force in the
        opposite direction, to try to move the ants apart. In this case, FocusOnTarget is not called since the ant has already moved.


  --Handling stuck cases--

    If the ant has spent a number of consecutive frames in the same square, then their path is cleared forcing them to calculate a new one.

*)

(* tAntIntelligence *)

const
  BITE_MIN_RANGE = 0.5 * 0.5;
  BITE_MAX_RANGE = 1.0 * 1.0;
  BITE_FIELD = PI / 4;
  BITE_FORCE = 300;
  BITE_DELAY = 0.8;

  EMERGE_SOUND_MAGNITUDE = 5;
  ATTACK_SOUND_MAGNITUDE = 12;
  BITE_SOUND_MAGNITUDE = 8;
  PAIN_SOUND_MAGNITUDE = 10;
  PARALYSE_SOUND_MAGNITUDE = 7;
  DEATH_SOUND_MAGNITUDE = 15;
  RUN_SOUND_MAGNITUDE = 8;
  WALK_SOUND_MAGNITUDE = 4;

constructor tAntIntelligence.Create( GameState : tGameState; Entity : tPhysicalEntity );
begin
  inherited;
  AntSense := tAntSense.Create( Self );
  EntityList := tList.Create;
  MaximumRadiansPerTurn := PI / 32;
  ParticleLocation := tPoint3d.Create;
  ParticleVelocity := tPoint3d.Create;
  ParalyseTime := -1;
  EmergeTime := -1;
end;

destructor tAntIntelligence.Destroy;
begin
  ParticleVelocity.Free;
  ParticleLocation.Free;
  EntityList.Free;
  AntSense.Free;
  inherited;
end;

function tAntIntelligence.GetSmellMagnitude : _float;
begin
  result := 4;
end;

function tAntIntelligence.GetSmellLifetime : _float;    // Ants don't smell
begin
  result := 0;
end;

procedure tAntIntelligence.BuildExplorationPath;

function FindExplorationPoint : tPoint3d;
begin
  result := tPoint3d.Create( GameState.Rescuer.Location );
  result.y := Entity.Location.y;
  result.x := result.x + Random * ExplorationArea - ExplorationArea div 2;
  result.z := result.z + Random * ExplorationArea - ExplorationArea div 2;
  if result.x < 0 then result.x := 0;
  if result.z < 0 then result.z := 0;
  if result.x >= GameState.Map.Width then result.x := GameState.Map.Width;
  if result.z >= GameState.Map.Height then result.z := GameState.Map.Height;
end;

var
  Point : tPoint3d;

begin
  Point := FindExplorationPoint;
  try
    Path.MaximumIterations := 24;
    BuildPath( Point );
  finally
    Point.Free;
  end;
end;

// Returns False if the Entity had to take action because of other entities, either close by or touching
function tAntIntelligence.ConsiderCollisions : boolean;
var
  Idx : integer;
  PhysicalEntity : tPhysicalEntity;
  Force : tPoint3d;
  Magnitude : _float;
begin
  result := true;
  Force := tPoint3d.Create;
  try
    for Idx := 0 to Entity.TouchingList.Count - 1 do
    begin
      PhysicalEntity := tPhysicalEntity( Entity.TouchingList[ Idx ] );
      if PhysicalEntity.EntityType.ID = TYPE_ANT then
      begin
        Force.setLocation( Entity.Location );
        Force.subtract( PhysicalEntity.Location );
        Force.y := 0;   // We don't want pushing upwards or downwards
        Magnitude := Force.magnitudeSq;
        if Magnitude <> 0 then    // This can happen if the entities are exactly on top of each other (don't ask how this can happen)
        begin
          Force.scale( Entity.EntityType.MaximumForce / Sqrt( Magnitude ) );      // Normalise and multiply in one step
          Entity.Force.translate( Force );
        end;
        result := false;
      end;
    end;
  finally
    Force.Free;
  end;
end;

procedure tAntIntelligence.ConsiderDecision( const BestOption : tIntelligenceOption );
var
  BiteLength : _float;
begin
  if BestOption.Valid then
  begin
    fState := tAntIntelligenceState( BestOption.State );

    if BestOption.Target.EntityType.Human and BestOption.SamePlane and ( GameState.Time >= BiteTime ) and ( GameState.Time >= BiteTestTime ) and IsHumanInBiteRange( BestOption.Target ) then
    begin
      BiteLength := Entity.EntityType.Model.Animation[ ANIMATION_ANT_BITE ].Length;
      BiteTime := GameState.Time + BiteLength;
      BiteTestTime := GameState.Time + BiteLength * 5 / 9;    // Bite frame is the 5th out of 9 frame transitions (10 frames)
      Entity.SetAnimation( ANIMATION_ANT_STAND );             // Reset animation in case we want to do two bites successively
      ProduceSound( 0, SOUND_ANT_ATTACK, ATTACK_SOUND_MAGNITUDE );
    end;
  end
  else
  begin
    fState := ANT_STATE_PATROL;
    if not HasPath then
    begin
      if GameState.SharedStateData.IsLogEnabled then
        GameState.SharedStateData.Log( LOG_AI, 'Ant cannot sense anything and will %s', [ StateDescription[ State ] ] );
      BuildExplorationPath;
    end;
  end;
end;

procedure tAntIntelligence.ConsiderEntity( var CurrentOption : tIntelligenceOption );
var
  AntIntelligence : tAntIntelligence;
  TargetState : tPhysicalEntityState;
begin
  with CurrentOption do
  begin
    case Target.EntityType.ID of
      TYPE_ANT:
      begin
        AntIntelligence := tAntIntelligence( tPhysicalEntity( Target ).Intelligence );
        if ( Self.State >= ANT_STATE_PATROL ) and ( AntIntelligence.State > Self.State ) and not AntIntelligence.ProxyTarget then
        begin
          State := cardinal( AntIntelligence.State );
          TargetLocation := AntIntelligence.Target;
          Distance := Entity.Location.distanceSq( TargetLocation );
          if AntIntelligence.State = ANT_STATE_PURSUE then
            Priority := 2
          else
            Priority := 5;
          Valid := true;
          ProxyTarget := true;
        end;
      end;
      TYPE_RESCUER, TYPE_RESCUEE:
      begin
        TargetState := tPhysicalEntity( Target ).State;
        if ( TargetState <> STATE_DEAD ) and ( TargetState <> STATE_QUIESCENT ) then
        begin
          State := cardinal( ANT_STATE_PURSUE );
          if ( Distance < 4 * 4 ) or ( ( Distance < 15 * 15 ) and SamePlane ) then
            Priority := 1
          else
            Priority := 2;
          if Target.EntityType.ID = TYPE_RESCUEE then   // The Ant prefers to chase the Rescuer - this allows the Rescuer to lure the Ants away from the Rescuee
            Factor := Factor * 3 * 3;
          Valid := true;
        end;
      end;
      TYPE_GRENADE:
      begin
        State := cardinal( ANT_STATE_INVESTIGATE );
        TargetLocation := tGrenade( Target ).Origin;
        Priority := 3;
        Valid := true;
      end;
      TYPE_EXPLOSION:
      begin
        State := cardinal( ANT_STATE_INVESTIGATE );
        Priority := 3;
        Valid := true;
      end;
      TYPE_SOUND, TYPE_SMELL:
      begin
        if Target.OwnerTypeID <> TYPE_ANT then
        begin
          if Target.EntityType.ID = TYPE_SOUND then
          begin
            State := cardinal( ANT_STATE_INVESTIGATE );
            if Target.EntityType.Human then
              Priority := 3
            else
              Priority := 4;
          end
          else
          begin
            State := cardinal( ANT_STATE_PURSUE );
            Priority := 2;
          end;
          Factor := ( GameState.Time - Target.CreateTime ) / tSensoryEntity( Target ).GetCurrentMagnitude;
          Valid := true;
        end;
      end;
    end;
  end;
end;

procedure tAntIntelligence.EvadeOtherAnts;
const
  AVOIDANCE_RADIUS = 1;
var
  Idx : integer;
  PhysicalEntity : tPhysicalEntity;
begin
  PathStickyMode := false;    // Optimistically hope that we can start jumping ahead in the path
  if not UseTarget and not IsBiting then
  begin
    GameState.OccupancyMap.GetEntities( Entity.Location, 2 * AVOIDANCE_RADIUS, EntityList, Entity );
    for Idx := 0 to EntityList.Count - 1 do
    begin
      PhysicalEntity := tPhysicalEntity( EntityList[ Idx ] );
      if PhysicalEntity.EntityType.ID = TYPE_ANT then
      begin
        BuildPath( Target );    // Path should automatically avoid visible obstacles
        PathStickyMode := true;
        break;
      end;
    end;
  end;
end;

procedure tAntIntelligence.FocusOnPoint( Point : tPoint3d );
const
  TIGHT_TURNING = PI / 4;
var
  Idx : integer;
  fx, fz : integer;
  Angle, Turn, Magnitude, Distance : _float;
  Focus : tPoint3d;
  PhysicalEntity : tPhysicalEntity;
  WillHit : boolean;
begin
  if ConsiderCollisions then    // If false, ConsiderCollisions will already have handled the movement
  begin
    Focus := tPoint3d.Create( Point );
    try
      FaceTarget( Focus, Angle, Turn );

      Magnitude := Entity.EntityType.MaximumForce * StateForce[ State ];
      if Abs( Turn ) > TIGHT_TURNING then
        Magnitude := Magnitude * 0.2;
      if IsBiting then
        Magnitude := Magnitude * 0.8;   // Slow down when biting

      // Look ahead to see if we are likely to bump into any other ants
      WillHit := false;
      Distance := Focus.magnitude;
      if Distance > 0.4 then    // If we are close to the centre of our target, persevere and push to it. Otherwise...
      begin
        Focus.scale( 0.7 / Distance );    // Normalise focus and multiply it
        Focus.translate( Entity.Location );
        fx := Floor( Focus.x );
        fz := Floor( Focus.z );
        if ( fx <> Floor( Entity.Location.x ) ) or ( fz <> Floor( Entity.Location.z ) ) then  // Check whether we "own" this square
        begin
          if GameState.OccupancyMap.GetEntities( fx, fz, EntityList, Entity ) > 0 then
            for Idx := 0 to EntityList.Count - 1 do
            begin
              PhysicalEntity := tPhysicalEntity( EntityList[ Idx ] );
              if PhysicalEntity.EntityType.ID = TYPE_ANT then
              begin
                with PhysicalEntity.BoundingBox do
                  if ( Focus.x >= PhysicalEntity.Location.x + Left ) and ( Focus.x <= PhysicalEntity.Location.x + Right ) and ( Focus.z >= PhysicalEntity.Location.z + Far ) and ( Focus.z <= PhysicalEntity.Location.z + Near ) then
                  begin
                    WillHit := true;
                    break;
                  end;
              end;
            end;
        end;
      end;

      if not WillHit then
      begin
        if Distance <= 1 then    // Slow down when approaching the centre point
        begin
          Magnitude := Magnitude * Sin( PI * Distance / 2 );    // Reduce force gradually, in the shape of a sine curve, still applying ~70% of force 50% away from destination
          Entity.Force.translate( Magnitude * Sin( Angle ), 0, Magnitude * Cos( Angle ) );
        end
        else
          Entity.Force.translate( Magnitude * Sin( Entity.Orientation ), 0, Magnitude * Cos( Entity.Orientation ) );
      end
      else if Random( 4 ) = 0 then
      begin
        Magnitude := Magnitude * Random * 0.2;
        Angle := Random * 2 * PI;
        Entity.Force.translate( Magnitude * Sin( Angle ), 0, Magnitude * Cos( Angle ) );
      end;
    finally
      Focus.Free;
    end;
  end;
end;

function tAntIntelligence.GetChannelCount : cardinal;
begin
  result := 3;
end;

function tAntIntelligence.GetStateDescription( State : cardinal ) : string;
begin
  result := StateDescription[ tAntIntelligenceState( State ) ];
end;

function tAntIntelligence.GetThinkDelay : _float;
const
  DELAY_BASE : array [ tAntIntelligenceState ] of _float = ( 0.0, 0.5, 0.3, 0.1 );
begin
  result := DELAY_BASE[ State ] + 0.25 * Random;
end;

function tAntIntelligence.IsBiting : Boolean;
begin
  result := GameState.Time < BiteTime;
end;

function tAntIntelligence.IsHumanInBiteRange( Human : tEntity ) : boolean;
var
  Distance : _float;
begin
  if Human <> nil then
  begin
    Distance := Entity.Location.distanceSq( Human.Location );
    result := ( Distance >= BITE_MIN_RANGE ) and ( Distance <= BITE_MAX_RANGE ) and ( Floor( Entity.Location.y + 0.5 ) = Floor( Human.Location.y + 0.5 ) ) and ( Entity.GetAngleFromFace( Human.Location ) <= BITE_FIELD );
  end
  else
    result := false;
end;

procedure tAntIntelligence.JumpToPoint( Point : tPoint3d );
begin
  // Ants can't jump
end;

procedure tAntIntelligence.PerformBite;
var
  Force : tPoint3d;

procedure TestEntity( Human : tPhysicalEntity );
begin
  if IsHumanInBiteRange( Human ) then
  begin
    Human.ApplyForce( Force );
    Human.TakeDamage( 1, Entity.EntityType.ID );
    ProduceBlood( Human, 30 );
  end;
end;

begin
  if GameState.Time >= BiteTestTime then
  begin
    Force := tPoint3d.Create;
    try
      Force.setLocation( Sin( Entity.Orientation ), 1, Cos( Entity.Orientation ) );
      Force.normalise;
      Force.scale( BITE_FORCE );
      TestEntity( GameState.Rescuer );
      TestEntity( GameState.Rescuee );
      BiteTestTime := BiteTime + BITE_DELAY;   // So we don't do this test again and to introduce a short delay between bite attempts
    finally
      Force.Free;
    end;
    ProduceSound( 1, SOUND_ANT_BITE, BITE_SOUND_MAGNITUDE );
  end
  else if UseTarget then      // Keep moving towards target when biting
    FocusOnPoint( Target );
end;

procedure tAntIntelligence.ProduceBlood( Target : tPhysicalEntity; Particles : integer );
var
  Idx : integer;
  Angle, SinA, CosA : _float;
begin
  for Idx := 1 to Particles do
  begin
    Angle := Random * 2 * PI;
    SinA := Sin( Angle );
    CosA := Cos( Angle );
    with Target.Location do
      ParticleLocation.setLocation( x + SinA * 0.1, y + Target.EntityType.EyeOffset - 0.3, z + CosA * 0.1 );
    ParticleVelocity.setLocation( SinA, 2 + Random * 7, CosA );
    GameState.AddParticle( Target, TYPE_BLOOD, ParticleLocation, ParticleVelocity, 1.5 );
  end;
end;

procedure tAntIntelligence.ProduceDeathSound;
begin
  ProduceSound( 0, SOUND_ANT_DEAD, DEATH_SOUND_MAGNITUDE );
  StopSound( 1 );
  StopSound( 2 );
end;

procedure tAntIntelligence.ProduceDirt;
const
  Particles = 5;
var
  Idx : integer;
  Angle, SinA, CosA : _float;
begin
  for Idx := 1 to Random( Particles ) do
  begin
    Angle := Random * 2 * PI;
    SinA := Sin( Angle );
    CosA := Cos( Angle );
    with Entity.Location do
      ParticleLocation.setLocation( x + SinA * 0.6, Floor( y + 1 ) - 0.2, z + CosA * 0.6 );
    ParticleVelocity.setLocation( SinA, 2 + Random * 4, CosA );
    GameState.AddParticle( Entity, TYPE_DIRT, ParticleLocation, ParticleVelocity, 2 );
  end;
end;

procedure tAntIntelligence.ProducePainSound;
begin
  ProduceSound( 0, SOUND_ANT_PAIN, PAIN_SOUND_MAGNITUDE );
end;

procedure tAntIntelligence.Think;
begin
  inherited;
  case Entity.State of
    STATE_MOBILE:
    begin
      if not Entity.Airborne then
      begin
        if not IsBiting then
        begin
          if IsTimeToThink then
          begin
            KickIfStuck;
            AntSense.sense( Entity, GameState, SensedEntityList );
            ConsiderEntities;
            EvadeOtherAnts;
          end;
          if UseTarget then
            FocusOnPoint( Target )
          else
            TraversePath;
        end
        else
          PerformBite;
      end;
      UpdateSoundAndAnimation;
    end;
    STATE_EMERGING:
    begin
      with Entity.GetMapSquare do
        if ( y >= 0 ) and ( GameState.Map.Block[ x, y, z ] = BLOCK_EMPTY ) then
        begin
          Entity.State := STATE_MOBILE;
          fState := ANT_STATE_PATROL;
        end
        else
        begin
          if EmergeTime < 0 then
          begin
            EmergeTime := GameState.Time;
            ProduceSound( 1, SOUND_ANT_EMERGE, EMERGE_SOUND_MAGNITUDE );
          end;
          Entity.Force.setLocation( 0, Entity.EntityType.MaximumForce * StateForce[ ANT_STATE_EMERGE ], 0 );
          ProduceDirt;
        end;
      Entity.SetAnimation( ANIMATION_ANT_WALK );
    end;
    STATE_PARALYSED:
    begin
      if ParalyseTime < 0 then
      begin
        ParalyseTime := GameState.Time - Entity.AnimationTime;
        ProduceSound( 1, SOUND_ANT_PARALYSIS, PARALYSE_SOUND_MAGNITUDE );
        ProducePainSound;
        StopSound( 2 );
      end;
      Entity.AnimationTime := GameState.Time - ParalyseTime;      // Keep the animation locked on the same frame
    end;
    STATE_DEAD:
      Entity.SetAnimation( ANIMATION_ANT_DIE );
  end;
  ProduceSmell;
end;

procedure tAntIntelligence.UpdateSoundAndAnimation;
var
  Force : boolean;
begin
  Force := Entity.Force.magnitudeSq > 0.01;
  if IsBiting then
    Entity.SetAnimation( ANIMATION_ANT_BITE )
  else if Force then
    Entity.SetAnimation( ANIMATION_ANT_WALK )
  else
    Entity.SetAnimation( ANIMATION_ANT_STAND );

  if not Entity.Airborne and Force then
  begin
    If State = ANT_STATE_PURSUE then
      ProduceSound( 2, SOUND_ANT_RUN, RUN_SOUND_MAGNITUDE, true )
    else
      ProduceSound( 2, SOUND_ANT_WALK, WALK_SOUND_MAGNITUDE, true );
  end
  else
    StopSound( 2 );
end;

end.
