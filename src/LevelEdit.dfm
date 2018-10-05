object frmLevelEdit: TfrmLevelEdit
  Left = 395
  Top = 184
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Edit Level'
  ClientHeight = 256
  ClientWidth = 224
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  Scaled = False
  DesignSize = (
    224
    256)
  PixelsPerInch = 96
  TextHeight = 13
  object grpLevel: TGroupBox
    Left = 8
    Top = 8
    Width = 208
    Height = 200
    Anchors = [akLeft, akTop, akRight, akBottom]
    Caption = 'Level %d'
    TabOrder = 0
    object lblLatitude: TLabel
      Left = 24
      Top = 128
      Width = 96
      Height = 13
      AutoSize = False
      Caption = 'Sun L&atitude:'
    end
    object lblLongitude: TLabel
      Left = 24
      Top = 160
      Width = 96
      Height = 13
      AutoSize = False
      Caption = 'Sun L&ongitude:'
    end
    object lblAntCount: TLabel
      Left = 24
      Top = 32
      Width = 96
      Height = 13
      AutoSize = False
      Caption = '&Maximum Ants:'
    end
    object lblSpawnInterval: TLabel
      Left = 24
      Top = 64
      Width = 96
      Height = 13
      AutoSize = False
      Caption = '&Spawn Interval:'
    end
    object lblDrawDistance: TLabel
      Left = 24
      Top = 96
      Width = 96
      Height = 13
      AutoSize = False
      Caption = '&Draw Distance:'
    end
    object edtLatitude: TEdit
      Left = 120
      Top = 125
      Width = 64
      Height = 21
      TabOrder = 6
    end
    object edtLongitude: TEdit
      Left = 120
      Top = 157
      Width = 64
      Height = 21
      TabOrder = 7
    end
    object edtAntCount: TEdit
      Left = 120
      Top = 29
      Width = 48
      Height = 21
      TabOrder = 0
      Text = '0'
    end
    object edtSpawnInterval: TEdit
      Left = 120
      Top = 61
      Width = 48
      Height = 21
      TabOrder = 2
      Text = '1'
    end
    object spnAntCount: TUpDown
      Left = 168
      Top = 29
      Width = 15
      Height = 21
      Associate = edtAntCount
      Min = 0
      Position = 0
      TabOrder = 1
      Wrap = False
    end
    object spnSpawnInterval: TUpDown
      Left = 168
      Top = 61
      Width = 15
      Height = 21
      Associate = edtSpawnInterval
      Min = 1
      Max = 200
      Position = 1
      TabOrder = 3
      Wrap = False
    end
    object edtDrawDistance: TEdit
      Left = 120
      Top = 93
      Width = 48
      Height = 21
      TabOrder = 4
      Text = '5'
    end
    object spnDrawDistance: TUpDown
      Left = 168
      Top = 93
      Width = 15
      Height = 21
      Associate = edtDrawDistance
      Min = 5
      Max = 255
      Position = 5
      TabOrder = 5
      Wrap = False
    end
  end
  object btnOK: TButton
    Left = 56
    Top = 224
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'OK'
    Default = True
    TabOrder = 1
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 144
    Top = 224
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
