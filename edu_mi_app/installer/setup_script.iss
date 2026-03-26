; Script de Inno Setup para crear instalador de edu_mi_app
; Este instalador maneja automáticamente:
; - Instalación del programa principal y dependencias
; - Inclusión de todos los simuladores de Unity (carpeta simuladores)
; - Registro del protocolo stemforall:// para deep linking
; - Instalación de Visual C++ Redistributable
; - Creación de accesos directos
; - Desinstalación limpia

#define MyAppName "EduMi App"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Tu Empresa/Institución"
#define MyAppURL "https://tuwebsite.com"
#define MyAppExeName "edu_mi_app.exe"

[Setup]
; Información básica de la aplicación (¡Asegúrate de generar un AppId nuevo desde Tools -> Generate GUID!)
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

; NOTA: Si no tienes el archivo LICENSE en la raíz, deshabilita o comenta esta línea:
; LicenseFile=..\LICENSE

OutputDir=installer_output
OutputBaseFilename=EduMiApp_Installer_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

; Privilegios de administrador (necesario para registrar el protocolo en HKCR)
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Forzar a 64 bits (necesario para las librerías de Agora y Flutter engine de x64)
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Archivo del programa principal (.exe)
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Librerías DLL (Engine de flutter, librerías de Agora SDK, pdfium, etc)
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Datos compilados de la interfaz (assets, shaders, etc)
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

; SIMULADORES DE UNITY (toda la carpeta de juegos y assets 3D que pasamos)
Source: "..\build\windows\x64\runner\Release\simuladores\*"; DestDir: "{app}\simuladores"; Flags: ignoreversion recursesubdirs

; Visual C++ Redistributable
; DEBES DESCARGARLO: https://aka.ms/vs/17/release/vc_redist.x64.exe
; y colocarlo en una carpeta llamada "dependencies" al lado de este script .iss
Source: "dependencies\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Registrar el protocolo stemforall:// globalmente
Root: HKCR; Subkey: "stemforall"; ValueType: string; ValueName: ""; ValueData: "URL:StemForAll Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey

; stemforall\shell\open\command
Root: HKCR; Subkey: "stemforall\shell"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall\shell\open"; Flags: uninsdeletekey
Root: HKCR; Subkey: "stemforall\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

[Run]
; Instalar Visual C++ Redistributable silenciosamente si falta (necesario para plugins y Flutter)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Instalando Visual C++ Redistributable..."; Check: VCRedistNeedsInstall

; Ejecutar la aplicación al finalizar el setup
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Función para verificar si Visual C++ Redistributable (x64) está instalado
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
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
