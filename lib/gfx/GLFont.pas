//*********************************************************
//GLFONT.CPP -- glFont routines
//Copyright (c) 1998 Brad Fish
//See glFont.txt for terms of use
//November 10, 1998

//*********************************************************
//Conversion to Delphi: Daniel Klepel
//November 26, 2001
//*********************************************************

unit GLFont;

interface

uses
//OpenGL12: Borland Delphi Runtime Library - OpenGL interface unit
  Classes, OpenGL12;

//*********************************************************
//Structures
//*********************************************************

//glFont character structure
type
  PGLFontChar = ^TGLFontChar;
  TGLFontChar = record
  	dx, dy : Single;
  	tx1, ty1 : Single;
	  tx2, ty2 : Single;
  end;

//glFont structure
type
  PGLFont = ^TGLFont;
  TGLFont = record
  	tex : Integer;
  	texWidth, texHeight : Integer;
  	intStart, intEnd : Integer;
    character : PGLFontChar;
  end;

//*********************************************************
//Variables
//*********************************************************

//*********************************************************
//Function Declarations
//*********************************************************

//Creates a glFont
function glFontCreate ( fontData : tStream ) : pGLFont; overload;
function glFontCreate ( fontData : pointer ) : pGLFont; overload;

//Adds a black border to a font
procedure glFontBorder( fontData : pointer; BorderWidth : single );

//Deletes a glFont
procedure glFontDestroy ( pFont : PGLFont );

//Needs to be called before text output
procedure glFontBegin ( pFont : PGLFont );

//Needs to be called after text output
procedure glFontEnd ( );

//Draws text with a glFont
procedure glFontTextOut ( const str : String; x, y, z, xAlignment, yAlignment : Single; TextColour, BackgroundColour : cardinal; FullBorder : boolean );

//*********************************************************


implementation

uses
  SysUtils, Math;

type
  pTexel = ^tTexel;
  tTexel = record
    Luminance : byte;
    Alpha : byte;
  end;

//Current font
var pCurrentGLFont : PGLFont;

function GetTexel( Base : pointer; x, y, Width : integer ) : pTexel;
begin
  result := Base;
  inc( result, y * Width );
  inc( result, x );
end;

function glFontCreateTexture( pFont : pGLFont; pTexBytes : pointer ) : boolean; forward;

//*********************************************************
//Functions and Procedures
//*********************************************************
function glFontCreate ( fontData : tStream ) : pGLFont;
var
  pTexBytes : PChar;
  num : Integer;
  Success : boolean;
begin
  Success := false;
  GetMem( result, SizeOf( tGLFont ) );
  try
    //Read glFont structure
    fontData.Read( result^, SizeOf( tGLFont ) );

    //Get number of characters
    num := result^.intEnd - result^.intStart + 1;

    //Allocate memory for characters
    GetMem( result^.character, SizeOf( TGLFontChar ) * num );
    try
      //Read glFont characters
      fontData.Read( result^.character^, SizeOf( TGLFontChar ) * num );

      //Get texture size
      num := result^.texWidth * result^.texHeight * 2;

      //Allocate memory for texture data
      GetMem( pTexBytes, num );

      try
        //Read texture data
        fontData.Read( pTexBytes^, num );

        Success := glFontCreateTexture( result, pTexBytes );
      finally
        FreeMem( pTexBytes );
      end;
    finally
      if not Success then
        FreeMem( result^.character );
    end;
  finally
    if not Success then
    begin
      FreeMem( result );
      result := nil;
    end;
  end;
end;

function glFontCreate ( fontData : pointer ) : pGLFont;
var
  pTexBytes : pByte;
begin
  result := fontData;
  pTexBytes := fontData;

  inc( pTexBytes, SizeOf( tGLFont ) );
  result^.character := pointer( pTexBytes );   // Indicate an in-memory font
  inc( pTexBytes, SizeOf( tGLFontChar ) * ( result^.intEnd - result^.intStart + 1 ) );

  if not glFontCreateTexture( result, pTexBytes ) then
    result := nil;
end;

// This routine works through each glyph and allocates additional space around the edge which will contain the border pixels
// An exception is thrown if it runs out of space in the texture
procedure glFontBorderPreProcess( fontData : pointer; BorderWidth : single );
var
  Header : pGLFont;
  pGlyph : pGLFontChar;
  pTexBytes, pNewTexture : pByte;
  Size : cardinal;
  Extent : cardinal;
  Extent2 : cardinal;
  Glyphs : cardinal;
  GIdx : cardinal;
  x, y, tx, ty, dx, dy : cardinal;
  Width, Height, GreatestHeight : cardinal;
  twRecip, thRecip : single;
begin
  if BorderWidth <= 0 then
    exit;

  Extent := Ceil( BorderWidth ) + 1;    // Adding 1 eliminates artifacts, although I'm not sure why they should occur
  Extent2 := 2 * Extent;
  Header := fontData;
  Glyphs := Header^.intEnd - Header^.intStart + 1;

  twRecip := 1 / Header^.texWidth;
  thRecip := 1 / Header^.texHeight;

  pTexBytes := fontData;
  inc( pTexBytes, SizeOf( tGLFont ) );
  pGlyph := pointer( pTexBytes );
  inc( pTexBytes, SizeOf( tGLFontChar ) * Glyphs );

  GreatestHeight := 0;
  Size := Header^.texWidth * Header^.texHeight * 2;
  pNewTexture := AllocMem( Size );
  try
    dx := 0;
    dy := 0;
    for GIdx := 1 to Glyphs do
    begin
      tx := Round( Header^.texWidth * pGlyph^.tx1 );
      ty := Round( Header^.texHeight * pGlyph^.ty1 );
      Width := Round( Header^.texWidth * ( pGlyph^.tx2 - pGlyph^.tx1 ) );
      Height := Round( Header^.texHeight * ( pGlyph^.ty2 - pGlyph^.ty1 ) );
      if dx + Extent2 + Width > Cardinal( Header^.texWidth ) then
      begin
        dx := 0;
        inc( dy, Extent2 + GreatestHeight );
        GreatestHeight := 0;
      end;
      if dy + Extent2 + Height > Cardinal( Header^.texHeight ) then
        raise eRangeError.Create( 'Glyphs with a border no longer fit within texture boundaries' );
      if Height > GreatestHeight then
        GreatestHeight := Height;

      for y := 0 to Height - 1 do
        for x := 0 to Width - 1 do
          GetTexel( pNewTexture, dx + x + Extent, dy + y + Extent, Header^.texWidth )^ := GetTexel( pTexBytes, tx + x, ty + y, Header^.texWidth )^;

      pGlyph^.dx := pGlyph^.dx + Extent2 * twRecip;
      pGlyph^.dy := pGlyph^.dy + Extent2 * thRecip;
      pGlyph^.tx1 := dx * twRecip;
      pGlyph^.ty1 := dy * thRecip;
      pGlyph^.tx2 := ( dx + Extent2 + Width ) * twRecip;
      pGlyph^.ty2 := ( dy + Extent + Height ) * thRecip;

      inc( dx, Extent2 + Width );
      inc( pGlyph );
    end;
    Move( pNewTexture^, pTexBytes^, Size );
  finally
    FreeMem( pNewTexture );
  end;
end;

procedure glFontBorder( fontData : pointer; BorderWidth : single );
var
  Header : pGLFont;
  pTexBytes, pNewTexture : pByte;
  Size : cardinal;
  Extent : cardinal;
  DistanceSq, ExtentSq : cardinal;
  ix, iy, cx, cy, fx, fy : integer;
  TotalAlpha, CurrentAlpha : cardinal;
  Distance : single;
begin
  if BorderWidth <= 0 then
    exit;

  glFontBorderPreProcess( fontData, BorderWidth );

  Extent := Ceil( BorderWidth );
  ExtentSq := Extent * Extent;
  Header := fontData;
  pTexBytes := fontData;

  inc( pTexBytes, SizeOf( tGLFont ) );
  inc( pTexBytes, SizeOf( tGLFontChar ) * ( Header^.intEnd - Header^.intStart + 1 ) );


  Size := Header^.texWidth * Header^.texHeight * 2;
  GetMem( pNewTexture, Size );
  try
    Move( pTexBytes^, pNewTexture^, Size );
    for iy := 0 to Header^.texHeight - 1 do
    begin
      for ix := 0 to Header^.texWidth - 1 do
      begin
        if GetTexel( pTexBytes, ix, iy, Header^.texWidth ).Alpha = 0 then
        begin
          TotalAlpha := 0;
          for cy := -Extent to Extent do
          begin
            fy := iy + cy;
            if ( fy >= 0 ) and ( fy < Header^.texHeight ) then
            begin
              for cx := -Extent to Extent do
              begin
                fx := ix + cx;
                if ( fx >= 0 ) and ( fx < Header^.texWidth ) then
                begin
                  CurrentAlpha := GetTexel( pTexBytes, fx, fy, Header^.texWidth ).Alpha;
                  if CurrentAlpha <> 0 then
                  begin
                    DistanceSq := ( cx * cx ) + ( cy * cy );
                    if DistanceSq > ExtentSq then
                    begin
                      Distance := Sqrt( DistanceSq ) - Extent;
                      if Distance < 1 then
                        CurrentAlpha := Round( CurrentAlpha * ( 1 - Distance ) )
                      else
                        CurrentAlpha := 0;
                    end;
                    inc( TotalAlpha, CurrentAlpha );
                  end;
                end;
              end;
            end;
          end;
          if TotalAlpha > 255 then
            TotalAlpha := 255;
          with GetTexel( pNewTexture, ix, iy, Header^.texWidth )^ do
          begin
            Luminance := 0;
            Alpha := TotalAlpha;
          end;
        end;
      end;
    end;
    Move( pNewTexture^, pTexBytes^, Size );
  finally
    FreeMem( pNewTexture );
  end;
end;

function glFontCreateTexture( pFont : pGLFont; pTexBytes : pointer ) : boolean;
begin
  // Clear Error
  glGetError;

  //Set texture attributes
  glGenTextures( 1, @pFont^.tex );
  glBindTexture( GL_TEXTURE_2D, pFont^.tex );
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP );
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP );
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexEnvf( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE );

  //Create texture
  glTexImage2D( GL_TEXTURE_2D, 0, 2, pFont^.texWidth, pFont^.texHeight, 0, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, pTexBytes );

  result := glGetError = GL_NO_ERROR;
end;

//*********************************************************
procedure glFontDestroy ( pFont : PGLFont );
var
  pCharData : pGLFont;
begin
	//Free character memory
  if pFont <> nil then
  begin
    glDeleteTextures( 1, @pFont^.tex );
    pCharData := pFont;
    inc( pCharData );
    if pointer( pCharData ) <> pointer( pFont^.character ) then    // If it is a contiguous font do not free the memory - it was managed elsewhere
    begin
      FreeMem( pFont^.character );
      FreeMem( pFont );
    end;
  end;
end;
//*********************************************************
procedure glFontBegin ( pFont : PGLFont );
begin

	//Save pointer to font structure
  pCurrentGLFont := pFont;

	//Bind to font texture
	glBindTexture( GL_TEXTURE_2D, pFont^.tex );

end;
//*********************************************************
procedure glFontEnd ( );
begin

	//Font no longer current
  pCurrentGLFont := nil;

end;

function GetTextWidth( const Str : string ) : single; overload;
var
  Idx : integer;
  pCharacter : PGLFontChar;
begin
  result := 0;
  for Idx := 1 to Length( Str ) do
  begin
    pCharacter := pCurrentGLFont^.character;
    Inc( pCharacter,  Integer( Str[ Idx ] ) - pCurrentGLFont^.intStart );
    result := result + pCharacter^.dx;
  end;
end;

function GetTextHeight : single;
var
  pCharacter : PGLFontChar;
begin
  pCharacter := pCurrentGLFont^.character;
  Inc( pCharacter,  Integer( 'M' ) - pCurrentGLFont^.intStart );
  result := pCharacter^.dy;
end;

//*********************************************************
procedure glFontTextOut ( const str : String; x, y, z, xAlignment, yAlignment : Single; TextColour, BackgroundColour : cardinal; FullBorder : boolean );
var
  len, i : Integer;
  width, height, borderx, bordery : single;
  pCharacter : PGLFontChar;
begin

	//Return if we don't have a valid glFont
  if nil = pCurrentGLFont then
    Exit;

	//Get length of string
  len := Length( str );

  width := GetTextWidth( str );
  height := GetTextHeight;

  // Position text horizontally
  if xAlignment > 0 then
    x := x - ( width * xAlignment );

  // Position text vertically
  if yAlignment > 0 then
    y := y - ( height * yAlignment );

  glPushAttrib( GL_ENABLE_BIT );
  glDisable( GL_LIGHTING );
  glDisable( GL_FOG );

  if ( BackgroundColour and $ff000000 ) <> 0 then
  begin
    borderx := GetTextWidth( 'M' ) * 0.5;
    bordery := borderx * 0.5;
    if FullBorder then
      borderx := 65536;

    glDisable( GL_TEXTURE_2D );
    glColor4ubv( @BackgroundColour );

	  glBegin( GL_QUADS );
      glVertex3f( x - borderx, y - bordery, z );
      glVertex3f( x + borderx + width, y - bordery, z );
      glVertex3f( x + borderx + width, y + height + bordery, z );
      glVertex3f( x - borderx, y + height + bordery, z );
    glEnd;

  end;

  glEnable( GL_TEXTURE_2D );
  glColor4ubv( @TextColour );

	//Begin rendering quads
	glBegin( GL_QUADS );
	//Loop through characters
  for i := 0 to len - 1 do begin

    pCharacter := pCurrentGLFont^.character;
    Inc( pCharacter,  Integer(str[i + 1]) - pCurrentGLFont^.intStart );

		//Specify vertices and texture coordinates
		glTexCoord2f( pCharacter^.tx1, pCharacter^.ty2 );
		glVertex3f(x, y + pCharacter^.dy, z);
		glTexCoord2f( pCharacter^.tx1, pCharacter^.ty1 );
		glVertex3f(x, y, z);
		glTexCoord2f(pCharacter^.tx2, pCharacter^.ty1);
		glVertex3f(x + pCharacter^.dx, y, z);
		glTexCoord2f(pCharacter^.tx2, pCharacter^.ty2);
		glVertex3f(x + pCharacter^.dx, y + pCharacter^.dy, z);

		//Move to next character
		x := x + pCharacter^.dx;
  end;

	//Stop rendering quads
	glEnd();

  glPopAttrib;
end;

//*********************************************************

end.
