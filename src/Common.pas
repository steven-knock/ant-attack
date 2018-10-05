Unit Common;

Interface

Uses
  Windows, Types, Classes, Dialogs, Graphics, SysUtils;

Const
  VERSION_GAME   = '1.0.7';
  VERSION_EDITOR = '1.3.7';

  FILE_ANT_ATTACK = 'antattack.exe';
  FILE_MAP_MAKER  = 'mapmaker.exe';
  FILE_CONFIGURATION = 'configuration.exe';
  FILE_USER_GUIDE = 'doc\mapmaker.htm';

Type
  tObjectList = Class(tList)
  Public
    Procedure Clear; Reintroduce;
    Procedure Delete (Index : Integer);
    Procedure Move (CurIndex, NewIndex : Integer);
    Function  Remove (Item : Pointer) : Integer;
    Destructor Destroy; Override;
  End;

  tAllocatedMemoryStream = class( tCustomMemoryStream )
  public
    constructor Create( const Buffer : Pointer; Size : Int64 );
    function    Write( const Buffer; Count : LongInt ) : LongInt; override;
  end;

  pFloatPoint2d = ^tFloatPoint2d;
  tFloatPoint2d = record
    case boolean of
      false: (
        x, y : single;
      );
      true : (
        i : array [ 0 .. 1 ] of single;
      );
  end;

  pFloatPoint3d = ^tFloatPoint3d;
  tFloatPoint3d = record
    case boolean of
      false: (
        x, y, z : single;
      );
      true : (
        i : array [ 0 .. 2 ] of single;
      );
  end;

  pIntPoint3d = ^tIntPoint3d;
  tIntPoint3d = record
    x, y, z : integer;
  end;

  pFloatArray = ^tFloatArray;
  tFloatArray = array [ 0 .. 2 ] of single;

  tSphericalCoordinate = record
    Latitude, Longitude : single;
  end;

procedure AddPointToRect( var R : tRect; const P : tPoint );
function SingleToStr( s : single ) : string;
function WrapFloat( Value, Minimum, Range : single ) : single;
procedure WriteMessageToDumpFile( const Message : string );
function MakeApplicationRelative( const Filename : string ) : string;

Implementation

uses
  Forms;

procedure WriteMessageToDumpFile( const Message : string );
var
  F : TextFile;
begin
  AssignFile( F, 'c:\aa.txt' );
  try
    Append( F );
  except
    Rewrite( F );
  end;
  try
    ShortDateFormat := 'dd/mm/yyyy';
    ShortTimeFormat := 'hh:nn:ss';
    WriteLN( F, Format( '[%s] %s: ', [ DateTimeToStr( Now ), Message ] ) );
  finally
    CloseFile( F );
  end;
end;

procedure WriteMemoryStatus( const Comment : string );
var
  HeapStatus : tHeapStatus;
begin
  HeapStatus := GetHeapStatus;
  WriteMessageToDumpFile( Format( '%d bytes - %s: ', [ HeapStatus.TotalAllocated, Comment ] ) );
end;

function MakeApplicationRelative( const Filename : string ) : string;
begin
  result := ExtractFilePath( Application.EXEName ) + Filename;
end;

(* tObjectList *)

Procedure tObjectList.Clear;
Var
  Idx : Integer;
Begin
  For Idx:=0 To Count - 1 Do
    tObject(List[Idx]).Free;
  Inherited Clear;
End;

Procedure tObjectList.Delete (Index : Integer);
Begin
  tObject(List[Index]).Free;
  Inherited Delete(Index);
End;

Procedure tObjectList.Move (CurIndex, NewIndex : Integer);
Begin
  If CurIndex <> NewIndex Then
  Begin
    tObject(List[NewIndex]).Free;
    Inherited Move(CurIndex,NewIndex);
  End;
End;

Function tObjectList.Remove (Item : Pointer) : Integer;
Begin
  Result:=IndexOf(Item);
  If Result <> -1 Then
    Delete(Result);
End;

Destructor tObjectList.Destroy;
Begin
  Clear;
  Inherited Destroy;
End;

constructor tAllocatedMemoryStream.Create( const Buffer : Pointer; Size : Int64 );
begin
  inherited Create;
  SetPointer( Buffer, Size );
end;

function tAllocatedMemoryStream.Write( const Buffer; Count : LongInt ) : LongInt;
begin
  result := 0;
end;

procedure AddPointToRect( var R : tRect; const P : tPoint );
begin
  if P.x < R.Left then
    R.Left := P.x
  else if P.x > R.Right then
    R.Right := P.x;

  if P.y < R.Top then
    R.Top := P.y
  else if P.y > R.Bottom then
    R.Bottom := P.y;
end;

function SingleToStr( s : single ) : string;
begin
  result := Format( '%.1f', [ s ] );
end;

function WrapFloat( Value, Minimum, Range : single ) : single;
begin
  while Value < Minimum do
    Value := Value + Range;
  while Value >= Minimum + Range do
    Value := Value - Range;
  result := Value;
end;

End.
