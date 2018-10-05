unit Cube;

interface

uses
  Geometry;

type
  tCubeSurface = ( CS_LEFT, CS_RIGHT, CS_TOP, CS_BOTTOM, CS_FAR, CS_NEAR );

  tCubeSurfaces = set of tCubeSurface;

  tSquareSurfaceCoordinates = array [ 0 .. 3,  0 .. 2 ] of _float;

const
  CUBE_SURFACES = 6;

  ptBoxNormal : array [ tCubeSurface, 0 .. 2 ] of _float = (
    ( -1, 0, 0 ),   // Left
    ( 1, 0, 0 ),    // Right
    ( 0, 1, 0 ),    // Top
    ( 0, -1, 0 ),   // Bottom
    ( 0, 0, -1 ),   // Far
    ( 0, 0, 1 )     // Near
  );

  ptBoxVertex : array [ tCubeSurface ] of tSquareSurfaceCoordinates = (
    ( ( 0, 1, 1 ), ( 0, 1, 0 ), ( 0, 0, 0 ), ( 0, 0, 1 ) ),   // Left
    ( ( 1, 1, 0 ), ( 1, 1, 1 ), ( 1, 0, 1 ), ( 1, 0, 0 ) ),   // Right
    ( ( 1, 1, 1 ), ( 1, 1, 0 ), ( 0, 1, 0 ), ( 0, 1, 1 ) ),   // Top
    ( ( 0, 0, 1 ), ( 0, 0, 0 ), ( 1, 0, 0 ), ( 1, 0, 1 ) ),   // Bottom
    ( ( 0, 1, 0 ), ( 1, 1, 0 ), ( 1, 0, 0 ), ( 0, 0, 0 ) ),   // Far
    ( ( 1, 1, 1 ), ( 0, 1, 1 ), ( 0, 0, 1 ), ( 1, 0, 1 ) )    // Near
  );

  ptSkyBoxTexture : array [ tCubeSurface, 0 .. 3, 0 .. 1 ] of _float = (
    ( ( 0, 0 ), ( 1, 0 ), ( 1, 1 ), ( 0, 1 ) ),   // Left
    ( ( 0, 0 ), ( 1, 0 ), ( 1, 1 ), ( 0, 1 ) ),   // Right
    ( ( 1, 0 ), ( 1, 1 ), ( 0, 1 ), ( 0, 0 ) ),   // Top
    ( ( 0, 0 ), ( 0, 0 ), ( 0, 0 ), ( 0, 0 ) ),   // Bottom
    ( ( 0, 0 ), ( 1, 0 ), ( 1, 1 ), ( 0, 1 ) ),   // Far
    ( ( 0, 0 ), ( 1, 0 ), ( 1, 1 ), ( 0, 1 ) )    // Near
  );

implementation

end.
