unit glGeometry;

interface

uses
  OpenGL12, Geometry;

procedure glgGetAxis( const cAxis : tAxis; out nMatrix : array of glFloat; bTranspose : boolean = true );
procedure glgGetMatrix( const cMatrix : tMatrix; out nMatrix : array of glFloat );

implementation

procedure glgGetAxis( const cAxis : tAxis; out nMatrix : array of glFloat; bTranspose : boolean );
begin
  if bTranspose then      // This is usually used for applying a Camera's orientation into a ModelView matrix
  begin
    nMatrix[ 0 ] := cAxis.ptAxis[ 0 ].x;
    nMatrix[ 1 ] := cAxis.ptAxis[ 0 ].y;
    nMatrix[ 2 ] := cAxis.ptAxis[ 0 ].z;
    nMatrix[ 4 ] := cAxis.ptAxis[ 1 ].x;
    nMatrix[ 5 ] := cAxis.ptAxis[ 1 ].y;
    nMatrix[ 6 ] := cAxis.ptAxis[ 1 ].z;
    nMatrix[ 8 ] := cAxis.ptAxis[ 2 ].x;
    nMatrix[ 9 ] := cAxis.ptAxis[ 2 ].y;
    nMatrix[ 10 ] := cAxis.ptAxis[ 2 ].z;
  end
  else
  begin
    nMatrix[ 0 ] := cAxis.ptAxis[ 0 ].x;
    nMatrix[ 1 ] := cAxis.ptAxis[ 1 ].x;
    nMatrix[ 2 ] := cAxis.ptAxis[ 2 ].x;
    nMatrix[ 4 ] := cAxis.ptAxis[ 0 ].y;
    nMatrix[ 5 ] := cAxis.ptAxis[ 1 ].y;
    nMatrix[ 6 ] := cAxis.ptAxis[ 2 ].y;
    nMatrix[ 8 ] := cAxis.ptAxis[ 0 ].z;
    nMatrix[ 9 ] := cAxis.ptAxis[ 1 ].z;
    nMatrix[ 10 ] := cAxis.ptAxis[ 2 ].z;
  end;
  nMatrix[ 3 ] := 0;
  nMatrix[ 7 ] := 0;
  nMatrix[ 11 ] := 0;
  nMatrix[ 12 ] := 0;
  nMatrix[ 13 ] := 0;
  nMatrix[ 14 ] := 0;
  nMatrix[ 15 ] := 1.0;
end;

procedure glgGetMatrix( const cMatrix : tMatrix; out nMatrix : array of glFloat );
var
  nIdx, nCol, nRow : integer;
begin
  nIdx := 0;
  for nRow := 0 to cMatrix.getRowCount - 1 do
    for nCol := 0 to cMatrix.getColumnCount - 1 do
    begin
      nMatrix[ nIdx ] := cMatrix.getComponent( nCol, nRow );
      inc( nIdx );
    end;
end;

end.
