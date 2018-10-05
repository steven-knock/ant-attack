object frmGameLog: TfrmGameLog
  Left = 190
  Top = 105
  Width = 600
  Height = 656
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSizeToolWin
  BorderWidth = 4
  Caption = 'Game Log'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object pnlLog: TPanel
    Left = 0
    Top = 0
    Width = 584
    Height = 621
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lstLog: TListBox
      Left = 0
      Top = 40
      Width = 584
      Height = 581
      Style = lbVirtual
      Align = alClient
      Color = clBlack
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clLime
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ItemHeight = 13
      ParentFont = False
      TabOrder = 0
      OnData = lstLogData
    end
    object pnlControls: TPanel
      Left = 0
      Top = 0
      Width = 584
      Height = 40
      Align = alTop
      BevelOuter = bvNone
      BorderWidth = 4
      TabOrder = 1
      DesignSize = (
        584
        40)
      object lblFilter: TLabel
        Left = 8
        Top = 16
        Width = 64
        Height = 13
        AutoSize = False
        Caption = 'Filter:'
      end
      object btnSave: TButton
        Left = 304
        Top = 8
        Width = 80
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '&Save'
        TabOrder = 0
        OnClick = btnSaveClick
      end
      object btnLoad: TButton
        Left = 400
        Top = 8
        Width = 80
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '&Load'
        TabOrder = 1
        OnClick = btnLoadClick
      end
      object btnClear: TButton
        Left = 496
        Top = 8
        Width = 80
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '&Clear'
        TabOrder = 2
        OnClick = btnClearClick
      end
      object cmbFilter: TComboBox
        Left = 72
        Top = 11
        Width = 80
        Height = 21
        Style = csDropDownList
        ItemHeight = 13
        TabOrder = 3
        OnClick = cmbFilterClick
      end
    end
  end
  object dlgSave: TSaveDialog
    Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofNoChangeDir, ofPathMustExist, ofEnableSizing]
    Left = 360
  end
  object dlgOpen: TOpenDialog
    Filter = 'Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 456
  end
end
