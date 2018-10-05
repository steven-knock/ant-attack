unit GameLog;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Log;

type
  TfrmGameLog = class(TForm)
    pnlLog: TPanel;
    lstLog: TListBox;
    pnlControls: TPanel;
    btnSave: TButton;
    btnLoad: TButton;
    btnClear: TButton;
    dlgSave: TSaveDialog;
    dlgOpen: TOpenDialog;
    cmbFilter: TComboBox;
    lblFilter: TLabel;
    procedure btnClearClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure cmbFilterClick(Sender: TObject);
    procedure lstLogData( Control : tWinControl; Index : integer; var Data : string );
  private
    fLog : tStringList;
    fFilteredLog : tList;
    fFilter : tLogCategory;
    procedure   ApplyFilter( Index : integer = -1 );
    function    GetLog : tStrings;
    procedure   LogAdded( Sender : tObject );
    procedure   UpdateCount;
  public
    constructor Create( Owner : tComponent ); override;
    destructor  Destroy; override;
    property    Log : tStrings read GetLog;
  end;

implementation

{$R *.dfm}

type
  tNotifyingStringList = class( tStringList )
  private
    Event : tNotifyEvent;
  public
    constructor Create( Event : tNotifyEvent );
    function    AddObject( const s : string; obj : tObject ) : integer; override;
    procedure   Clear; override;
    procedure   LoadFromFile( const FileName : string ); override;
  end;

(* tNotifyingStringList *)

constructor tNotifyingStringList.Create( Event : tNotifyEvent );
begin
  inherited Create;
  Self.Event := Event;
end;

function tNotifyingStringList.AddObject( const s : string; obj : tObject ) : integer;
begin
  result := inherited AddObject( s, obj );
  Event( Self );
end;

procedure tNotifyingStringList.Clear;
begin
  inherited;
  Event( Self );
end;

procedure tNotifyingStringList.LoadFromFile( const FileName : string );
begin
  inherited;
  Event( Self );
end;

(* tfrmGameLog *)

constructor tfrmGameLog.Create( Owner : tComponent );
var
  Category : tLogCategory;
begin
  inherited;
  fLog := tNotifyingStringList.Create( LogAdded );
  fFilter := LOG_ALL;
  fFilteredLog := tList.Create;
  for Category := Low( tLogCategory ) to High( tLogCategory ) do
    cmbFilter.Items.Add( LogCategoryDescription[ Category ] );
  cmbFilter.ItemIndex := 0;
  ApplyFilter;
end;

destructor tfrmGameLog.Destroy;
begin
  fFilteredLog.Free;
  fLog.Free;
  inherited;
end;

procedure TfrmGameLog.btnClearClick(Sender: TObject);
begin
  Log.Clear;
end;

procedure TfrmGameLog.btnSaveClick(Sender: TObject);
begin
  if dlgSave.Execute then
    Log.SaveToFile( dlgSave.FileName );
end;

procedure TfrmGameLog.btnLoadClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    Log.LoadFromFile( dlgOpen.FileName );
end;

procedure tfrmGameLog.cmbFilterClick(Sender: TObject);
begin
  fFilter := tLogCategory( cmbFilter.ItemIndex );
  ApplyFilter;
end;

procedure tfrmGameLog.lstLogData( Control : tWinControl; Index : integer; var Data : string );
begin
  if fFilter <> LOG_ALL then
    data := fLog[ Integer( fFilteredLog[ Index ] ) ]
  else
    data := fLog[ Index ];
end;

procedure tfrmGameLog.LogAdded( Sender : tObject );
begin
  ApplyFilter( fLog.Count - 1 );
  lstLog.TopIndex := lstLog.Count - 1;
end;

procedure tfrmGameLog.UpdateCount;
begin
  if fFilter = LOG_ALL then
    lstLog.Count := fLog.Count
  else
    lstLog.Count := fFilteredLog.Count;
end;

procedure tfrmGameLog.ApplyFilter( Index : integer );
var
  Description : string;
  DescriptionLength : integer;

procedure FilterLine( Idx : integer );
begin
  if Copy( fLog[ Idx ], 0, DescriptionLength ) = Description then
    fFilteredLog.Add( Pointer( Idx ) );
end;

var
  Idx : integer;

begin
  if ( Index < 0 ) or ( fFilter = LOG_ALL ) then
    fFilteredLog.Clear;
  if fFilter <> LOG_ALL then
  begin
    Description := LogCategoryDescription[ fFilter ];
    DescriptionLength := Length( Description );
    if Index < 0 then
      for Idx := 0 to fLog.Count - 1 do
        FilterLine( Idx )
    else
      FilterLine( Index );
  end;
  UpdateCount;
end;

function tfrmGameLog.GetLog : tStrings;
begin
  result := fLog;
end;

end.
