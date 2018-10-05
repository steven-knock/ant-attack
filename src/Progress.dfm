object frmProgress: TfrmProgress
  Left = 190
  Top = 105
  BorderStyle = bsDialog
  BorderWidth = 8
  ClientHeight = 101
  ClientWidth = 256
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object pnlProgress: TPanel
    Left = 0
    Top = 0
    Width = 256
    Height = 69
    Align = alClient
    BevelOuter = bvLowered
    BorderWidth = 8
    TabOrder = 0
    object lblInformation: TLabel
      Left = 9
      Top = 9
      Width = 238
      Height = 25
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      WordWrap = True
    end
    object barProgress: TProgressBar
      Left = 9
      Top = 34
      Width = 238
      Height = 26
      Align = alBottom
      Min = 0
      Max = 100
      TabOrder = 0
    end
  end
  object pnlButton: TPanel
    Left = 0
    Top = 69
    Width = 256
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnCancel: TButton
      Left = 180
      Top = 6
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 0
      OnClick = btnCancelClick
    end
  end
end
