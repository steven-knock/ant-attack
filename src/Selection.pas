unit Selection;

interface

uses
  Controls, Common, Graphics, Types, Map;

type
  tMapSelectionState = class( tObject )
  public
    Dragging : boolean;
    DragTest : boolean;
    Buttons : set of tMouseButton;
    Area : tRect;
    AreaValid : boolean;
    StartValid : boolean;
    InDoubleClick : boolean;
  end;

  tSelectionCommand = class;
  tSelectionInfo = class;

  tSelectionCommandContext = class( tObject )
  private
    fUndoStack : tObjectList;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   ClearUndoStack;
    function    GetUndoStackSize : integer;
    procedure   PushToUndoStack( Info : tSelectionInfo ); overload;
    procedure   PushToUndoStack( const ThingInfo : tThingInfo ); overload;
    function    PopFromUndoStack : tObject;
  end;

  tSelectionRegion = record
    Area : tRect;
    Plane : integer;
  end;

  tSelectionInfo = class( tObject )
  private
    fRegion : tSelectionRegion;
    fContext : tSelectionCommandContext;
    fBlocks : pBlock;
    fMap : tMap;
    function GetBufferSize : integer;
    function GetWidth : integer;
    function GetHeight : integer;
    function GetSize : integer;
  protected
    procedure AllocateBlocks;
    procedure AssignBlocks( BlockData : pBlock );
  public
    constructor Create( Map : tMap; const Region : tSelectionRegion; Context : tSelectionCommandContext ); overload;
    constructor Create( const Info : tSelectionInfo ); overload;
    destructor  Destroy; override;
    property Region : tSelectionRegion read fRegion;
    property Blocks : pBlock read fBlocks;
    property Context : tSelectionCommandContext read fContext;
    property BufferSize : integer read GetBufferSize;
    property Width : integer read GetWidth;
    property Height : integer read GetHeight;
    property Size : integer read GetSize;
    property Map : tMap read fMap;
  end;

  tSelectionHandler = class( tObject )
  private
    fContext : tSelectionCommandContext;
    procedure ProcessSelectionImpl( Info : tSelectionInfo; Command : tSelectionCommand; FreeCommand : boolean );
  public
    constructor Create;
    destructor  Destroy; override;
    procedure   ProcessSelection( Map : tMap; var Region : tSelectionRegion; Command : tSelectionCommand; FreeCommand : boolean = true );
    procedure   PushBlockToUndoStack( Map : tMap; const Location : tPoint );
    procedure   PushThingToUndoStack( const ThingInfo : tThingInfo );
    property    Context : tSelectionCommandContext read fContext;
  end;

  tSelectionCommand = class( tObject )
  public
    procedure AdjustSelection( SelectionInfo : tSelectionInfo ); virtual;
    procedure PreVisit( SelectionInfo : tSelectionInfo ); virtual;
    procedure PostVisit( const SelectionInfo : tSelectionInfo ); virtual;
    procedure VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock ); virtual;
  end;

  tUndoCommand = class( tSelectionCommand )
  private
    fIsBlockData : boolean;
    UndoData : tObject;
    pUndoScan : pBlock;
    procedure RestoreThing( Map : tMap; Thing : tThing );
  public
    procedure AdjustSelection( SelectionInfo : tSelectionInfo ); override;
    procedure PreVisit( SelectionInfo : tSelectionInfo ); override;
    procedure VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock ); override;
    destructor Destroy; override;
    property  IsBlockData : boolean read fIsBlockData;
  end;

  tCopyCommand = class( tSelectionCommand )
  public
    procedure PreVisit( SelectionInfo : tSelectionInfo ); override;
  end;

  tUndoableCommand = class( tSelectionCommand )
  private
    procedure RememberSelection( SelectionInfo : tSelectionInfo );
  public
    procedure PreVisit( SelectionInfo : tSelectionInfo ); override;
  end;

  tPasteCommand = class( tUndoableCommand )
  private
    LocalInfo : tSelectionInfo;
    BlockShift : integer;
    pRowStart, pRowScan : pBlock;
    LastY : integer;
    Count : tPoint;
  public
    class function ClipboardContainsData : boolean;
    procedure AdjustSelection( SelectionInfo : tSelectionInfo ); override;
    procedure VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock ); override;
    destructor Destroy; override;
  end;

  tDeleteCommand = class( tUndoableCommand )
  public
    procedure VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock ); override;
  end;

  tShiftCommand = class( tUndoableCommand )
  private
    RaiseMode : boolean;
  public
    constructor Create( RaiseMode : boolean );
    procedure VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock ); override;
  end;

  tRememberMapCommand = class( tUndoableCommand )
  public
    procedure AdjustSelection( SelectionInfo : tSelectionInfo ); override;
  end;

function EncodeBlockAsColour( Block : tBlock ) : tColor;
function DecodeBlockFromColour( Colour : tColor ) : tBlock;

implementation

uses
  Math, Windows, Clipbrd, Classes;

var
  hClipboardFormat : cardinal;

function EncodeBlockAsColour( Block : tBlock ) : tColor;
var
  Idx, Mask : integer;
begin
  result := 0;
  Mask := 3;
  for Idx := 0 to MAP_SIZE_COLUMN - 1 do
  begin
    if ( Block and Mask ) <> 0 then
      result := 31 + ( 32 * Idx );
    Mask := Mask shl 2;
  end;
  result := result or ( result shl 8 ) or ( result shl 16 );
end;

function DecodeBlockFromColour( Colour : tColor ) : tBlock;
var
  r, g, b, a : integer;
begin
  r := Colour and $ff;
  g := ( Colour and $ff00 ) shr 8;
  b := ( Colour and $ff0000 ) shr 16;
  a := ( Max( r, Max( g, b ) ) + 31 ) div 32;
  if a > 0 then
    a := ( 1 shl ( a * 2 ) ) - 1;
  result := tBlock( a );
end;

(* tSelectionCommandContext *)

constructor tSelectionCommandContext.Create;
begin
  inherited;
  fUndoStack := tObjectList.Create;
end;

destructor tSelectionCommandContext.Destroy;
begin
  fUndoStack.Free;
  inherited;
end;

procedure tSelectionCommandContext.ClearUndoStack;
begin
  fUndoStack.Clear;
end;

function tSelectionCommandContext.GetUndoStackSize : integer;
begin
  GetUndoStackSize := fUndoStack.Count;
end;

procedure tSelectionCommandContext.PushToUndoStack( Info : tSelectionInfo );
begin
  fUndoStack.Add( tSelectionInfo.Create( Info ) );
end;

procedure tSelectionCommandContext.PushToUndoStack( const ThingInfo : tThingInfo );
var
  Thing : tThing;
begin
  Thing := tThing.Create;
  try
    Thing.Info := ThingInfo;
    fUndoStack.Add( Thing );
  except
    Thing.Free;
    raise;
  end;
end;

function tSelectionCommandContext.PopFromUndoStack : tObject;
var
  Idx : integer;
begin
  Idx := fUndoStack.Count - 1;
  result := fUndoStack[ Idx ];
  fUndoStack[ Idx ] := nil;  // Ensure that object doesn't get freed by the list
  fUndoStack.Delete( Idx );
end;

(* tSelectionInfo *)

constructor tSelectionInfo.Create( Map : tMap; const Region : tSelectionRegion; Context : tSelectionCommandContext );
begin
  inherited Create;
  Self.fMap := Map;
  Self.fRegion := Region;
  Self.fContext := Context;
end;

constructor tSelectionInfo.Create( const Info : tSelectionInfo );
begin
  Create( Info.Map, Info.Region, Info.Context );
  AssignBlocks( Info.Blocks );
end;

destructor tSelectionInfo.Destroy;
begin
  if fBlocks <> nil then
    FreeMem( fBlocks );
  inherited;
end;

function tSelectionInfo.GetBufferSize : integer;
begin
  result := Size * SizeOf( tBlock );
end;

function tSelectionInfo.GetWidth : integer;
begin
  result := Region.Area.Right - Region.Area.Left;
end;

function tSelectionInfo.GetHeight : integer;
begin
  result := Region.Area.Bottom - Region.Area.Top;
end;

function tSelectionInfo.GetSize : integer;
begin
  result := Width * Height;
end;

procedure tSelectionInfo.AllocateBlocks;
begin
  if fBlocks <> nil then
    FreeMem( fBlocks );
  GetMem( fBlocks, BufferSize );
end;

procedure tSelectionInfo.AssignBlocks( BlockData : pBlock );
begin
  if fBlocks = nil then
    AllocateBlocks;
  Move( BlockData^, fBlocks^, BufferSize );
end;

(* tSelectionHandler *)

constructor tSelectionHandler.Create;
begin
  inherited;
  fContext := tSelectionCommandContext.Create;
end;

destructor tSelectionHandler.Destroy;
begin
  fContext.Free;
  inherited;
end;

procedure tSelectionHandler.ProcessSelectionImpl( Info : tSelectionInfo; Command : tSelectionCommand; FreeCommand : boolean );

procedure NormaliseArea( var Rect : tRect );
var
  Temp : integer;
begin
  if Rect.Left > Rect.Right then
  begin
    Temp := Rect.Left;
    Rect.Left := Rect.Right;
    Rect.Right := Temp;
  end;
  if Rect.Top > Rect.Bottom then
  begin
    Temp := Rect.Top;
    Rect.Top := Rect.Bottom;
    Rect.Bottom := Temp;
  end;
end;

var
  pMapRow, pMapScan, pBufferScan : pBlock;
  Pass, Mask, x, y : integer;
  Initialised : boolean;
begin
  Initialised := false;
  try
    NormaliseArea( Info.fRegion.Area );
    try
      Command.AdjustSelection( Info );
      NormaliseArea( Info.fRegion.Area );
      Info.AllocateBlocks;

      if Info.Region.Plane >= 0 then
        Mask := 3 shl ( Info.Region.Plane * 2 )
      else
        Mask := -1;

      for Pass := 1 to 3 do
      begin
        pBufferScan := Info.fBlocks;
        pMapRow := Info.Map.BlockData;
        with Info.Region.Area do
        begin
          inc( pMapRow, Top * Info.Map.Width + Left );
          for y := Top to Bottom - 1 do
          begin
            pMapScan := pMapRow;
            for x := Left to Right - 1 do
            begin
              case Pass of
                1:
                  pBufferScan^ := pMapScan^ and Mask;
                2:
                  Command.VisitBlock( Info, Point( x, y ), pBufferScan^ );
                3:
                  pMapScan^ := ( pMapScan^ and not Mask ) or ( pBufferScan^ and Mask );
              end;
              inc( pBufferScan );
              inc( pMapScan );
            end;
            inc( pMapRow, Info.Map.Width );
          end;
        end;

        if Pass = 1 then
        begin
          Initialised := true;
          Command.PreVisit( Info );
        end;
      end;
    finally
      if Initialised then
        Command.PostVisit( Info );
    end;
  finally
    if FreeCommand then
      Command.Free;
  end;

  Info.Map.EnsureThingsAreNotObstructed;
end;

procedure tSelectionHandler.ProcessSelection( Map : tMap; var Region : tSelectionRegion; Command : tSelectionCommand; FreeCommand : boolean );
var
  Info : tSelectionInfo;
begin
  Info := tSelectionInfo.Create( Map, Region, Context );
  try
    ProcessSelectionImpl( Info, Command, FreeCommand );
    Region := Info.Region;
  finally
    Info.Free;
  end;
end;

procedure tSelectionHandler.PushBlockToUndoStack( Map : tMap; const Location : tPoint );
var
  Region : tSelectionRegion;
  Info : tSelectionInfo;
begin
  with Location do
    Region.Area := Rect( x, y, x + 1, y + 1 );
  Region.Plane := -1;
  Info := tSelectionInfo.Create( Map, Region, Context );
  try
    Info.AllocateBlocks;
    Info.Blocks^ := Map.Column[ Location.x, Location.y ];
    Context.PushToUndoStack( Info );
  except
    Info.Free;
    raise;
  end;
end;

procedure tSelectionHandler.PushThingToUndoStack( const ThingInfo : tThingInfo );
begin
  Context.PushToUndoStack( ThingInfo );
end;

(* tSelectionCommand *)

procedure tSelectionCommand.AdjustSelection( SelectionInfo : tSelectionInfo );
begin
end;

procedure tSelectionCommand.PreVisit( SelectionInfo : tSelectionInfo );
begin
end;

procedure tSelectionCommand.VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock );
begin
end;

procedure tSelectionCommand.PostVisit;
begin
end;

(* tCopyCommand *)

procedure tCopyCommand.PreVisit( SelectionInfo : tSelectionInfo );

procedure CopyNative;
var
  hMem : hGlobal;
  pMem : ^tSelectionRegion;
  BufferSize : integer;
begin
  BufferSize := SizeOf( tSelectionRegion ) + SelectionInfo.BufferSize;
  hMem := GlobalAlloc( GMEM_MOVEABLE or GMEM_DDESHARE, BufferSize );
  if hMem <> 0 then
  begin
    pMem := GlobalLock( hMem );
    try
      Move( SelectionInfo.Region, pMem^, SizeOf( tSelectionRegion ) );
      inc( pMem );
      Move( SelectionInfo.Blocks^, pMem^, SelectionInfo.BufferSize );
    finally
      GlobalUnlock( hMem );
    end;
    Clipboard.SetAsHandle( hClipboardFormat, hMem );
  end;
end;

procedure CopyBitmap;
var
  Image : Graphics.tBitmap;
  x, y : integer;
  pBlockScan : pBlock;
begin
  Image := Graphics.tBitmap.Create;
  try
    Image.Width := SelectionInfo.Width;
    Image.Height := SelectionInfo.Height;
    Image.Monochrome := false;
    pBlockScan := SelectionInfo.Blocks;
    for y := 0 to Image.Height - 1 do
      for x := 0 to Image.Width - 1 do
      begin
        Image.Canvas.Pixels[ x, y ] := EncodeBlockAsColour( pBlockScan^ );
        inc( pBlockScan );
      end;
    Clipboard.Assign( Image );
  finally
    Image.Free;
  end;
end;

begin
  Clipboard.Open;
  try
    CopyBitmap;
    CopyNative;
  finally
    Clipboard.Close;
  end;
end;

(* tUndoableCommand *)

procedure tUndoableCommand.RememberSelection( SelectionInfo : tSelectionInfo );
begin
  SelectionInfo.Context.PushToUndoStack( SelectionInfo );
end;

procedure tUndoableCommand.PreVisit( SelectionInfo : tSelectionInfo );
begin
  inherited;
  RememberSelection( SelectionInfo );
end;

(* tPasteCommand *)

class function tPasteCommand.ClipboardContainsData : boolean;
begin
  result := Clipboard.HasFormat( hClipboardFormat ) or Clipboard.HasFormat( CF_BITMAP );
end;

procedure tPasteCommand.AdjustSelection( SelectionInfo : tSelectionInfo );

function GetSelectionFromClipboard : tSelectionInfo;

function GetBitmap : tSelectionInfo;
var
  Image : Graphics.tBitmap;
  Region : tSelectionRegion;
  x, y : integer;
  pBlockScan : pBlock;
begin
  result := nil;
  if Clipboard.HasFormat( CF_BITMAP ) then
  begin
    Image := Graphics.tBitmap.Create;
    try
      Image.Assign( Clipboard );
      if ( Image.Width > 0 ) and ( Image.Height > 0 ) then
      begin
        Region.Area := Rect( 0, 0, Image.Width, Image.Height );
        Region.Plane := -1;
        result := tSelectionInfo.Create( SelectionInfo.Map, Region, SelectionInfo.Context );
        try
          result.AllocateBlocks;
          pBlockScan := result.Blocks;
          for y := 0 to Image.Height - 1 do
            for x := 0 to Image.Width - 1 do
            begin
              pBlockScan^ := DecodeBlockFromColour( Image.Canvas.Pixels[ x, y ] );
              inc( pBlockScan );
            end;
        except
          result.Free;
          raise;
        end;
      end;
    finally
      Image.Free;
    end;
  end;
end;

function GetNative( hMem : tHandle ) : tSelectionInfo;
var
  pRegion : ^tSelectionRegion;
begin
  pRegion := GlobalLock( hMem );
  try
    result := tSelectionInfo.Create( SelectionInfo.Map, pRegion^, SelectionInfo.Context );
    try
      inc( pRegion );
      result.AssignBlocks( pBlock( pRegion ) );
    except
      result.Free;
      raise;
    end;
  finally
    GlobalUnlock( hMem );
  end;
end;

var
  hMem : tHandle;
begin
  Clipboard.Open;
  try
    hMem := Clipboard.GetAsHandle( hClipboardFormat );
    if hMem = 0 then
      result := GetBitmap
    else
      result := GetNative( hMem );
  finally
    Clipboard.Close;
  end;
end;

procedure AdjustUserSelection;
begin
  if SelectionInfo.Width < LocalInfo.Width then
    with SelectionInfo.Region.Area do
    begin
      Right := Left + LocalInfo.Width;
      if Right > SelectionInfo.Map.Width then
        Right := SelectionInfo.Map.Width;
    end;

  if SelectionInfo.Height < LocalInfo.Height then
    with SelectionInfo.Region.Area do
    begin
      Bottom := Top + LocalInfo.Height;
      if Bottom > SelectionInfo.Map.Height then
        Bottom := SelectionInfo.Map.Height;
    end;
end;

begin
  LocalInfo := GetSelectionFromClipboard;
  if LocalInfo <> nil then
  begin
    AdjustUserSelection;
    pRowStart := LocalInfo.Blocks;
    LastY := SelectionInfo.Region.Area.Top;
    Count.y := LocalInfo.Height;
    if ( LocalInfo.Region.Plane >= 0 ) and ( SelectionInfo.Region.Plane >= 0 ) then
      BlockShift := 2 * ( SelectionInfo.Region.Plane - LocalInfo.Region.Plane )
    else
      BlockShift := 0;
  end;
end;

procedure tPasteCommand.VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock );
begin
  if LocalInfo = nil then
    Exit;

  if Position.y <> LastY then
  begin
    dec( Count.y );
    if Count.y = 0 then
    begin
      pRowStart := LocalInfo.Blocks;
      Count.y := LocalInfo.Height;
    end
    else
      inc( pRowStart, LocalInfo.Width );
    Count.x := 0;
    LastY := Position.y;
  end;

  dec( Count.x );
  if Count.x < 0 then
  begin
    Count.x := LocalInfo.Width - 1;
    pRowScan := pRowStart;
  end;

  if BlockShift >= 0 then
    Block := pRowScan^ shl BlockShift
  else
    Block := pRowScan^ shr -BlockShift;
  inc( pRowScan );
end;

destructor tPasteCommand.Destroy;
begin
  LocalInfo.Free;
  inherited;
end;

(* tDeleteCommand *)

procedure tDeleteCommand.VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock );
begin
  Block := 0;
end;

(* tUndoCommand *)

procedure tUndoCommand.AdjustSelection( SelectionInfo : tSelectionInfo );
var
  UndoInfo : tSelectionInfo;
  Thing : tThing;
begin
  UndoData := SelectionInfo.Context.PopFromUndoStack;
  fIsBlockData := UndoData is tSelectionInfo;
  if fIsBlockData then
  begin
    UndoInfo := tSelectionInfo( UndoData );
    SelectionInfo.fRegion := UndoInfo.Region;
    pUndoScan := UndoInfo.Blocks;
    SelectionInfo.Map.invalidateLightMaps;
  end
  else
  begin
    Thing := tThing( UndoData );
    with Thing.Info.Position do
      SelectionInfo.fRegion.Area := Rect( x, z, x + 1, z + 1 );
  end;
end;

procedure tUndoCommand.RestoreThing( Map : tMap; Thing : tThing );

function IsValidThing : boolean;
begin
  result := Ord( Thing.Info.ThingType ) >= 0;
end;

var
  Idx : integer;
  List : tList;
  MapThing : tThing;
  TP : tIntPoint3d;
  Found : boolean;
begin
  TP := Thing.Info.Position;
  List := tList.Create;
  try
    Map.GetThings( List );
    Found := false;
    for Idx := 0 to List.Count - 1 do
    begin
      MapThing := tThing( List[ Idx ] );
      with MapThing.Info.Position do
        if ( TP.x = x ) and ( TP.y = y ) and ( TP.z = z ) then
        begin
          if IsValidThing then
            MapThing.Info := Thing.Info
          else
            Map.DeleteThing( MapThing );
          Found := true;
          break;
        end;
    end;

    if not Found and IsValidThing then
      Map.AddThing( Thing.Info );
  finally
    List.Free;
  end;
end;

procedure tUndoCommand.PreVisit( SelectionInfo : tSelectionInfo );
begin
  if not IsBlockData then
    RestoreThing( SelectionInfo.Map, tThing( UndoData ) );
end;

procedure tUndoCommand.VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock );
begin
  if IsBlockData then
  begin
    Block := pUndoScan^;
    inc( pUndoScan );
  end;
end;

destructor tUndoCommand.Destroy;
begin
  UndoData.Free;
end;

(* tShiftCommand *)

constructor tShiftCommand.Create( RaiseMode : boolean );
begin
  inherited Create;
  Self.RaiseMode := RaiseMode;
end;

procedure tShiftCommand.VisitBlock( const SelectionInfo : tSelectionInfo; Position : tPoint; var Block : tBlock );
begin
  if RaiseMode then
    Block := tBlock( Block shl 2 )
  else
    Block := Block shr 2;
end;

(* tRememberMapCommand *)

procedure tRememberMapCommand.AdjustSelection( SelectionInfo : tSelectionInfo );
begin
  with SelectionInfo do
  begin
    fRegion.Area := Rect( 0, 0, Map.Width, Map.Height );
    fRegion.Plane := -1;
  end;
end;

initialization
  hClipboardFormat := RegisterClipboardFormat( 'AntAttackMapData' );
end.
