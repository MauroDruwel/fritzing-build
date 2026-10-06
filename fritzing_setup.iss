; Fritzing Installer Script for Inno Setup 6.1+
; Supports two modes via /dOnlineInstaller="1" or /dOnlineInstaller="0":
;   Online  – lightweight setup, downloads fritzing-parts during install
;   Offline – bundles fritzing-parts inside the setup executable

[Setup]
; NOTE: AppId uniquely identifies this application. Do not use the same AppId
; in installers for other applications.
AppId={{94D3371B-D83D-4171-BD52-8ED3D3957E99}
AppName=Fritzing
AppVersion={#MyAppVersion}
AppVerName=Fritzing {#MyAppVersion}
AppPublisher=Fritzing
AppPublisherURL=https://fritzing.org
AppSupportURL=https://forum.fritzing.org
DefaultDirName={autopf}\Fritzing
DefaultGroupName=Fritzing
LicenseFile=fritzing-app\LICENSE.GPL2
OutputDir=.\
#if defined(OnlineInstaller) && OnlineInstaller == "1"
OutputBaseFilename=Fritzing-{#MyAppVersion}-OnlineSetup-Windows-x64
#else
OutputBaseFilename=Fritzing-{#MyAppVersion}-OfflineSetup-Windows-x64
#endif
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\Fritzing.exe
ChangesAssociations=yes
WizardStyle=modern
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "associatefzz"; Description: "Associate .fzz and .fzpz files with Fritzing"; GroupDescription: "File associations:"; Flags: unchecked

[Registry]
Root: HKA; Subkey: "Software\Classes\.fzz"; ValueType: string; ValueName: ""; ValueData: "FritzingProject"; Flags: uninsdeletevalue; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\.fzpz"; ValueType: string; ValueName: ""; ValueData: "FritzingPart"; Flags: uninsdeletevalue; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingProject"; ValueType: string; ValueName: ""; ValueData: "Fritzing Sketch"; Flags: uninsdeletekey; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingProject\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Fritzing.exe,0"; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingProject\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Fritzing.exe"" ""%1"""; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingPart"; ValueType: string; ValueName: ""; ValueData: "Fritzing Component Part"; Flags: uninsdeletekey; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingPart\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Fritzing.exe,0"; Tasks: associatefzz
Root: HKA; Subkey: "Software\Classes\FritzingPart\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Fritzing.exe"" ""%1"""; Tasks: associatefzz

[Files]
; Bundle everything inside release64 (Online = no parts, Offline = with parts)
Source: "release64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
; Fritzing updates the parts repo and can rewrite parts.db at runtime, which a
; non-admin user can't do under Program Files. Files created inside inherit this ACL.
Name: "{app}\fritzing-parts"; Permissions: users-modify

[Icons]
Name: "{group}\Fritzing"; Filename: "{app}\Fritzing.exe"
Name: "{autodesktop}\Fritzing"; Filename: "{app}\Fritzing.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Fritzing.exe"; Description: "{cm:LaunchProgram,Fritzing}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up the fritzing-parts folder (extracted post-install by the online installer,
; so Inno Setup's uninstaller does not track those files automatically)
Type: filesandordirs; Name: "{app}\fritzing-parts"

; Online Installer: download and extract fritzing-parts during installation
#if defined(OnlineInstaller) && OnlineInstaller == "1"
#ifndef PartsDownloadUrl
#define PartsDownloadUrl "https://github.com/fritzing/fritzing-parts/archive/refs/heads/master.zip"
#endif

[Code]
var
  DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    SetupMessage(msgWizardPreparing),
    SetupMessage(msgPreparingDesc),
    nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then begin
    DownloadPage.Clear;
    DownloadPage.Add(
      '{#PartsDownloadUrl}',
      'fritzing-parts.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
      except
        if DownloadPage.AbortedByUser then
          Log('Download aborted by user.')
        else
          SuppressibleMsgBox(
            'Failed to download the parts database:' + #13#10 + GetExceptionMessage + #13#10#13#10 +
            'Fritzing will still install but may not function correctly without the parts library.',
            mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  ZipPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    ZipPath := ExpandConstant('{tmp}\fritzing-parts.zip');

    // Only attempt extraction if the download actually succeeded
    if not FileExists(ZipPath) then begin
      Log('fritzing-parts.zip not found in temp; skipping extraction.');
      exit;
    end;

    WizardForm.StatusLabel.Caption := 'Extracting Fritzing Parts database... (this may take a minute)';
    WizardForm.ProgressGauge.Style := npbstMarquee;

    // Use native Windows 10/11 tar.exe for fast extraction
    if Exec(
      ExpandConstant('{cmd}'),
      '/c tar.exe -xf "' + ZipPath + '" -C "' + ExpandConstant('{app}') + '"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      // GitHub's archive names the folder 'fritzing-parts-master'; rename to 'fritzing-parts'
      // Zips created manually will already extract to 'fritzing-parts'
      if DirExists(ExpandConstant('{app}\fritzing-parts-master')) then
      begin
        RenameFile(
          ExpandConstant('{app}\fritzing-parts-master'),
          ExpandConstant('{app}\fritzing-parts'));
      end;
      Log('fritzing-parts extracted successfully.');
    end else begin
      Log('tar.exe failed with exit code: ' + IntToStr(ResultCode));
      SuppressibleMsgBox(
        'Failed to extract the parts database (tar exit code: ' + IntToStr(ResultCode) + ').' + #13#10 +
        'You can manually download and extract it from:' + #13#10 +
        '{#PartsDownloadUrl}',
        mbError, MB_OK, IDOK);
    end;

    WizardForm.ProgressGauge.Style := npbstNormal;
  end;
end;
#endif
