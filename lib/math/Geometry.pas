(* This unit contains and combines my geometry based Java math classes *)

(* tPlane is new ( 4/3/2002 ) - Needs to be recoded in Java *)

unit Geometry;

interface

uses
  SysUtils, Types;

type
  pFloat = ^_float;
  _float = single;  // So that numeric precision can be easily changed

  tPoint3d = class( tObject )
  public
    x, y, z : _float;
    constructor create( v : tPoint3d ); overload;
    constructor create( x, y, z : _float ); overload;
    function    crossProduct( v1, v2 : tPoint3d ) : tPoint3d;
    function    distance( v : tPoint3d ) : _float;
    function    distanceSq( v : tPoint3d ) : _float;
    function    dotProduct( v : tPoint3d ) : _float;
    function    dotProductSq( v : tPoint3d ) : _float;
    function    equals( v : tPoint3d ) : boolean;   // Implements java.lang.Object.equals
    procedure   getValues( f : pointer );   // Not in Java code
    function    magnitude : _float;
    function    magnitudeSq : _float;
    procedure   negate;
    procedure   normalise;
    procedure   reset;
    procedure   rotateX( radians : _float );
    procedure   rotateY( radians : _float );
    procedure   rotateZ( radians : _float );
    procedure   scale( v : tPoint3d ); overload;
    procedure   scale( s : _float ); overload;
    procedure   setLocation( v : tPoint3d ); overload;
    procedure   setLocation( x, y, z : _float ); overload;
    procedure   setLocation( const xyz : array of _float ); overload;
    procedure   subtract( v : tPoint3d); overload;
    procedure   subtract( x, y, z : _float ); overload;
    procedure   translate( v : tPoint3d ); overload;
    procedure   translate( x, y, z : _float ); overload;
    function    toString : string;
  end;

  tPlane = class( tPoint3d )
  public
    d : _float;
    constructor create; overload;
    constructor create( x, y, z, d : _float ); overload;
    constructor create( const ptVertex : array of tPoint3d ); overload;
    constructor create( plane : tPlane ); overload;
    procedure   assign( x, y, z, d : _float ); overload;
    procedure   assign( const ptVertex : array of tPoint3d ); overload;
    procedure   assign( plane : tPlane ); overload;
    function    dotProduct( ptVertex : tPoint3d ) : _float;
    function    getRayIntersection( ptStart, ptFinish : tPoint3d; out nIntersection : _float ) : boolean;   // Returns false if never intersects
    function    getSide( ptVertex : tPoint3d ) : integer;
    procedure   negate; reintroduce;
    procedure   subtract( v : tPoint3d); overload;
    procedure   subtract( x, y, z : _float ); overload;
    procedure   translate( v : tPoint3d ); overload;
    procedure   translate( x, y, z : _float ); overload;
  end;

  tAxis = class( tObject )
  protected
    procedure rotate( axis : integer; radians : _float );
  public
    ptAxis : Array [ 0 .. 2 ] Of tPoint3d;
    constructor create;
    procedure   assign( const axis : tAxis );
    procedure   negate;
    procedure   reset;
    procedure   rotateX( radians : _float );
    procedure   rotateY( radians : _float );
    procedure   rotateZ( radians : _float );
    destructor  destroy; override;
  end;

  tViewpoint = class( tPoint3d )
  protected
    axOrientation : tAxis;
  public
    constructor create;
    procedure   assign( const viewpoint : tViewpoint );
    procedure   reset;
    destructor  destroy; override;
    property    Orientation : tAxis read axOrientation;
  end;

  tMatrix = class( tObject )
  protected
    _matrix : array of array of _float;
    procedure wantEqual( m : tMatrix );
    procedure wantSquare;
  public
    constructor create( m : tMatrix ); overload;
    constructor create( size : integer ); overload;
    constructor create( width, height : integer ); overload;
    procedure   add( m : tMatrix );
    function    getComponent( x, y : integer ) : _float;
    function    getColumnCount : integer;
    function    getRowCount : integer;
    function    getTranslation : tPoint3d; overload;
    function    getTranslation( v : tPoint3d ) : tPoint3d; overload;
    procedure   multiply( m : tMatrix ); overload;
    function    multiply( v : tPoint3d ) : tPoint3d; overload;
    function    multiply( vIn, vOut : tPoint3d ) : tPoint3d; overload;
    class function pop : tMatrix;
    class procedure push( m : tMatrix ); overload;
    procedure   push; overload;
    procedure   setComponent( x, y : integer; value : _float );
    procedure   setMatrix( m : tMatrix );
    procedure   setToIdentity;
    procedure   setTranslation( v : tPoint3d );
    procedure   subtract( m : tMatrix );
    procedure   transpose;
    destructor  destroy; override;
  end;

  tMatrixFactory = class( tObject )
  public
    class function  createAxisMatrix( a : tAxis ) : tMatrix;
    class function  createIdentityMatrix : tMatrix; overload;
    class function  createIdentityMatrix( nSize : integer ) : tMatrix; overload;
    class function  createPoint3dMatrix( v : tPoint3d ) : tMatrix;
    class function  createRotationMatrix( vAxis : tPoint3d; angle : _float ) : tMatrix;
    class function  getDefaultSize : integer;
    class procedure setDefaultSize( nSize : integer );
  end;

  tMatrixException = class( Exception );

  tProjection = class( tObject )
  protected
    nFOV : _float;
    nDistance : _float;
    ptViewportSize : tPoint;
    ptHalfSize : tPoint;
  public
    constructor create; overload;
    constructor create( nFOV : _float; nViewportWidth, nViewportHeight : integer ); overload;
    function  getFOV : _float;
    procedure setFOV( nFOV : _float );
    function  getViewportSize : tPoint;
    procedure setViewportSize( ptViewportSize : tPoint ); overload;
    procedure setViewportSize( nViewportWidth, nViewportHeight : integer ); overload;
    function  projectPoint( v : tPoint3d ) : tPoint;
  end;

  tBoundingBox = class( tObject )
  private
    ptLeftTopFar : tPoint3d;
    ptRightBottomNear : tPoint3d;
    ptLocation : tPoint3d;
    axAxis : tAxis;
    function    GetComponent( Idx : integer ) : _float;
    procedure   SetComponent( Idx : integer; Value : _float );
  public
    constructor create; overload;
    constructor create( Width, Height, Depth, VerticalPosition : _float ); overload;
    destructor  destroy; override;
    procedure   assign( const BoundingBox : tBoundingBox );
    function    contains( v : tPoint3d ) : boolean;
    procedure   initialise( Width, Height, Depth, VerticalPosition : _float );
    procedure   getPoint( Index : integer; ptOutput : tPoint3d );
    procedure   getTransformedPoints( var ptArray : array of tPoint3d );
    property    LeftTopFar : tPoint3d read ptLeftTopFar;
    property    RightBottomNear : tPoint3d read ptRightBottomNear;
    property    Left : _float index 0 read GetComponent write SetComponent;
    property    Right : _float index 1 read GetComponent write SetComponent;
    property    Top : _float index 2 read GetComponent write SetComponent;
    property    Bottom : _float index 3 read GetComponent write SetComponent;
    property    Far : _float index 4 read GetComponent write SetComponent;
    property    Near : _float index 5 read GetComponent write SetComponent;
    property    Axis : tAxis read axAxis;
    property    Location : tPoint3d read ptLocation;
  end;

procedure crossProduct( v1, v2, result : tPoint3d );
function makePoint( x, y : integer) : tPoint;   // Not in the Java code
function normaliseBearing( Bearing : _float ) : _float;

implementation

uses
  Classes, Math;

const
  EPSILON = 0.001;  // Defined in tPlane

var
  cMatrixStack : tList;
  nDefaultSize : integer;

(* tPoint3d *)

(* Constructors *)

constructor tPoint3d.create( v : tPoint3d );
begin
  inherited create;
  setLocation( v );
end;

constructor tPoint3d.create( x, y, z : _float );
begin
  inherited create;
  setLocation( x, y, z );
end;

(* Public Methods *)

function tPoint3d.crossProduct( v1, v2 : tPoint3d ) : tPoint3d;
var
  d1, d2 : tPoint3d;
begin
  result := tPoint3d.create;
  try
    d1 := tPoint3d.create( v1.x - x, v1.y - y, v1.z - z );
    try
      d2 := tPoint3d.create( v2.x - v1.x, v2.y - v1.y, v2.z - v1.z );
      try
        result.x := ( d1.z * d2.y ) - ( d1.y * d2.z );
        result.y := ( d1.x * d2.z ) - ( d1.z * d2.x );
        result.z := ( d1.y * d2.x ) - ( d1.x * d2.y );
      finally
        d2.free;
      end;
    finally
      d1.free;
    end;
  except
    result.free;
    raise;
  end;
end;

function tPoint3d.distance( v : tPoint3d ) : _float;
begin
  result := sqrt( distanceSq( v ) );
end;

function tPoint3d.distanceSq( v : tPoint3d ) : _float;
var
  x, y, z : _float;
begin
  x := Self.x - v.x;
  y := Self.y - v.y;
  z := Self.z - v.z;
  result := ( x * x ) + ( y * y ) + ( z * z );
end;

function tPoint3d.dotProduct( v : tPoint3d ) : _float;
begin
  result := dotProductSq( v ) / distance( v );
end;

function tPoint3d.dotProductSq( v : tPoint3d ) : _float;
begin
  result := ( x * v.x ) + ( y * v.y ) + ( z * v.z );
end;

function tPoint3d.equals( v : tPoint3d ) : boolean;
begin
  result := ( x = v.x ) and ( y = v.y ) and ( z = v.z );
end;

procedure tPoint3d.getValues( f : pointer );
var
  fs : ^_float;
begin
  fs := f;
  fs^ := x;
  inc( fs );
  fs^ := y;
  inc( fs );
  fs^ := z;
end;

function tPoint3d.magnitude : _float;
begin
  result := sqrt( magnitudeSq );
end;

function tPoint3d.magnitudeSq : _float;
begin
  result := ( x * x ) + ( y * y ) + ( z * z );
end;

procedure tPoint3d.negate;
begin
  x := -x;
  y := -y;
  z := -z;
end;

procedure tPoint3d.normalise;
var
  nMagnitude : _float;
begin
  nMagnitude := magnitude;

  x := x / nMagnitude;
  y := y / nMagnitude;
  z := z / nMagnitude;
end;

procedure tPoint3d.reset;
begin
  x := 0;
  y := 0;
  z := 0;
end;

procedure tPoint3d.rotateX( radians : _float );
var
  ty, tz : _float;
begin
  ty := ( y * cos( radians ) ) - ( z * sin( radians ) );
	tz := ( z * cos( radians ) ) + ( y * sin( radians ) );

  y := ty;
  z := tz;
end;

procedure tPoint3d.rotateY( radians : _float );
var
  tx, tz : _float;
begin
  tx := ( x * cos( radians ) ) + ( z * sin( radians ) );
	tz := ( z * cos( radians ) ) - ( x * sin( radians ) );

  x := tx;
	z := tz;
end;

procedure tPoint3d.rotateZ( radians : _float );
var
  tx, ty : _float;
begin
  tx := ( x * cos( radians ) ) - ( y * sin( radians ) );
	ty := ( y * cos( radians ) ) + ( x * sin( radians ) );

	x := tx;
  y := ty;
end;

procedure tPoint3d.scale( v : tPoint3d );
begin
	x := x * v.x;
	y := y * v.y;
	z := z * v.z;
end;

procedure tPoint3d.scale( s : _float );
begin
	x := x * s;
	y := y * s;
  z := z * s;
end;

procedure tPoint3d.setLocation( v : tPoint3d );
begin
  x := v.x;
  y := v.y;
	z := v.z;
end;

procedure tPoint3d.setLocation( x, y, z : _float );
begin
	self.x := x;
	self.y := y;
	self.z := z;
end;

procedure tPoint3d.setLocation( const xyz : array of _float );
begin
  self.x := xyz[ 0 ];
  self.y := xyz[ 1 ];
  self.z := xyz[ 2 ];
end;

procedure tPoint3d.subtract( v : tPoint3d);
begin
	x := x - v.x;
  y := y - v.y;
  z := z - v.z;
end;

procedure tPoint3d.subtract( x, y, z : _float );
begin
  self.x := self.x - x;
	self.y := self.y - y;
  self.z := self.z - z;
end;

procedure tPoint3d.translate( v : tPoint3d );
begin
	x := x + v.x;
	y := y + v.y;
	z := z + v.z;
end;

procedure tPoint3d.translate( x, y, z : _float );
begin
  self.x := self.x + x;
	self.y := self.y + y;
  self.z := self.z + z;
end;

function tPoint3d.toString : string;
begin
  result := Format( '[x=%f, y=%f, z=%f]', [ x, y, z ] );
end;

(* tPlane *)

(* Constructors *)

constructor tPlane.create;
begin
  inherited;
  d := 0;
end;

constructor tPlane.create( x, y, z, d : _float );
begin
  create;
  assign( x, y, z, d );
end;

constructor tPlane.create( const ptVertex : array of tPoint3d );
begin
  create;
  assign( ptVertex );
end;

constructor tPlane.create( plane : tPlane );
begin
  create;
  assign( plane );
end;

procedure tPlane.assign( x, y, z, d : _float );
begin
  setLocation( x, y, z );
  self.d := d;
end;

procedure tPlane.assign( const ptVertex : array of tPoint3d );
var
  ptTempNormal : tPoint3d;
begin
  if length( ptVertex ) >= 3 then
  begin
    ptTempNormal := ptVertex[ 0 ].crossProduct( ptVertex[ 1 ], ptVertex[ 2 ] );
    try
      ptTempNormal.normalise;
      setLocation( ptTempNormal );
      d := -( x * ptVertex[ 0 ].x ) - ( y * ptVertex[ 0 ].y ) - ( z * ptVertex[ 0 ].z );
    finally
      ptTempNormal.free;
    end;
  end
  else
    raise eInvalidArgument.create( 'You must specify at least 3 vertices' );
end;

(* Public Methods *)

procedure tPlane.assign( plane : tPlane );
begin
  x := plane.x;
  y := plane.y;
  z := plane.z;
  d := plane.d;
end;

function tPlane.dotProduct( ptVertex : tPoint3d ) : _float;
begin
  result := ( x * ptVertex.x ) + ( y * ptVertex.y ) + ( z * ptVertex.z ) + d;
{  if abs( result ) < EPSILON then
    result := 0;}
end;

function tPlane.getRayIntersection( ptStart, ptFinish : tPoint3d; out nIntersection : _float ) : boolean;
var
  denom : _float;
begin
  denom := ( x * ( ptFinish.x - ptStart.x ) ) + ( y * ( ptFinish.y - ptStart.y ) ) + ( z * ( ptFinish.z - ptStart.z ) );
  if denom <> 0 then
  begin
    nIntersection := -dotProduct( ptStart ) / denom;
    result := true;
  end
  else
    result := false;
end;

function tPlane.getSide( ptVertex : tPoint3d ) : integer;
var
  nValue : _float;
begin
  nValue := dotProduct( ptVertex );
  if nValue < 0 then
    result := -1
  else
  if nValue > 0 then
    result := 1
  else
    result := 0;
end;

procedure tPlane.negate;
begin
  inherited;
  d := -d;
end;

procedure tPlane.subtract( v : tPoint3d);
begin
  d := d + ( v.x * x ) + ( v.y * y ) + ( v.z * z );
end;

procedure tPlane.subtract( x, y, z : _float );
begin
  d := d + ( x * self.x ) + ( y * self.y ) + ( z * self.z );
end;

procedure tPlane.translate( v : tPoint3d );
begin
  d := d - ( v.x * x ) - ( v.y * y ) - ( v.z * z );
end;

procedure tPlane.translate( x, y, z : _float );
begin
  d := d - ( x * self.x ) - ( y * self.y ) - ( z * self.z );
end;

(* tAxis *)

(* Constructor *)

constructor tAxis.create;
var
  idx : integer;
begin
  inherited create;
  for idx := low( ptAxis ) to high( ptAxis ) do
    ptAxis[ idx ] := tPoint3d.create;
  reset;
end;

(* Protected Methods *)

procedure tAxis.rotate( axis : integer; radians : _float );
Var
  mtRotation : tMatrix;
  ptTemp : tPoint3d;
  idx : integer;
begin
  mtRotation := tMatrixFactory.createRotationMatrix( ptAxis[ axis ], radians );
  try
    ptTemp := tPoint3d.create;
    try
      for idx := low( ptAxis ) to high( ptAxis ) do
        if ( idx <> axis ) then
        begin
          mtRotation.multiply( ptAxis[ idx ], ptTemp );
          ptAxis[ idx ].setLocation( ptTemp );
        end;
    finally
      ptTemp.free;
    end;
  finally
    mtRotation.free;
  end;
end;

(* Public Methods *)

procedure tAxis.assign( const axis : tAxis );
var
  i : integer;
begin
  for i := 0 to 2 do
    ptAxis[ i ].setLocation( axis.ptAxis[ i ] );
end;

procedure tAxis.negate;
var
  i : integer;
begin
  for i := 0 to 2 do
    ptAxis[ i ].negate;
end;

procedure tAxis.reset;
begin
  ptAxis[ 0 ].setLocation( 1, 0, 0 );
  ptAxis[ 1 ].setLocation( 0, 1, 0 );
  ptAxis[ 2 ].setLocation( 0, 0, 1 );
end;

procedure tAxis.rotateX( radians : _float );
begin
  rotate( 0, radians );
end;

procedure tAxis.rotateY( radians : _float );
begin
  rotate( 1, radians );
end;

procedure tAxis.rotateZ( radians : _float );
begin
  rotate( 2, radians );
end;

(* Destructor *)

destructor tAxis.destroy;
var
  idx : integer;
begin
  for idx := low( ptAxis ) to high( ptAxis ) do
    ptAxis[ idx ].free;
  inherited;
end;

(* tViewpoint *)

constructor tViewpoint.create;
begin
  inherited;
  axOrientation := tAxis.create;
end;

procedure tViewpoint.assign( const viewpoint : tViewpoint );
begin
  setLocation( viewpoint );
  axOrientation.assign( viewpoint.axOrientation );
end;

procedure tViewpoint.reset;
begin
  inherited;
  axOrientation.reset;
end;

destructor tViewpoint.destroy;
begin
  axOrientation.free;
  inherited;
end;

(* tMatrix *)

(* Constructors *)

constructor tMatrix.create( m : tMatrix );
begin
  inherited create;
  setMatrix( m );
end;

constructor tMatrix.create( size : integer );
begin
  create( size, size );
end;

constructor tMatrix.create( width, height : integer );
begin
  inherited create;
  setLength( _matrix, width, height );
end;

(* Protected Methods *)

procedure tMatrix.wantEqual( m : tMatrix );
begin
  if ( ( getColumnCount <> m.getColumnCount ) or ( getRowCount <> m.getRowCount ) ) then
		raise tMatrixException.create( 'Both Matrices must be the same size to perform this operation' );
end;

procedure tMatrix.wantSquare;
begin
	if ( getColumnCount <> getRowCount ) then
		raise tMatrixException.create( 'Matrix must be square to perform this operation' );
end;

(* Public Methods *)

procedure tMatrix.add( m : tMatrix );
var
  x, y : integer;
begin
  wantEqual( m );
  for x := 0 to getColumnCount() - 1 do
    for y := 0 to getRowCount() - 1 do
      _matrix[ x ][ y ] := _matrix[ x ][ y ] + m._matrix[ x ][ y ];
end;

function tMatrix.getComponent( x, y : integer ) : _float;
begin
  result := _matrix[ x ][ y ];
end;

function tMatrix.getColumnCount : integer;
begin
  result := length( _matrix );
end;

function tMatrix.getRowCount : integer;
begin
  result := length( _matrix[ 0 ] );
end;

function tMatrix.getTranslation : tPoint3d;
begin
  result := getTranslation( tPoint3d.create );
end;

function tMatrix.getTranslation( v : tPoint3d ) : tPoint3d;
var
  nCol, nRow : integer;
begin
  nCol := getColumnCount - 1;
  nRow := getRowCount;
  if nRow > 1 then v.x := _matrix[ nCol, 0 ];
  if nRow > 2 then v.y := _matrix[ nCol, 1 ];
  if nRow > 3 then v.z := _matrix[ nCol, 2 ];
  result := v;
end;

procedure tMatrix.multiply( m : tMatrix );
var
  x, y, my : integer;
  tot : _float;
  mNew : tMatrix;
begin
  if ( getColumnCount <> m.getRowCount ) then
    raise tMatrixException.create( 'Row and Column sizes must be the same' );

  mNew := tMatrix.create( m.getColumnCount(), getRowCount() );
  try
    for x := 0 to mNew.getColumnCount - 1 do
      for y := 0 to mNew.getRowCount - 1 do
      begin
        tot := 0;
        for my := 0 to getColumnCount - 1 do
          tot := tot + ( _matrix[ my ][ y ] * m._matrix[ x ][ my ] );
        mNew._matrix[ x ][ y ] := tot;
      end;
    setMatrix( mNew );
  finally
    mNew.free;
  end;
end;

function tMatrix.multiply( v : tPoint3d ) : tPoint3d;
begin
  result := multiply( v, tPoint3d.create );
end;

function tMatrix.multiply( vIn, vOut : tPoint3d ) : tPoint3d;
var
  mPt, mTemp : tMatrix;
begin
  mPt := tMatrixFactory.createPoint3dMatrix( vIn );
  try
    mTemp := tMatrix.create( self );
    try
      mTemp.multiply( mPt );
      vOut.x := mTemp._matrix[ 0 ][ 0 ];
      vOut.y := mTemp._matrix[ 0 ][ 1 ];
      vOut.z := mTemp._matrix[ 0 ][ 2 ];
    finally
      mTemp.free;
    end;
  finally
    mPt.free;
  end;
  result := vOut;
end;

class function tMatrix.pop : tMatrix;
var
  nCount : integer;
begin
  nCount := cMatrixStack.Count - 1;
  result := cMatrixStack.items[ nCount ];
  cMatrixStack.delete( nCount );
end;

class procedure tMatrix.push( m : tMatrix );
begin
  cMatrixStack.add( tMatrix.create( m ) );
end;

procedure tMatrix.push;
begin
  push( self );
end;

procedure tMatrix.setComponent( x, y : integer; value : _float );
begin
  _matrix[ x ][ y ] := value;
end;

procedure tMatrix.setMatrix( m : tMatrix );
var
  x, y : integer;
begin
  setLength( _matrix, m.getColumnCount, m.getRowCount );
  for x := 0 to getColumnCount() - 1 do
    for y := 0 to getRowCount() - 1 do
      _matrix[ x ][ y ] := m._matrix[ x ][ y ];
end;

procedure tMatrix.setToIdentity;
var
  x, y : integer;
  value : _float;
begin
  wantSquare();
  for x := 0 to getColumnCount() - 1 do
    for y := 0 to getRowCount() - 1 do
    begin
      if ( x = y ) then value := 1 else value := 0;
      _matrix[ x ][ y ] := value;
    end;
end;

procedure tMatrix.setTranslation( v : tPoint3d );
var
  nCol, nRow : integer;
begin
  nCol := getColumnCount - 1;
  nRow := getRowCount;
  if nRow > 1 then _matrix[ nCol, 0 ] := v.x;
  if nRow > 2 then _matrix[ nCol, 1 ] := v.y;
  if nRow > 3 then _matrix[ nCol, 2 ] := v.z;
end;

procedure tMatrix.subtract( m : tMatrix );
var
  x, y : integer;
begin
  wantEqual( m );
  for x := 0 to getColumnCount() - 1 do
    for y := 0 to getRowCount() - 1 do
      _matrix[ x ][ y ] := _matrix[ x ][ y ] - m._matrix[ x ][ y ];
end;

procedure tMatrix.transpose;
var
  x, y : integer;
  temp : _float;
begin
  wantSquare();
  for x := 1 to getColumnCount - 1 do
    for y := 0 to x - 1 do
    begin
      temp := _matrix[ x ][ y ];
      _matrix[ x ][ y ] := _matrix[ y ][ x ];
      _matrix[ y ][ x ] := temp;
    end;
end;

(* Destructor *)

destructor tMatrix.destroy;
begin
  _matrix := nil;
  inherited destroy;
end;

(* tMatrixFactory *)

(* Public Methods *)

class function tMatrixFactory.createAxisMatrix( a : tAxis ) : tMatrix;
var
  nIdx, nSize : integer;
begin
  if nDefaultSize > 3 then nSize := nDefaultSize else nSize := 3;  
  result := tMatrix.create( nSize );
  for nIdx := 0 to nSize - 1 do
    if nIdx < 3 then
    begin
      result._matrix[ nIdx, 0 ] := a.ptAxis[ nIdx ].x;
      result._matrix[ nIdx, 1 ] := a.ptAxis[ nIdx ].y;
      result._matrix[ nIdx, 2 ] := a.ptAxis[ nIdx ].z;
    end
    else
      result._matrix[ nIdx, nIdx ] := 1;
end;

class function tMatrixFactory.createIdentityMatrix : tMatrix;
begin
  result := createIdentityMatrix( nDefaultSize );
end;

class function tMatrixFactory.createIdentityMatrix( nSize : integer ) : tMatrix;
begin
  result := tMatrix.create( nSize );
  result.setToIdentity();
end;

class function tMatrixFactory.createPoint3dMatrix( v : tPoint3d ) : tMatrix;
var
  nIdx, nSize : integer;
begin
  if nDefaultSize > 3 then nSize := nDefaultSize else nSize := 3;
	result := tMatrix.create( 1, nSize );
  try
    result._matrix[ 0, 0 ] := v.x;
    result._matrix[ 0, 1 ] := v.y;
    result._matrix[ 0, 2 ] := v.z;
    for nIdx := 3 to nSize - 1 do
      result._matrix[ 0, nIdx ]:= 1;
  except
    result.free;
    raise;
  end;
end;

class function tMatrixFactory.createRotationMatrix( vAxis : tPoint3d; angle : _float ) : tMatrix;
var
  nIdx, nSize : integer;
  x, y : integer;
  vTemp : tPoint3d;
  mAxis : tMatrix;
  ca, ica : _float;
  sa : array [ 0..2 ] of _float;
  m : array [ 0..2, 0..2 ] of _float;
begin
  if nDefaultSize > 3 then nSize := nDefaultSize else nSize := 3;
  result := tMatrix.create( nSize );
  try
    vTemp := tPoint3d.create( vAxis );
    try
      vTemp.normalise;
      mAxis := createPoint3dMatrix( vTemp );
      try
        for x := 0 to 2 do
          for y := 0 to 2 do
            m[ x ][ y ] := ( mAxis._matrix[ 0 ][ x ] * mAxis._matrix[ 0 ][ y ] );

        ca := cos( angle );
        ica := 1.0 - ca;
        for x := 0 to 2 do
          sa[ x ] := mAxis._matrix[ 0 ][ x ] * sin( angle );

        result._matrix[ 0 ][ 0 ] := m[ 0 ][ 0 ] + ( ( 1.0 - m[ 0 ][ 0 ] ) * ca );
        result._matrix[ 0 ][ 1 ] := m[ 0 ][ 1 ] * ica + sa[ 2 ];
        result._matrix[ 0 ][ 2 ] := m[ 0 ][ 2 ] * ica - sa[ 1 ];

        result._matrix[ 1 ][ 0 ] := m[ 1 ][ 0 ] * ica - sa[ 2 ];
        result._matrix[ 1 ][ 1 ] := m[ 1 ][ 1 ] + ( ( 1.0 - m[ 1 ][ 1 ] ) * ca );
        result._matrix[ 1 ][ 2 ] := m[ 1 ][ 2 ] * ica + sa[ 0 ];

        result._matrix[ 2 ][ 0 ] := m[ 2 ][ 0 ] * ica + sa[ 1 ];
        result._matrix[ 2 ][ 1 ] := m[ 2 ][ 1 ] * ica - sa[ 0 ];
        result._matrix[ 2 ][ 2 ] := m[ 2 ][ 2 ] + ( ( 1.0 - m[ 2 ][ 2 ] ) * ca );

        for nIdx := 3 to nSize - 1 do
          result._matrix[ nIdx, nIdx ] := 1;
      finally
        mAxis.free;
      end;
    finally
      vTemp.free;
    end;
  except
    result.free;
    raise;
  end;
end;

class function tMatrixFactory.getDefaultSize : integer;
begin
  result := nDefaultSize;
end;

class procedure tMatrixFactory.setDefaultSize( nSize : integer );
begin
  nDefaultSize := nSize;
end;

(* tProjection *)

(* Constructors *)

constructor tProjection.create;
begin
  create( 60.0, 0, 0 );
end;

constructor tProjection.create( nFOV : _float; nViewportWidth, nViewportHeight : integer );
begin
  inherited create;
  setFOV( nFOV );
  setViewportSize( nViewportWidth, nViewportHeight );
end;

(* Public Methods *)

function tProjection.getFOV : _float;
begin
  result := nFOV;
end;

procedure tProjection.setFOV( nFOV : _float );		// Field of view, in degrees
var
  t : _float;
begin
  t := tan( nFOV * PI / 180 / 2 );
  if ( t <> 0 ) then nDistance := 1.0 / t else nDistance := 0;
  self.nFOV := nFOV;
end;

function tProjection.getViewportSize : tPoint;
begin
  result := ptViewportSize;
end;

procedure tProjection.setViewportSize( ptViewportSize : tPoint );
begin
	setViewportSize( ptViewportSize.x, ptViewportSize.y );
end;

procedure tProjection.setViewportSize( nViewportWidth, nViewportHeight : integer );
begin
	ptViewportSize.x := nViewportWidth;
  ptViewportSize.y := nViewportHeight;
  ptHalfSize.x := ptViewportSize.x Div 2;
  ptHalfSize.y := ptViewportSize.y Div 2;
end;

function tProjection.projectPoint( v : tPoint3d ) : tPoint;
var
  p : tPoint;
begin
  if ( v.z >= 0 ) then
  begin
    if ( nDistance <> 0 ) then
    begin	// Perspective Projection
      p.x := ptHalfSize.x + round( ptHalfSize.x * v.x * nDistance / ( v.z + nDistance ) );
      p.y := ptHalfSize.y + round( ptHalfSize.y * -v.y * nDistance / ( v.z + nDistance ) );
    end
    else
    begin	// Parallel Projection
      p.x := ptHalfSize.x + round( ptHalfSize.x * v.x );
      p.y := ptHalfSize.y + round( ptHalfSize.y * -v.y );
    end
  end
  else
    raise eRangeError.create( 'Cannot project points with negative Z' );
  result := p;
end;

(* tBoundingBox *)

constructor tBoundingBox.create;
begin
  inherited;
  ptLeftTopFar := tPoint3d.Create;
  ptRightBottomNear := tPoint3d.Create;
  ptLocation := tPoint3d.Create;
  axAxis := tAxis.Create;
end;

constructor tBoundingBox.create( Width, Height, Depth, VerticalPosition : _float );
begin
  Create;
  initialise( Width, Height, Depth, VerticalPosition );
end;

destructor tBoundingBox.destroy;
begin
  axAxis.Free;
  ptLocation.Free;
  ptRightBottomNear.Free;
  ptLeftTopFar.Free;
  inherited;
end;

function tBoundingBox.GetComponent( Idx : integer ) : _float;
begin
  case Idx of
    0:
      result := ptLeftTopFar.x;
    1:
      result := ptRightBottomNear.x;
    2:
      result := ptLeftTopFar.y;
    3:
      result := ptRightBottomNear.y;
    4:
      result := ptLeftTopFar.z;
    5:
      result := ptRightBottomNear.z;
  else
    result := 0;
  end;
end;

procedure tBoundingBox.SetComponent( Idx : integer; Value : _float );
begin
  case Idx of
    0:
      ptLeftTopFar.x := Value;
    1:
      ptRightBottomNear.x := Value;
    2:
      ptLeftTopFar.y := Value;
    3:
      ptRightBottomNear.y := Value;
    4:
      ptLeftTopFar.z := Value;
    5:
      ptRightBottomNear.z := Value;
  end;
end;

procedure tBoundingBox.assign( const BoundingBox : tBoundingBox );
begin
  ptLocation.setLocation( BoundingBox.Location );
  axAxis.assign( BoundingBox.Axis );
  ptLeftTopFar.setLocation( BoundingBox.LeftTopFar );
  ptRightBottomNear.setLocation( BoundingBox.RightBottomNear );
end;

function tBoundingBox.contains( v : tPoint3d ) : boolean;
var
  x, y, z : _float;
begin
  x := v.x - ptLocation.x;
  y := v.y - ptLocation.y;
  z := v.z - ptLocation.z;
  result := ( x >= ptLeftTopFar.x ) and ( x < ptRightBottomNear.x ) and ( y < ptLeftTopFar.y ) and ( y >= ptRightBottomNear.y ) and ( z >= ptLeftTopFar.z ) and ( z < ptRightBottomNear.z );
end;

procedure tBoundingBox.initialise( Width, Height, Depth, VerticalPosition : _float );
var
  w, h, d : _float;
begin
  w := Width * 0.5;
  h := Height * VerticalPosition;
  d := Depth * 0.5;
  ptLeftTopFar.x := -w;
  ptRightBottomNear.x := w;
  ptLeftTopFar.y := Height - h;
  ptRightBottomNear.y := -h;
  ptLeftTopFar.z := -d;
  ptRightBottomNear.z := d;
end;

procedure tBoundingBox.getPoint( Index : integer; ptOutput : tPoint3d );
begin
  with ptOutput do
    case Index of
      0:
        setLocation( ptLeftTopFar );
      1:
        setLocation( Left, Top, Near );
      2:
        setLocation( Right, Top, Near );
      3:
        setLocation( Right, Top, Far );
      4:
        setLocation( Left, Bottom, Far );
      5:
        setLocation( Left, Bottom, Near );
      6:
        setLocation( ptRightBottomNear );
      7:
        setLocation( Right, Bottom, Far );
    end;
end;

procedure tBoundingBox.getTransformedPoints( var ptArray : array of tPoint3d );
var
  Matrix : tMatrix;

procedure definePoint( Index : integer; x, y, z : _float );
var
  ptPoint : tPoint3d;

begin
  ptPoint := ptArray[ Index ];
  if ptPoint = nil then
    ptPoint := tPoint3d.Create( x, y, z )
  else
    ptPoint.setLocation( x, y, z );

  Matrix.multiply( ptPoint, ptPoint );
  ptPoint.translate( ptLocation );
end;

begin
  Matrix := tMatrixFactory.createAxisMatrix( axAxis );
  try
    definePoint( 0, Left, Top, Far );
    definePoint( 1, Left, Top, Near );
    definePoint( 2, Right, Top, Near );
    definePoint( 3, Right, Top, Far );
    definePoint( 4, Left, Bottom, Far );
    definePoint( 5, Left, Bottom, Near );
    definePoint( 6, Right, Bottom, Near );
    definePoint( 7, Right, Bottom, Far );
  finally
    Matrix.free;
  end;
end;

(* Module Functions *)

procedure freeMatrixStack;
begin
  while cMatrixStack.Count > 0 do
  begin
    tMatrix( cMatrixStack[ 0 ] ).free;
    cMatrixStack.delete( 0 );
  end;
end;

(* Static Procedures *)

// The CrossProduct routine in the tPoint3d class will work, but sometimes is not quite what is required.
// I can't change it now because it may be used elsewhere. This is a simpler version.
procedure crossProduct( v1, v2, result : tPoint3d );
begin
  result.x := ( v1.z * v2.y ) - ( v1.y * v2.z );
  result.y := ( v1.x * v2.z ) - ( v1.z * v2.x );
  result.z := ( v1.y * v2.x ) - ( v1.x * v2.y );
end;

function makePoint( x, y : integer) : tPoint;
begin
  result.x := x;
  result.y := y;
end;

function normaliseBearing( Bearing : _float ) : _float;
begin
  while Bearing > PI do
    Bearing := Bearing - 2 * PI;
  while Bearing < -PI do
    Bearing := Bearing + 2 * PI;
  result := Bearing;
end;

initialization
  nDefaultSize := 3;
  cMatrixStack := tList.create;
finalization
  freeMatrixStack;
  cMatrixStack.free;
end.
