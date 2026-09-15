; Inno Setup script — dong goi ban Windows Release thanh 1 file setup.exe
; duy nhat de gui khach (cai vao Program Files, tao shortcut Start Menu,
; co uninstaller). Chay qua Inno Setup Compiler (ISCC.exe) sau khi da co
; `flutter build windows --release` (xem .github/workflows/windows-build.yml).
;
; #define AppVersion truyen tu ngoai vao qua /DAppVersion=x.y.z (CI dung
; version trong pubspec.yaml) — mac dinh 1.0.0 khi build thu cuc bo.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "CSB Vocab"
#define AppPublisher "vn.canhsatbien"
#define AppExeName "csb_vocab_app.exe"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{5B6B1E2B-8C0B-4A6E-9A3B-3E9E8F6E7B9A}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=..\..\build\installer
OutputBaseFilename=csb-vocab-app-setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Tạo shortcut ngoài Desktop"; GroupDescription: "Shortcut bổ sung:"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Gỡ cài đặt {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Chạy {#AppName}"; Flags: nowait postinstall skipifsilent
