[Setup]
AppName=Fritzing
AppVersion={#MyAppVersion}
AppPublisher=Fritzing
AppURL=https://fritzing.org
DefaultDirName={autopf}\Fritzing
DefaultGroupName=Fritzing
OutputDir=.\
#if defined(OnlineInstaller) && OnlineInstaller == 1
OutputBaseFilename=Fritzing-{#MyAppVersion}-OnlineSetup-Windows-x64
#else
OutputBaseFilename=Fritzing-{#MyAppVersion}-OfflineSetup-Windows-x64
#endif
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\Fritzing.exe
ChangesAssociations=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "associatefzz"; Description: "Associate .fzz and .fzpz files with Fritzing"; GroupDescription: "File associations:"; Flags: unchecked

[Registry]
Root: HKCR; Subkey: ".fzz"; ValueType: string; ValueName: ""; ValueData: "FritzingProject"; Flags: uninsdeletevalue; Tasks: associatefzz
Root: HKCR; Subkey: ".fzpz"; ValueType: string; ValueName: ""; ValueData: "FritzingPart"; Flags: uninsdeletevalue; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingProject"; ValueType: string; ValueName: ""; ValueData: "Fritzing Sketch"; Flags: uninsdeletekey; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingProject\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Fritzing.exe,0"; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingProject\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Fritzing.exe"" ""%1"""; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingPart"; ValueType: string; ValueName: ""; ValueData: "Fritzing Component Part"; Flags: uninsdeletekey; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingPart\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Fritzing.exe,0"; Tasks: associatefzz
Root: HKCR; Subkey: "FritzingPart\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Fritzing.exe"" ""%1"""; Tasks: associatefzz

[Files]
; Base files (takes whatever is inside release64. For Online, it's missing fritzing-parts. For Offline, it contains fritzing-parts)
Source: "release64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Fritzing"; Filename: "{app}\Fritzing.exe"
Name: "{autodesktop}\Fritzing"; Filename: "{app}\Fritzing.exe"; Tasks: desktopicon

#if defined(OnlineInstaller) && OnlineInstaller == 1
[Code]
var
  DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if CurPageID = wpReady then begin
    DownloadPage.Clear;
    DownloadPage.Add('https://github.com/fritzing/fritzing-parts/archive/refs/heads/master.zip', 'fritzing-parts.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
      except
        if DownloadPage.AbortedByUser then
          Log('Aborted by user.')
        else
          MsgBox('Parts database download failed: ' + GetExceptionMessage, mbError, MB_OK);
        Result := False;
        exit;
      end;
    finally
      DownloadPage.Hide; // Hide the download page when done
    end;
  end;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Extracting Fritzing Parts database... (this may take a minute)';
    WizardForm.ProgressGauge.Style := npbstMarquee;
    
    // Use native Windows 10/11 tar to quickly extract the downloaded zip file into {app}
    if Exec(ExpandConstant('{cmd}'), '/c tar.exe -xf "' + ExpandConstant('{tmp}\fritzing-parts.zip') + '" -C "' + ExpandConstant('{app}') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      // GitHub zip names the extracted folder 'fritzing-parts-master', rename it to what Fritzing expects
      RenameFile(ExpandConstant('{app}\fritzing-parts-master'), ExpandConstant('{app}\fritzing-parts'));
    end else begin
      MsgBox('Failed to extract parts database. (tar exit code: ' + IntToStr(ResultCode) + ')', mbError, MB_OK);
    end;
    
    WizardForm.ProgressGauge.Style := npbstNormal;
  end;
end;
#endif
