unit HelpHandler;

interface

uses
  Messaging;

type
  tHelpMessageHandler = class( tObject )
  private
    fHelpActive : boolean;
  public
    procedure ProcessHelpRequest( MessageList : tMessageList );
    property  HelpActive : boolean read fHelpActive write fHelpActive;
  end;

implementation

uses
  Colour, Geometry;

const
  MSG_HELP = -3;

procedure tHelpMessageHandler.ProcessHelpRequest( MessageList : tMessageList );
type
  tStyle = ( TITLE, CAPTION, KEY_LEFT, KEY_RIGHT );

var
  y : _float;

procedure AddMessage( Style : tStyle; const Text : string; AdvanceLines : _float = 1; x : _float = 0 );
const
  Size : array [ tStyle ] of _float = ( 11, 10.5, 10, 10 );
  XAlignment : array [ tStyle ] of _float = ( 0.5, 0.5, 0, 1 );
  Colour : array [ tStyle ] of ^tColour = ( @COLOUR_HELP_TITLE, @COLOUR_HELP_CAPTION, @COLOUR_HELP_KEY, @COLOUR_HELP_ACTION );
begin
  MessageList.AddMessage( tMessage.Create( MSG_HELP, Text, Size[ Style ], 0 ).SetPosition( x, y ).SetAlignment( XAlignment[ Style ], 0 ).SetColour( Colour[ Style ]^ ) );
  y := y + ( AdvanceLines * Size[ Style ] / 100 );
end;

procedure AddControlMessage( const Key, Action : string );
begin
  AddMessage( KEY_RIGHT, Key + ' ', 0 );
  AddMessage( KEY_LEFT, '= ' + Action );
end;

begin
  if not HelpActive then
  begin
    y := -0.7;
    AddMessage( TITLE, 'Objective' );
    AddMessage( CAPTION, 'Locate the captive and' );
    AddMessage( CAPTION, 'lead them to freedom', 2 );

    AddMessage( TITLE, 'Controls' );
    AddControlMessage( 'Mouse', 'Rotate Viewpoint' );
    AddControlMessage( 'A / Left', 'Move Left' );
    AddControlMessage( 'D / Right', 'Move Right' );
    AddControlMessage( 'W / Up', 'Move Forwards' );
    AddControlMessage( 'S / Down', 'Move Backwards' );
    AddControlMessage( 'Ctrl / LMB', 'Throw Grenade' );
    AddControlMessage( 'Space / RMB', 'Jump' );
    AddControlMessage( 'Shift', 'Walk' );
    AddControlMessage( 'Tab', 'Perspective' );
  end
  else
    MessageList.ClearCategory( MSG_HELP );
  HelpActive := not HelpActive;
end;

end.
