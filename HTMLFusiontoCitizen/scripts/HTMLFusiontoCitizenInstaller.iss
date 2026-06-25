#ifndef SourceDir
  #error SourceDir must be provided via /DSourceDir=...
#endif

#ifndef OutputDir
  #error OutputDir must be provided via /DOutputDir=...
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define MyAppName "HTMLFusiontoCitizen"

[Setup]
AppId={{2E354453-4DFB-4EFD-9882-1939A2374B7C}
AppName={#MyAppName}
AppVersion={#AppVersion}
DefaultDirName={userappdata}\Autodesk\Autodesk Fusion 360\API\AddIns\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#MyAppName}-installer-v{#AppVersion}
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern
Uninstallable=no

[Files]
Source: "{#SourceDir}\manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\main.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\mainApplication.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Citizen.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Citizen.manifest"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\citizen_selector.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\machines.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\html\*"; DestDir: "{app}\html"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\posts\*"; DestDir: "{app}\posts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\template\*"; DestDir: "{app}\template"; Flags: ignoreversion recursesubdirs createallsubdirs

[Run]
Filename: "explorer.exe"; Parameters: "{app}"; Description: "Open installed add-in folder"; Flags: postinstall skipifsilent
