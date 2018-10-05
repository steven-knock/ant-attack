unit Intelligence;

interface

uses
  Classes, Types, Geometry, GameState, GameSound, Path;

type
  tNoisyIntelligence = class( tIntelligence )
  private
    NextSoundTime : array [ tSoundType ] of _float;
    VoiceID : array of cardinal;
  protected
    function    GetChannelCount : cardinal; virtual;
    procedure   ProduceSound( Channel : cardinal; HumanSoundType : tHumanSoundType; Magnitude : _float; Loop : Boolean = false ); overload;
    procedure   ProduceSound( Channel : cardinal; SoundType : tSoundType; Magnitude : _float; Loop : Boolean = false; Location : tPoint3d = nil ); overload;
    procedure   StopSound( Channel : cardinal );
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); override;
    destructor  Destroy; override;
    procedure   ProduceDeathSound; virtual;
    procedure   ProducePainSound; virtual;
    procedure   ResetSound; virtual;
  end;

  tSmellyNoisyIntelligence = class( tNoisyIntelligence )
  private
    fNextSmellTime : _float;
  protected
    function    GetSmellMagnitude : _float; virtual;
    function    GetSmellLifetime : _float; virtual;
    procedure   ProduceSmell;
  end;

  tIntelligenceOption = record
    Valid : boolean;
    State : cardinal;
    Priority : integer;
    Target : tEntity;
    TargetLocation : tPoint3d;
    Distance : _float;
    Factor : _float;
    SamePlane : boolean;
    ProxyTarget : boolean;
  end;

  tArtificialIntelligence = class( tSmellyNoisyIntelligence )
  private
    fJumpDestinationNodeIndex : integer;
    fMaximumRadiansPerTurn : _float;
    fNextThinkTime : _float;
    fPath : tPath;
    fPathStickyMode : boolean;
    fProxyTarget : boolean;
    fSensedEntityList : tList;
    fTarget : tPoint3d;
    fUseTarget : boolean;
    EntityWasAirborne : boolean;
    PathProgress : integer;
    LastPosition : tPoint;
    StaticPositionCount : integer;
    function    GetPath : tPath;
    procedure   SetPath( Path : tPath );
  protected
    procedure   BuildPath( Destination : tPoint3d ); virtual;
    procedure   BuildPursuitPath( Destination : tPoint3d );
    function    CalculateLandingNode( AirborneNodeIndex : integer ) : integer;
    procedure   ConsiderDecision( const BestOption : tIntelligenceOption ); virtual; abstract;
    procedure   ConsiderEntities;
    procedure   ConsiderEntity( var CurrentOption : tIntelligenceOption ); virtual; abstract;
    function    GetStateDescription( State : cardinal ) : string; virtual; abstract;
    function    GetThinkDelay : _float; virtual; abstract;
    procedure   FaceTarget( Focus : tPoint3d; out Angle, Turn : _float );
    procedure   FocusOnPoint( Point : tPoint3d ); virtual; abstract;
    function    HasPath : boolean;
    function    IsPointDifferentFromPathTarget( Point : tPoint3d ) : boolean;
    function    IsTimeToThink : boolean;
    procedure   JumpToPoint( Point : tPoint3d ); virtual; abstract;
    procedure   KickIfStuck;
    procedure   TraversePath;
    property    JumpDestinationNodeIndex : integer read fJumpDestinationNodeIndex;
    property    MaximumRadiansPerTurn : _float read fMaximumRadiansPerTurn write fMaximumRadiansPerTurn;
    property    Path : tPath read GetPath write SetPath;
    property    PathStickyMode : boolean read fPathStickyMode write fPathStickyMode;
    property    ProxyTarget : boolean read fProxyTarget;
    property    SensedEntityList : tList read fSensedEntityList;
    property    Target : tPoint3d read fTarget;
    property    UseTarget : boolean read fUseTarget;
  public
    constructor Create( GameState : tGameState; Entity : tPhysicalEntity ); override;
    destructor  Destroy; override;
    procedure   Think; override;
  end;

const
  STAMINA_RATE = 0.05;

  HUMAN_RUN_SOUND_MAGNITUDE = 10;   // Standard running sound will travel this number of units
  HUMAN_WALK_SOUND_MAGNITUDE = 2;
  HUMAN_THROW_SOUND_MAGNITUDE = 1;
  HUMAN_JUMP_SOUND_MAGNITUDE = 3;
  HUMAN_PAIN_SOUND_MAGNITUDE = 15;
  HUMAN_DEATH_SOUND_MAGNITUDE = 25;

implementation

uses
  Common, Math, Log, Cube, Sound;

(* tNoisyIntelligence *)

constructor tNoisyIntelligence.Create( GameState : tGameState; Entity : tPhysicalEntity );
begin
  inherited;
  SetLength( VoiceID, GetChannelCount );
  GameState.SharedStateData.AudioManager.DigitalAudio.CreateVoices( VoiceID );
end;

destructor tNoisyIntelligence.Destroy;
begin
  GameState.SharedStateData.AudioManager.DigitalAudio.DeleteVoices( VoiceID );
  VoiceID := nil;    // Deallocate dynamic array
  inherited;
end;

function tNoisyIntelligence.GetChannelCount : cardinal;
begin
  result := 1;
end;

procedure tNoisyIntelligence.ProduceDeathSound;
begin
end;

procedure tNoisyIntelligence.ProducePainSound;
begin
end;

procedure tNoisyIntelligence.ProduceSound( Channel : cardinal; HumanSoundType : tHumanSoundType; Magnitude : _float; Loop : Boolean );
begin
  ProduceSound( Channel, GenderSoundCrossReference[ tPlayerEntity( Entity ).Gender, HumanSoundType ], Magnitude, Loop );
end;

procedure tNoisyIntelligence.ProduceSound( Channel : cardinal; SoundType : tSoundType; Magnitude : _float; Loop : Boolean; Location : tPoint3d );
var
  Sample : tSoundSample;
  LifeTime : _float;
begin
  if GameState.Time >= NextSoundTime[ SoundType ] then
  begin
    Sample := GameState.SharedStateData.AudioManager.Sample[ Ord( SoundType ) ];
    if Sample <> nil then
      LifeTime := Sample.Length
    else
      LifeTime := 1;
    NextSoundTime[ SoundType ] := GameState.Time + LifeTime;
    if Location = nil then
      Location := Entity.Location;
    GameState.AddSound( Entity, Magnitude, LifeTime );
    GameState.SharedStateData.AudioManager.DigitalAudio.PlaySound( VoiceID[ Channel ], Ord( SoundType ), Location, Channel, Loop );
  end;
end;

procedure tNoisyIntelligence.ResetSound;
begin
  FillChar( NextSoundTime, SizeOf( NextSoundTime ), 0 );
end;

procedure tNoisyIntelligence.StopSound( Channel : cardinal );
begin
  GameState.SharedStateData.AudioManager.DigitalAudio.StopVoice( VoiceID[ Channel ] );
end;

(* tSmellyIntelligence *)

function tSmellyNoisyIntelligence.GetSmellMagnitude : _float;
begin
  result := 1;
end;

function tSmellyNoisyIntelligence.GetSmellLifetime : _float;
begin
  result := 6;
end;

procedure tSmellyNoisyIntelligence.ProduceSmell;
var
  LifeTime : _float;
begin
  if Entity.IsActive and ( GameState.Time >= fNextSmellTime ) then
  begin
    fNextSmellTime := GameState.Time + 0.5;
    LifeTime := GetSmellLifeTime;
    if LifeTime > 0 then
      GameState.AddSmell( Entity, GetSmellMagnitude, GetSmellLifeTime );
  end;
end;

(* tArtificialIntelligence *)

constructor tArtificialIntelligence.Create;
begin
  inherited;
  fMaximumRadiansPerTurn := PI;
  fTarget := tPoint3d.Create;
  fSensedEntityList := tList.Create;
end;

destructor tArtificialIntelligence.Destroy;
begin
  fSensedEntityList.Free;
  fTarget.Free;
  fPath.Free;
  inherited;
end;

procedure tArtificialIntelligence.BuildPath( Destination : tPoint3d );
begin
  Path.BuildPath( Entity.Location, Destination );
  PathProgress := 0;
  fJumpDestinationNodeIndex := -1;
  Target.setLocation( Destination );
end;

procedure tArtificialIntelligence.BuildPursuitPath( Destination : tPoint3d );
begin
  Path.MaximumIterations := 64;
  BuildPath( Destination );
end;

function tArtificialIntelligence.CalculateLandingNode( AirborneNodeIndex : integer ) : integer;
begin
  result := AirborneNodeIndex;    // Look ahead to the next node on terra firma
  repeat
    inc( result );
  until not Path.Node[ result ].Airborne;
end;

procedure tArtificialIntelligence.ConsiderEntities;
const
  MINIMUM_PATH_DISTANCE = 0.5 * 0.5;
var
  Idx : integer;
  CurrentOption, BestOption : tIntelligenceOption;
  ey, ty : integer;
  AdjustedEntityLocations : tObjectList;
begin
  BestOption.Valid := false;
  AdjustedEntityLocations := nil;
  try
    ey := Floor( Entity.Location.y );

    for Idx := 0 to SensedEntityList.Count - 1 do
    begin
      with CurrentOption do
      begin
        Valid := false;
        Target := tEntity( SensedEntityList[ Idx ] );
        TargetLocation := Target.Location;
        Distance := Entity.Location.distanceSq( TargetLocation );
        Factor := Distance;
        ProxyTarget := false;

        ConsiderEntity( CurrentOption );

        if Valid then
        begin
          Valid := not BestOption.Valid or
            ( Priority < BestOption.Priority ) or
            ( ( Priority = BestOption.Priority ) and ( ( Factor < BestOption.Factor ) ) );
          if Valid then
          begin
            ty := Floor( TargetLocation.y );
            SamePlane := ey = ty;
            if not SamePlane and ( TargetLocation = Target.Location ) then   // The Intelligence implementation has not changed the Target location, so that it still refers to the target entity and not to a point
            begin
              if Target.EntityType.Visible and tPhysicalEntity( Target ).Airborne and ( ey + 1 = ty ) then
              begin
                SamePlane := true;
                TargetLocation := tPoint3d.Create( Target.Location.x, TargetLocation.y - 1, TargetLocation.z );      // Entity.IsPointReachable will insist on the y map-coordinates being the same

                if AdjustedEntityLocations = nil then                // Keep track of adjusted TargetLocations so that they can be freed later 
                  AdjustedEntityLocations := tObjectList.Create;
                AdjustedEntityLocations.Add( TargetLocation );
              end;
            end;

            BestOption := CurrentOption;
          end;
        end;
      end;
    end;

    ConsiderDecision( BestOption );

    fUseTarget := false;
    fProxyTarget := false;
    if BestOption.Valid then
    begin
      fProxyTarget := BestOption.ProxyTarget;
      if BestOption.Distance > MINIMUM_PATH_DISTANCE then
      begin
        if BestOption.SamePlane then
        begin
          if BestOption.Target.EntityType.Visible then
            fUseTarget := Entity.IsEntityReachable( tPhysicalEntity( BestOption.Target ), BestOption.TargetLocation )
          else
            fUseTarget := Entity.IsPointReachable( BestOption.TargetLocation );
        end;
        if fUseTarget then
        begin
          if GameState.SharedStateData.IsLogEnabled then
            GameState.SharedStateData.Log( LOG_AI, 'Entity %d will %s directly towards %s at %s', [ Entity.ID, GetStateDescription( BestOption.State ), EntityTypeDescription[ BestOption.Target.EntityType.ID ], BestOption.TargetLocation.toString ] );
          Self.Target.setLocation( BestOption.TargetLocation );
        end
        else
        begin
          if ( fPath = nil ) or IsPointDifferentFromPathTarget( BestOption.TargetLocation ) then
          begin
            if GameState.SharedStateData.IsLogEnabled then
              GameState.SharedStateData.Log( LOG_AI, 'Entity %d will %s towards %s at %s', [ Entity.ID, GetStateDescription( BestOption.State ), EntityTypeDescription[ BestOption.Target.EntityType.ID ], BestOption.TargetLocation.toString ] );
            BuildPursuitPath( BestOption.TargetLocation );
          end;
        end;
      end
      else
        Path := nil;
    end;
  finally
    AdjustedEntityLocations.Free;
  end;
end;

procedure tArtificialIntelligence.FaceTarget( Focus : tPoint3d; out Angle, Turn : _float );
var
  Rotate : _float;
begin
  Focus.subtract( Entity.Location );
  if Focus.z <> 0 then
    Angle := ArcTan2( Focus.x, Focus.z )
  else if Focus.x > 0 then
    Angle := PI / 2
  else
    Angle := -PI / 2;

  Turn := normaliseBearing( Entity.Orientation - Angle );

  if Turn > MaximumRadiansPerTurn then   // We need to turn
    Rotate := MaximumRadiansPerTurn
  else if Turn < -MaximumRadiansPerTurn then
    Rotate := -MaximumRadiansPerTurn
  else
    Rotate := Turn;

  Entity.Orientation := Entity.Orientation - Rotate;
end;

function tArtificialIntelligence.GetPath : tPath;
begin
  if fPath = nil then
    fPath := tPath.Create( Entity, GameState );
  result := fPath;
end;

function tArtificialIntelligence.HasPath : boolean;
begin
  result := fPath <> nil;
end;

function tArtificialIntelligence.IsPointDifferentFromPathTarget( Point : tPoint3d ) : boolean;
begin
  result := ( Floor( Point.x ) <> Floor( Target.x ) ) or ( Floor( Point.y ) <> Floor( Target.y ) ) or ( Floor( Point.z ) <> Floor( Target.z ) ); 
end;

function tArtificialIntelligence.IsTimeToThink : boolean;
begin
  if GameState.Time >= fNextThinkTime then
  begin
    fNextThinkTime := GameState.Time + GetThinkDelay;
    result := true;
  end
  else
    result := false;
end;

procedure tArtificialIntelligence.KickIfStuck;
var
  CurrentPosition : tPoint;
begin
  with Entity.Location do
  begin
    CurrentPosition.x := Floor( x );
    CurrentPosition.y := Floor( z );
  end;
  if ( CurrentPosition.x = LastPosition.x ) and ( CurrentPosition.y = LastPosition.y ) then
  begin
    inc( StaticPositionCount );
    if StaticPositionCount = 7 then
    begin
      Path := nil;
      fUseTarget := false;
      StaticPositionCount := 0;
    end;
  end
  else
  begin
    StaticPositionCount := 0;
    LastPosition := CurrentPosition;
  end;
end;

procedure tArtificialIntelligence.SetPath( Path : tPath );
begin
  fPath.Free;
  fPath := Path;
  PathProgress := 0;
  fJumpDestinationNodeIndex := -1;
end;

procedure tArtificialIntelligence.Think;
begin
  inherited;
  if ( Entity.State = STATE_MOBILE ) and Entity.Airborne then
    EntityWasAirborne := true;
end;

procedure tArtificialIntelligence.TraversePath;
const
  WALK_THRESHOLD = 0.1 * 0.1;
  JUMP_THRESHOLD = 0.4 * 0.4;
  FACING = PI / 45;
var
  Node : tPathNode;
  NodeTarget : tPoint3d;
  NextNode : integer;
  Delta, Limit : integer;
  LookingAhead, TakeFirst : boolean;
  Angle, Turn, Threshold : _float;

procedure SetNodeTarget;
begin
  NodeTarget.setLocation( Node.Location.x + 0.5, Node.Location.y, Node.Location.z + 0.5 );
end;

begin
  if ( fPath <> nil ) and ( Path.Status <> STATE_INVALID ) then
  begin
    NodeTarget := tPoint3d.Create;
    try
      Node := Path.Node[ PathProgress ];

      if EntityWasAirborne then     // The entity has been in mid-air - if they attempted to jump or fall to a target node, we need to advance the path progress. If it failed, it will be recalculate later
      begin
        EntityWasAirborne := false;
        if Node.Airborne and ( fJumpDestinationNodeIndex > PathProgress ) then
        begin
          PathProgress := fJumpDestinationNodeIndex;
          Node := Path.Node[ PathProgress ];
        end;
      end;

      if not Node.Airborne then
      begin
        // Check whether we can still see our current node or whether we have been knocked off course
        LookingAhead := true;
        SetNodeTarget;
        if Entity.IsPointReachable( NodeTarget ) then
        begin
          Delta := 1;
          Limit := Path.NodeCount;
          TakeFirst := false;
          LookingAhead := not PathStickyMode or ( PathProgress = 0 );   // This says that we won't look ahead if we are in StickyMode (its definition) UNLESS we are still on the first node (otherwise it can get stuck returning to the centre of the start node).
        end
        else
        begin
          Delta := -1;
          Limit := -1;
          TakeFirst := true;
        end;

        // Look to see if we can take a short cut
        NextNode := PathProgress + Delta;
        while ( NextNode <> Limit ) and LookingAhead do
        begin
          Node := Path.Node[ NextNode ];
          SetNodeTarget;
          if Entity.IsPointReachable( NodeTarget ) then
          begin
            PathProgress := NextNode;
            GameState.SharedStatedata.Log( LOG_PATH, 'Entity %d is taking a short cut to node %d of %d', [ Entity.ID, NextNode + 1, Path.NodeCount ] );
            LookingAhead := not TakeFirst and not PathStickyMode;
          end
          else
            LookingAhead := TakeFirst;
          inc( NextNode, Delta );
        end;

        if TakeFirst and LookingAhead then    // We couldn't find anything - build another path
        begin
          Path := nil;
          exit;
        end;

        // Check to see whether the centre of a node has been reached
        Node := Path.Node[ PathProgress ];
        SetNodeTarget;
        NodeTarget.y := Entity.Location.y;         // Added this line to cause the rescuee to move and jump when on top of an Ant
        if ( PathProgress + 1 < Path.NodeCount ) and Path.Node[ PathProgress + 1 ].Airborne then
          Threshold := JUMP_THRESHOLD
        else
          Threshold := WALK_THRESHOLD;

        if Entity.Location.distanceSq( NodeTarget ) <= Threshold then
        begin
          // We have reached a node centre-point
          inc( PathProgress );
          if PathProgress = Path.NodeCount then
          begin
            NodeTarget.setLocation( Target );
            FaceTarget( NodeTarget, Angle, Turn );
            if Abs( Turn ) <= FACING then     // Stay on the last node until we are facing the target
            begin
              Path := nil;
              GameState.SharedStateData.Log( LOG_PATH, 'Entity %d has reached the end of its path', [ Entity.ID ] );
            end
            else
              dec( PathProgress );
          end
          else
          begin
            GameState.SharedStateData.Log( LOG_PATH, 'Entity %d has reached node %d of %d on its path', [ Entity.ID, PathProgress + 1, Path.NodeCount ] );
          end;
        end
        else
          // Otherwise, move towards the current target node (last reachable node in the path)
          FocusOnPoint( NodeTarget );
      end
      else
      begin
        fJumpDestinationNodeIndex := CalculateLandingNode( PathProgress );
        if Node.JumpDirection = CS_TOP then     // We prepare to jump
        begin
          Node := Path.Node[ fJumpDestinationNodeIndex ];
          SetNodeTarget;
          JumpToPoint( NodeTarget );
        end
        else                                    // We walk off of the edge to drop down
        begin
          SetNodeTarget;
          FocusOnPoint( NodeTarget );
        end;
      end;
    finally
      NodeTarget.Free;
    end;
  end
  else
    Path := nil;
end;

end.
