unit Colour;

interface

type
  tColour = record
    case integer of
      0: (
        r, g, b, a : byte;
      );
      1: (
        rgba : cardinal;
      );
      2: (
        i : array [ 0 .. 3 ] of byte;
      );
  end;

const
  COLOUR_BLACK          : tColour = ( r:0; g:0; b:0; a:255 );
  COLOUR_WHITE          : tColour = ( rgba: $ffffffff );
  COLOUR_RED            : tColour = ( r:255; g:32; b:64; a:255 );
  COLOUR_RACING_GREEN   : tColour = ( r:0; g: 192; b: 0; a: 255 );
  COLOUR_ORANGE         : tColour = ( r:236; g:86; b:24; a:255 );

  COLOUR_WARNING        : tColour = ( r:255; g:64; b:64; a:255 );

  COLOUR_MAP_TITLE      : tColour = ( r:204; g: 16; b:16; a:255 );

  COLOUR_HELP_TITLE     : tColour = ( r:255; g:255; b:192; a:255 );
  COLOUR_HELP_CAPTION   : tColour = ( r:0; g:192; b:32; a:255 );
  COLOUR_HELP_KEY       : tColour = ( r:208; g:72; b:32; a:255 );
  COLOUR_HELP_ACTION    : tColour = ( r:212; g:184; b:56; a:255 );

  COLOUR_CREDIT_SJK     : tColour = ( r:255; g:255; b:64; a:255 );
  COLOUR_CREDIT_SANDY   : tColour = ( r:255; g:64; b:64; a:255 );
  COLOUR_CREDIT_ANDY    : tColour = ( r:64; g:255; b:64; a:255 );
  COLOUR_CREDIT_MODEL   : tColour = ( r:165; g:148; b:238; a:255 );
  COLOUR_CREDIT_SOUND   : tColour = ( r:95; g:128; b:224; a:255 );

  COLOUR_GAME_ELTON     : tColour = ( r:255; g: 128; b:255; a:255 );

  COLOUR_GAME_PARALYSE  : tColour = ( r:255; g:110; b:53; a:255 );

function BlendColours( const Colour1, Colour2 : cardinal ) : cardinal; overload;
function BlendColours( const Colour1, Colour2 : tColour ) : tColour; overload;
function ScaleColour( const Colour : tColour; Scale : single ) : tColour;

implementation

uses
  Math;

function BlendColours( const Colour1, Colour2 : cardinal ) : cardinal;
var
  C1, C2 : tColour;
begin
  C1.rgba := Colour1;
  C2.rgba := Colour2;
  result := BlendColours( C1, C2 ).rgba;
end;

function BlendColours( const Colour1, Colour2 : tColour ) : tColour;
begin
  result.r := ( integer( Colour1.r ) + Colour2.r ) shr 1;
  result.g := ( integer( Colour1.g ) + Colour2.g ) shr 1;
  result.b := ( integer( Colour1.b ) + Colour2.b ) shr 1;
  result.a := ( integer( Colour1.a ) + Colour2.a ) shr 1;
end;

function ScaleColour( const Colour : tColour; Scale : single ) : tColour;
var
  Idx : integer;
begin
  for Idx := 0 to 2 do
    result.i[ Idx ] := Trunc( Min( Max( Colour.i[ Idx ] * Scale, 0 ), 255 ) );
  result.a := Colour.a;
end;

end.
