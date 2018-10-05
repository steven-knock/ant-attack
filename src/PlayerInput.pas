unit PlayerInput;

interface

uses
  Geometry;

type
  tPlayerInput = class( tObject )
  private
    fMovementAngle : _float;
    fMovementForce : _float;
    fRotationAngle : _float;
    fJumpForce : _float;
    fGrenadeActive : boolean;
    fGrenadeTrajectory : _float;
  public
    procedure   MovePlayer( Angle, Force : _float );
    procedure   RotatePlayer( Angle : _float );
    procedure   Jump( Force : _float );
    procedure   WindUpGrenade( GrenadeTrajectory : _float );
    procedure   Reset;
    property    MovementAngle : _float read fMovementAngle;
    property    MovementForce : _float read fMovementForce;
    property    RotationAngle : _float read fRotationAngle;
    property    JumpForce : _float read fJumpForce;
    property    GrenadeActive : boolean read fGrenadeActive;
    property    GrenadeTrajectory : _float read fGrenadeTrajectory;
  end;

implementation

uses
  Math;

(* tPlayerInput *)

procedure tPlayerInput.MovePlayer( Angle, Force : _float );
var
  x, z, f : _float;
begin
  f := Max( 0, Min( 1.0, Force ) );
  if f > 0 then
  begin
    if fMovementForce > 0 then
    begin
      x := Sin( fMovementAngle ) * fMovementForce;
      z := Cos( fMovementAngle ) * fMovementForce;
      x := x + Sin( Angle ) * f;
      z := z + Cos( Angle ) * f;
      fMovementAngle := ArcTan2( x, z );
      fMovementForce := ( x * x + z * z ) / ( f + fMovementForce );
    end
    else
    begin
      fMovementAngle := Angle;
      fMovementForce := f;
    end;
  end;
end;

procedure tPlayerInput.RotatePlayer( Angle : _float );
begin
  fRotationAngle := fRotationAngle + Angle;
end;

procedure tPlayerInput.Jump( Force : _float );
begin
  fJumpForce := Max( 0, Min( 1.0, Force ) );
end;

procedure tPlayerInput.WindUpGrenade( GrenadeTrajectory : _float );
begin
  fGrenadeActive := true;
  fGrenadeTrajectory := GrenadeTrajectory;
end;

procedure tPlayerInput.Reset;
begin
  fMovementAngle := 0;
  fMovementForce := 0;
  fRotationAngle := 0;
  fJumpForce := 0;
  fGrenadeActive := false;
end;

end.
