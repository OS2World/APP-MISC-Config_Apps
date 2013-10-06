Unit MainFormUnit;

Interface

Uses
  Classes, Forms, Graphics, StdCtrls, Buttons, MultiColumnListBox, Dialogs;

const
  AppVersion = 'V1.1.1'; // $SS_REQUIRE_NEW_VERSION$

type
  TProgramType =
  (
    idBrowser,
    idMail,
    idNews,
    idFTP,
    idIRC
  );

Type
  TMainForm = Class (TForm)
    PathEdit: TEdit;
    BrowsePathButton: TButton;
    SelectDirectoryButton: TButton;
    WorkingDirectoryEdit: TEdit;
    ItemsListbox: TMultiColumnListBox;
    ApplyButton: TButton;
    CloseButton: TButton;
    PathLabel: TLabel;
    WorkingDirectoryLabel: TLabel;
    OpenDialog: TSystemOpenDialog;
    ChangeDirDialog: TChangeDirDialog;
    RestoreButton: TButton;
    ParametersEdit: TEdit;
    ParametersLabel: TLabel;
    VersionLabel: TLabel;
    Procedure ParametersEditOnChange (Sender: TObject);
    Procedure RestoreButtonOnClick (Sender: TObject);
    Procedure MainFormOnCloseQuery (Sender: TObject; Var CanClose: Boolean);
    Procedure WorkingDirectoryEditOnChange (Sender: TObject);
    Procedure ApplyButtonOnClick (Sender: TObject);
    Procedure SelectDirectoryButtonOnClick (Sender: TObject);
    Procedure BrowsePathButtonOnClick (Sender: TObject);
    Procedure PathEditOnChange (Sender: TObject);
    Procedure ItemsListboxOnItemFocus (Sender: TObject; Index: LongInt);
    Procedure MainFormOnCreate (Sender: TObject);
  Private
    {Insert private declarations here}
    FLastItem: TProgramType;
    FLastItemSet: boolean;
    Displaying: boolean;
    Changed: boolean;
  Public
    {Insert public declarations here}
    Function SelectedType: TProgramType;
    Procedure StoreEdits( P: TProgramType );
    Procedure LoadCurrentSettings;
  End;

Var
  MainForm: TMainForm;

Implementation

Uses
  PMWin, PMSHL,
  SysUtils,
  ACLFileUtility, ACLUtility, ACLStringUtility,
  ControlsUtility, ACLDialogs;

type
  TProgramSettings = record
    ProgramType: TProgramType;
    Name: string;
    PathKey: string;
    WorkingDirectoryKey: string;
    ParametersKey: string;
  end;

  TCurrentSettings = record
    Path: string;
    WorkingDirectory: string;
    Parameters: string;
  end;

const
  Programs: array[ Low( TProgramType ).. High( TProgramType ) ] of TProgramSettings =
  (
    ( ProgramType: idBrowser;
      Name: 'Web Browser';
      PathKey: 'DefaultBrowserExe';
      WorkingDirectoryKey: 'DefaultWorkingDir';
      ParametersKey: 'DefaultParameters' ),
    ( ProgramType: idMail;
      Name: 'Email';
      PathKey: 'DefaultMailExe';
      WorkingDirectoryKey: 'DefaultMailWorkingDir';
      ParametersKey: 'DefaultMailParameters' ),
    ( ProgramType: idNews;
      Name: 'Newsgroups';
      PathKey: 'DefaultNewsExe';
      WorkingDirectoryKey: 'DefaultNewsWorkingDir';
      ParametersKey: 'DefaultNewsParameters' ),
    ( ProgramType: idFTP;
      Name: 'FTP';
      PathKey: 'DefaultFTPExe';
      WorkingDirectoryKey: 'DefaultFTPWorkingDir';
      ParametersKey: 'DefaultFTPParameters' ),
    ( ProgramType: idIRC;
      Name: 'IRC';
      PathKey: 'DefaultIRCExe';
      WorkingDirectoryKey: 'DefaultIRCWorkingDir';
      ParametersKey: 'DefaultIRCParameters' )
  );

var
  CurrentSettings: array[ Low( TProgramType ).. High( TProgramType ) ] of TCurrentSettings;;

Procedure SetProgramPath( P: TProgramSettings;
                          const V: string );
begin
  SetUserProfileString( 'WPURLDEFAULTSETTINGS',
                        P.PathKey,
                        V );
end;

Procedure SetWorkingDirectory( P: TProgramSettings;
                               const V: string );
begin
  SetUserProfileString( 'WPURLDEFAULTSETTINGS',
                         P.WorkingDirectoryKey,
                         V );
end;

Procedure SetParameters( P: TProgramSettings;
                         Const V: string );
begin
  SetUserProfileString( 'WPURLDEFAULTSETTINGS',
                        P.ParametersKey,
                        V );
end;

Function GetProgramPath( P: TProgramSettings ): string;
begin
  Result := GetUserProfileString( 'WPURLDEFAULTSETTINGS',
                                  P.PathKey,
                                  '' );
end;

Function GetWorkingDirectory( P: TProgramSettings ): string;
begin
  Result := GetUserProfileString( 'WPURLDEFAULTSETTINGS',
                                  P.WorkingDirectoryKey,
                                  '' );
end;

Function GetParameters( P: TProgramSettings ): string;
begin
  Result := GetUserProfileString( 'WPURLDEFAULTSETTINGS',
                                  P.ParametersKey,
                                  '' );
end;

Procedure TMainForm.ParametersEditOnChange (Sender: TObject);
Begin
  if not Displaying then
    Changed := true;
End;

Procedure TMainForm.RestoreButtonOnClick (Sender: TObject);
Begin
  LoadCurrentSettings;
End;

Procedure TMainForm.MainFormOnCloseQuery (Sender: TObject;
  Var CanClose: Boolean);
Begin
  if Changed then
    if not DoConfirmDlg( 'Discard changes?',
                         'Exit and discard changes?' ) then
      CanClose := false;

End;

Procedure TMainForm.WorkingDirectoryEditOnChange (Sender: TObject);
Begin
  if not Displaying then
    Changed := true;

End;

Procedure TMainForm.ApplyButtonOnClick (Sender: TObject);
var
  ProgramType: TProgramType;
  P: TProgramSettings;
  FoundPath: string; // dummy
Begin
  StoreEdits( SelectedType );
  // validate.
  for ProgramType := Low( TProgramType ) to High( TProgramType ) do
  begin
    p := Programs[ ProgramType ];

    with CurrentSettings[ ProgramType ] do
    begin
      if Trim( Path ) <> '' then
      begin
        if ExtractFilePath( Path ) <> '' then
        begin
          // they specified a path...
          if not FileExists( Path ) then
            if not DoConfirmDlg( p.Name,
                                 'File does not exist: ' + EndLine
                                 + Path + EndLine
                                 + 'Save anyway?' ) then
              exit;
        end
        else
        begin
          // no directory, search path
          if not SearchPath( 'PATH',
                             Path,
                             FoundPath ) then
            if not DoConfirmDlg( p.Name,
                                 'Program not found in path: ' + EndLine
                                 + Path + EndLine
                                 + 'Save anyway?' ) then
              exit;
        end;
        if not DirectoryExists( WorkingDirectory ) then
          if not DoConfirmDlg( p.Name,
                               'Directory does not exist: '
                               + WorkingDirectory
                               + '. Save anyway?' ) then
            exit;
      end;
    end;
  end;

  for ProgramType := Low( TProgramType ) to High( TProgramType ) do
  begin
    p := Programs[ ProgramType ];

    SetProgramPath( P, CurrentSettings[ ProgramType ].Path );
    SetWorkingDirectory( P, CurrentSettings[ ProgramType ].WorkingDirectory );
    SetParameters( p, CurrentSettings[ ProgramType ].Parameters );
  end;

  Changed := false;
End;

Procedure TMainForm.SelectDirectoryButtonOnClick (Sender: TObject);
Begin
  ChangeDirDialog.Directory := WorkingDirectoryEdit.Text;
  if not ChangeDirDialog.Execute then
    exit;
  WorkingDirectoryEdit.Text := ChangeDirDialog.Directory;
End;

Procedure TMainForm.BrowsePathButtonOnClick (Sender: TObject);
Begin
  OpenDialog.Filename := ExtractFilePath( PathEdit.Text ) + '*.exe' ;
  if not OpenDialog.Execute then
    exit;

  PathEdit.Text := OpenDialog.FileName;
End;

Procedure TMainForm.PathEditOnChange (Sender: TObject);
Begin
  if not Displaying then
  begin
    StoreEdits( SelectedType );
    Changed := true;
  end;
End;

Function TMainForm.SelectedType: TProgramType;
begin
  Result := TProgramType( ItemsListBox.Items.Objects[ ItemsListBox.ItemIndex ] );
end;

Procedure TMainForm.StoreEdits( P: TProgramType );
var
  i: longint;
begin
  CurrentSettings[ P ].Path := PathEdit.Text;
  CurrentSettings[ P ].WorkingDirectory := WorkingDirectoryEdit.Text;
  CurrentSettings[ P ].Parameters := ParametersEdit.Text;

  for i := 0 to ItemsListBox.Items.Count - 1 do
    if TProgramType( ItemsListBox.Items.Objects[ i ] ) = p then
      ItemsListBox.Items[ i ] := Programs[ p ].Name
                                 + #9
                                 + PathEdit.Text;
end;

Procedure TMainForm.ItemsListboxOnItemFocus (Sender: TObject; Index: LongInt);
Begin
  if FLastItemSet then
  begin
    StoreEdits( FLastItem );
  end;

  Displaying := true;
  PathEdit.Text := CurrentSettings[ SelectedType ].Path;
  WorkingDirectoryEdit.Text := CurrentSettings[ SelectedType ].WorkingDirectory;
  ParametersEdit.Text := CurrentSettings[ SelectedType ].Parameters;

  Displaying := false;
  FLastItem := SelectedType;
  FLastItemSet := true;
End;

Procedure TMainForm.MainFormOnCreate (Sender: TObject);
Begin
  Font := GetNiceDefaultFont;

  VersionLabel.Caption := AppVersion;
  LoadCurrentSettings;
end;

Procedure TMainForm.LoadCurrentSettings;
var
  ProgramType: TProgramType;
  P: TProgramSettings;
begin
  ItemsListBox.Items.Clear;
  for ProgramType := Low( TProgramType ) to High( TProgramType ) do
  begin
    p := Programs[ ProgramType ];
    CurrentSettings[ ProgramType ].Path := GetProgramPath( p );
    CurrentSettings[ ProgramType ].WorkingDirectory := GetWorkingDirectory( p );
    CurrentSettings[ ProgramType ].Parameters := GetParameters( p );

    ItemsListBox.Items.AddObject( P.Name
                                  + #9
                                  + CurrentSettings[ ProgramType ].Path,
                                  TObject( P.ProgramType ) );
  end;

  FLastItemSet := false;
  Displaying := false;
  Changed := false;
  ItemsListBox.ItemIndex := 0;
End;

Initialization
  RegisterClasses ([TMainForm, TEdit, TButton, TMultiColumnListBox, TLabel,
    TSystemOpenDialog, TChangeDirDialog]);
End.
