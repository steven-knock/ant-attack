object frmLevelDetail: TfrmLevelDetail
  Left = 190
  Top = 105
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  BorderWidth = 8
  Caption = 'Level Detail'
  ClientHeight = 352
  ClientWidth = 584
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  Scaled = False
  PixelsPerInch = 96
  TextHeight = 13
  object grpLevel: TGroupBox
    Left = 0
    Top = 0
    Width = 584
    Height = 352
    Align = alClient
    Caption = '&Level Detail'
    TabOrder = 0
    DesignSize = (
      584
      352)
    object lstLevels: TListView
      Left = 16
      Top = 32
      Width = 553
      Height = 209
      Anchors = [akLeft, akTop, akRight]
      Columns = <
        item
          Caption = 'Level'
          Width = 64
        end
        item
          Caption = 'Maximum Ants'
          Width = 96
        end
        item
          Caption = 'Spawn Interval'
          Width = 96
        end
        item
          Caption = 'Draw Distance'
          Width = 96
        end
        item
          Caption = 'Sun Latitude'
          Width = 96
        end
        item
          Caption = 'Sun Longitude'
          Width = 96
        end>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnClick = lstLevelsClick
      OnDblClick = lstLevelsDblClick
    end
    object btnCancel: TButton
      Left = 488
      Top = 312
      Width = 80
      Height = 25
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = '&Cancel'
      ModalResult = 2
      TabOrder = 3
    end
    object grpShadow: TGroupBox
      Left = 16
      Top = 248
      Width = 176
      Height = 88
      Caption = 'Light &Map Generation'
      TabOrder = 1
      object btnInterpolate: TButton
        Left = 16
        Top = 20
        Width = 144
        Height = 25
        Caption = '&Interpolate Light Position'
        TabOrder = 0
        OnClick = btnInterpolateClick
      end
      object btnLightMap: TButton
        Left = 16
        Top = 52
        Width = 144
        Height = 25
        Caption = '&Build Light Maps'
        TabOrder = 1
        OnClick = btnLightMapClick
      end
    end
    object btnEdit: TButton
      Left = 296
      Top = 312
      Width = 80
      Height = 25
      Anchors = [akTop, akRight]
      Caption = '&Edit'
      Default = True
      Enabled = False
      TabOrder = 2
      OnClick = btnEditClick
    end
    object btnOK: TButton
      Left = 392
      Top = 312
      Width = 80
      Height = 25
      Anchors = [akTop, akRight]
      Caption = '&OK'
      TabOrder = 4
      OnClick = btnOKClick
    end
  end
end
