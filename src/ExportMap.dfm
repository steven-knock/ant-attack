object frmExport: TfrmExport
  Left = 190
  Top = 105
  BorderStyle = bsDialog
  Caption = 'Export Map'
  ClientHeight = 424
  ClientWidth = 368
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
    368
    424)
  PixelsPerInch = 96
  TextHeight = 13
  object grpFilename: TGroupBox
    Left = 8
    Top = 8
    Width = 352
    Height = 65
    Caption = '&Filename'
    TabOrder = 0
    object edtFilename: TEdit
      Left = 16
      Top = 24
      Width = 288
      Height = 21
      TabOrder = 0
    end
    object btnFilename: TButton
      Left = 312
      Top = 21
      Width = 24
      Height = 25
      Caption = '...'
      TabOrder = 1
      OnClick = btnFilenameClick
    end
  end
  object grpFormat: TGroupBox
    Left = 8
    Top = 88
    Width = 352
    Height = 152
    Anchors = [akLeft, akTop, akRight]
    Caption = 'E&xport Format'
    TabOrder = 1
    object btnPackedWord: TRadioButton
      Left = 16
      Top = 24
      Width = 288
      Height = 17
      Caption = '&2 bytes per column / 2 bits per block'
      Checked = True
      TabOrder = 0
      TabStop = True
      OnClick = rawExportFormatClick
    end
    object btnBytePerBlock: TRadioButton
      Left = 16
      Top = 48
      Width = 288
      Height = 17
      Caption = '&8 bytes per column / 1 byte per block'
      TabOrder = 1
      OnClick = rawExportFormatClick
    end
    object btnWordPerBlock: TRadioButton
      Left = 16
      Top = 72
      Width = 288
      Height = 17
      Caption = '&16 bytes per column / 2 bytes per block'
      TabOrder = 2
      OnClick = rawExportFormatClick
    end
    object btnSTLText: TRadioButton
      Left = 16
      Top = 96
      Width = 288
      Height = 17
      Caption = '&STL Text (STereoLithography file)'
      TabOrder = 3
      OnClick = stlExportFormatClick
    end
    object btnSTLBinary: TRadioButton
      Left = 16
      Top = 120
      Width = 288
      Height = 17
      Caption = '&STL Binary (STereoLithography file)'
      TabOrder = 4
      OnClick = stlExportFormatClick
    end
  end
  object grpRawOptions: TGroupBox
    Tag = 1
    Left = 8
    Top = 256
    Width = 352
    Height = 84
    Anchors = [akLeft, akRight, akBottom]
    Caption = '&Raw Options'
    TabOrder = 2
    object btnTitle: TCheckBox
      Tag = 1
      Left = 16
      Top = 24
      Width = 176
      Height = 17
      Caption = 'Include &title'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object btnDimension: TCheckBox
      Tag = 1
      Left = 16
      Top = 48
      Width = 176
      Height = 17
      Caption = 'Include &dimensions'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
  end
  object btnExport: TButton
    Left = 184
    Top = 384
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = '&Export'
    Default = True
    TabOrder = 3
    OnClick = btnExportClick
  end
  object btnCancel: TButton
    Left = 280
    Top = 384
    Width = 80
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
  object grpSTLOptions: TGroupBox
    Tag = 2
    Left = 8
    Top = 256
    Width = 352
    Height = 112
    Anchors = [akLeft, akTop, akBottom]
    Caption = 'STL &Options'
    TabOrder = 5
    Visible = False
    object lblScale: TLabel
      Left = 16
      Top = 83
      Width = 30
      Height = 13
      Caption = 'S&cale:'
      FocusControl = edtScale
    end
    object lblArea: TLabel
      Left = 16
      Top = 51
      Width = 25
      Height = 13
      Caption = '&Area:'
      FocusControl = edtScale
    end
    object lblLeft: TLabel
      Left = 56
      Top = 51
      Width = 8
      Height = 13
      AutoSize = False
      Caption = 'x'
      FocusControl = edtScale
    end
    object lblTop: TLabel
      Left = 120
      Top = 51
      Width = 8
      Height = 13
      AutoSize = False
      Caption = 'y'
      FocusControl = edtScale
    end
    object lblWidth: TLabel
      Left = 184
      Top = 51
      Width = 8
      Height = 13
      AutoSize = False
      Caption = 'w'
      FocusControl = edtScale
    end
    object lblHeight: TLabel
      Left = 248
      Top = 51
      Width = 8
      Height = 13
      AutoSize = False
      Caption = 'h'
      FocusControl = edtScale
    end
    object btnGroundPlane: TCheckBox
      Tag = 2
      Left = 16
      Top = 24
      Width = 176
      Height = 17
      Caption = 'Include g&round plane'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object edtScale: TEdit
      Left = 56
      Top = 80
      Width = 56
      Height = 21
      TabOrder = 5
      Text = '2'
    end
    object edtLeft: TEdit
      Left = 72
      Top = 48
      Width = 33
      Height = 21
      TabOrder = 1
      Text = '0'
    end
    object edtTop: TEdit
      Left = 136
      Top = 48
      Width = 33
      Height = 21
      TabOrder = 2
      Text = '0'
    end
    object edtWidth: TEdit
      Left = 200
      Top = 48
      Width = 33
      Height = 21
      TabOrder = 3
    end
    object edtHeight: TEdit
      Left = 264
      Top = 48
      Width = 33
      Height = 21
      TabOrder = 4
    end
  end
  object dlgExport: TSaveDialog
    Filter = 
      'Export Files (*.raw, *.stl)|*.raw;*.stl|Raw Files (*.raw)|*.raw|' +
      'STL Files (*.stl)|*.stl|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Left = 8
    Top = 384
  end
end
