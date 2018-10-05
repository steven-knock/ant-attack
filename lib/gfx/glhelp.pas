unit GLHelp;

interface

uses
  Windows;

function  glhInitialise( hWindow : hWnd; const cPFD : tPixelFormatDescriptor ) : cardinal;
procedure glhUninitialise; overload;
procedure glhUninitialise( nId : cardinal ); overload;
procedure glhSwapBuffers; overload;
procedure glhSwapBuffers( nId : cardinal ); overload;
procedure glhRaiseLastOpenGLError;

implementation

uses
  Classes, OpenGL12, SysUtils;

type
  pGLInstance = ^tGLInstance;
  tGLInstance = record
    glThread : tHandle;
    glPFD    : tPixelFormatDescriptor;
    glWnd    : hWnd;
    glDC     : hDC;
    glRC     : hGLRC;
    glLink   : boolean;
    glId     : cardinal;
  end;

  eOpenGLException = class( Exception )
  public
    constructor Create( ErrorCode : integer );
  end;


var
  cGLInstanceList : tList;
  nNextId : cardinal;

procedure initGLInstanceList;
begin
  cGLInstanceList := tList.create;
  nNextId := 1;
end;

function findGLInstanceByThread : integer;
var
  nIdx : integer;
  hCurrentThread : tHandle;
begin
  result := -1;
  hCurrentThread := getCurrentThread;
  for nIdx := 0 to cGLInstanceList.Count - 1 do
    if pGLInstance( cGLInstanceList[ nIdx ] )^.glThread = hCurrentThread then
    begin
      result := nIdx;
      break;
    end;
end;

function findGLInstanceById( nId : cardinal ) : integer;
var
  nIdx : integer;
begin
  result := -1;
  for nIdx := 0 to cGLInstanceList.Count - 1 do
    if pGLInstance( cGLInstanceList[ nIdx ] )^.glId = nId then
    begin
      result := nIdx;
      break;
    end;
end;

procedure freeGLInstance( nIdx : integer );
begin
  if nIdx >= 0 then
  begin
    freeMem( cGLInstanceList[ nIdx ] );
    cGLInstanceList.delete( nIdx );
  end;
end;

procedure freeGLInstanceList;
begin
  while cGLInstanceList.Count > 0 do
    freeGLInstance( cGLInstanceList.Count - 1 );
end;

procedure glhUninitialise( pInstance : pGLInstance ); overload;
begin
  with pInstance^ do
  begin
    if glLink then
    begin
      wglMakeCurrent( 0, 0 );
      glLink := false;
    end;
    if glDC <> 0 then
    begin
      releaseDC( glWnd, glDC );
      glDC := 0;
    end;
    if glRC <> 0 then
    begin
      wglDeleteContext( glRC );
      glRC := 0;
    end;
  end;
  freeGLInstance( cGLInstanceList.IndexOf( pInstance ) );
end;

function glhInitialise( hWindow : hWnd; const cPFD : tPixelFormatDescriptor ) : cardinal;
const
  sErrMsg : array [ 1 .. 6 ] of string =
    ('Unable To Obtain Device Context','Unable To Set Pixel Format',
     'Unable To Obtain Rendering Context','Unable To Link Thread To OpenGL',
     'Unable To Create a Suitable Rendering Device', 'Hardware acceleration is not available on the selected OpenGL Rendering Context. Please ensure that your video drivers are up-to-date.' );
var
  nPixelIndex, nErr : integer;
  GLInstance : pGLInstance;
  hOldCursor : hCursor;
  dPfd : tPixelFormatDescriptor;
begin
  result := 0;
  glInstance := allocMem( sizeOf( tGLInstance ) );
  try
    glInstance^.glId := nNextId;
    glInstance^.glThread := getCurrentThread;
    cGLInstanceList.add( glInstance );
    hOldCursor := setCursor( loadCursor( 0, makeIntResource( IDC_WAIT ) ) );
    setCapture( hWindow );
    try
      with glInstance^ do
      begin
        move( cPFD, glPFD, sizeOf( tPixelFormatDescriptor ) );
        glWnd := hWindow;
        glDC := getDC( glWnd );
        if glDC <> 0 then
        begin
          nPixelIndex := choosePixelFormat( glDC, @cPfd );
          if nPixelIndex > 0 then
          begin
            if describePixelFormat( glDC, nPixelIndex, SizeOf( dPfd ), dPfd ) then
            begin
              if ( dPfd.iPixelType = cPfd.iPixelType ) and ( dPfd.cColorBits >= cPfd.cColorBits ) and ( dPfd.cDepthBits >= cPfd.cDepthBits ) then
              begin
                if ( dPfd.dwFlags and PFD_GENERIC_FORMAT ) = 0 then
                begin
                  if setPixelFormat( glDC, nPixelIndex, @cPfd ) then
                  begin
                    glRC := wglCreateContext( glDC );
                    if glRC <> 0 then
                    begin
                      glLink := wglMakeCurrent( glDC, glRC );
                      if glLink then
                      begin
                        ReadImplementationProperties;
                        ReadExtensions;
                        nErr := 0;
                        result := glInstance^.glId;
                        inc( nNextId );
                      end
                      else
                        nErr := 4;
                    end
                    else
                      nErr := 3;
                  end
                  else
                    nErr := 2;
                end
                else
                  nErr := 6;
              end
              else
                nErr := 5;
            end
            else
              nErr := 5;
          end
          else
            nErr := 5;
        end
        else
          nErr := 1;
      end;
    finally
      releaseCapture;
      setCursor( hOldCursor );
    end;
    if nErr <> 0 then raise Exception.create( sErrMsg[ nErr ] );
  except
    glhUninitialise( glInstance );
    raise;
  end;
end;

procedure glhUninitialise; overload;
var
  nIdx : integer;
begin
  nIdx := findGLInstanceByThread;
  if nIdx >= 0 then
    glhUninitialise( pGLInstance( cGLInstanceList[ nIdx ] ) );
end;

procedure glhUninitialise( nId : cardinal ); overload;
var
  nIdx : integer;
begin
  nIdx := findGLInstanceById( nId );
  if nIdx >= 0 then
    glhUninitialise( pGLInstance( cGLInstanceList[ nIdx ] ) );
end;

procedure glhSwapBuffers;
var
  nIdx : integer;
begin
  nIdx := findGLInstanceByThread;
  if nIdx >= 0 then
    swapBuffers( pGLInstance( cGLInstanceList[ nIdx ] )^.glDC );
end;

procedure glhSwapBuffers( nId : cardinal );
var
  nIdx : integer;
begin
  nIdx := findGLInstanceById( nId );
  if nIdx >= 0 then
    swapBuffers( pGLInstance( cGLInstanceList[ nIdx ] )^.glDC );
end;

procedure glhRaiseLastOpenGLError;
var
  ErrorCode : glInt;
begin
  ErrorCode := glGetError;
  if ErrorCode <> 0 then
    Raise eOpenGLException.Create( ErrorCode );
end;

constructor eOpenGLException.Create( ErrorCode : integer );
begin
  inherited Create( 'Last OpenGL function returned: ' + IntToStr( ErrorCode ) );
end;

initialization
  initGLInstanceList;
  InitOpenGL;
finalization
  freeGLInstanceList;
  CloseOpenGL;
end.
