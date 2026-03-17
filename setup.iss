[Setup]
AppName=綜合選擇題考試系統
AppVersion=1.0
DefaultDirName=C:\綜合選擇題考試系統
DefaultGroupName=綜合選擇題考試系統
OutputDir=installer_dist
OutputBaseFilename=綜合選擇題考試系統安装包
Compression=lzma
SolidCompression=yes

[Files]
Source: "dist\main.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "題庫\*"; DestDir: "{app}\題庫"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\綜合選擇題考試系統"; Filename: "{app}\main.exe"
Name: "{commondesktop}\綜合選擇題考試系統"; Filename: "{app}\main.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\main.exe"; Description: "{cm:LaunchProgram,綜合選擇題考試系統}"; Flags: nowait postinstall skipifsilent