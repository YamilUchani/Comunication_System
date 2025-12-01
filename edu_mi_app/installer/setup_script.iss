; Script de Inno Setup para crear instalador de edu_mi_app
; Este instalador maneja automáticamente:
; - Instalación del programa
; - Registro del protocolo stemforall://
; - Instalación de Visual C++ Redistributable
; - Creación de accesos directos
; - Desinstalación limpia

#define MyAppName "EduMi App"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Tu Nombre/Empresa"
#define MyAppURL "https://tuwebsite.com"
#define MyAppExeName "edu_mi_app.exe"

[Setup]
; Información básica de la aplicación
AppId={{TU-GUID-UNICO-AQUI}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Configuración de instalación
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=installer_output
OutputBaseFilename=EduMiApp_Setup_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; Privilegios de administrador (necesario para registrar protocolo)
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Arquitectura
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Archivos del programa principal
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

; Visual C++ Redistributable
; Descarga desde: https://aka.ms/vs/17/release/vc_redist.x64.exe
; Colócalo en la carpeta installer/dependencies/
Source: "dependencies\vc_redist.x64.exe"; DestDir: {tmp}; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Registry]
; Registrar el protocolo stemforall://
; HKEY_CLASSES_ROOT\stemforall
Root: HKCR; Subkey: "stemforall"; ValueType: string; ValueName: ""; ValueData: "URL:StemForAll Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey

; stemforall\shell\open\command
Root: HKCR; Subkey: "stemforall\shell"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall\shell\open"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

[Run]
; Instalar Visual C++ Redistributable si no está instalado
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Instalando Visual C++ Redistributable..."; Check: VCRedistNeedsInstall

; Ejecutar la aplicación al finalizar
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Función para verificar si Visual C++ Redistributable está instalado
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Verificar si está instalado Visual C++ 2015-2022 Redistributable (x64)
  if RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    // Ya está instalado
    Result := False;
  end
  else
  begin
    // Necesita instalación
    Result := True;
  end;
end;

// Mensaje personalizado durante la instalación
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('El protocolo stemforall:// ha sido registrado correctamente.' + #13#10 +
           'Ahora la aplicación puede manejar deep links desde el navegador.', 
           mbInformation, MB_OK);
  end;
end;
