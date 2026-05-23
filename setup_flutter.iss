[Setup]
AppId={{2A6F2FA9-82AD-4BB6-B69F-9D66B97E45BE}
AppName=考试练习系统
AppVersion=1.2.0
AppPublisher=BitaMatt
DefaultDirName={autopf}\ComprehensiveExamSystem
DefaultGroupName=考试练习系统
OutputDir=out
OutputBaseFilename=comprehensive-exam-system-windows-setup-v1.2.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\考试练习系统"; Filename: "{app}\comprehensive_exam_system.exe"
Name: "{autodesktop}\考试练习系统"; Filename: "{app}\comprehensive_exam_system.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\comprehensive_exam_system.exe"; Description: "{cm:LaunchProgram,考试练习系统}"; Flags: nowait postinstall skipifsilent
