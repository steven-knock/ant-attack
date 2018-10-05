object frmGame: TfrmGame
  Left = 397
  Top = 199
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Ant Attack - %s'
  ClientHeight = 480
  ClientWidth = 640
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDefaultPosOnly
  Scaled = False
  Visible = True
  OnActivate = FormActivate
  OnClose = FormClose
  OnDeactivate = FormDeactivate
  OnKeyUp = FormKeyUp
  OnMouseDown = FormMouseDown
  OnMouseUp = FormMouseUp
  OnShortCut = FormShortCut
  PixelsPerInch = 96
  TextHeight = 13
  object pnlRender: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 480
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
    object pbxRender: TPaintBox
      Left = 0
      Top = 0
      Width = 640
      Height = 480
      Align = alClient
      OnMouseDown = FormMouseDown
      OnMouseUp = FormMouseUp
      OnPaint = pbxRenderPaint
    end
  end
  object tmrRender: TTimer
    Enabled = False
    Interval = 100
    OnTimer = tmrRenderTimer
    Left = 8
    Top = 8
  end
end
