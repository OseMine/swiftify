; swiftify's windows installer: a per-user install, no administrator needed,
; with a start menu entry, an optional desktop shortcut and an uninstaller.
;
; tools/build-windows-installer.ps1 passes the paths and the version in:
;   /DAPP_VERSION=0.17.1 /DSOURCE_DIR=... /DOUT_FILE=... /DICON_FILE=...
;
; the folder it packages is the one tools/build-windows.ps1 installs into, so
; qt, its plugins and the c++ runtime are already beside the exe

Unicode true

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

!ifndef APP_VERSION
    !error "APP_VERSION is not set"
!endif
!ifndef SOURCE_DIR
    !error "SOURCE_DIR is not set"
!endif
!ifndef OUT_FILE
    !error "OUT_FILE is not set"
!endif
!ifndef ICON_FILE
    !error "ICON_FILE is not set"
!endif

!define APP_NAME "Swiftify"
!define APP_EXE "swiftify.exe"
!define APP_ID "dev.addenator.Swiftify.Qt"
!define APP_PUBLISHER "Swiftify"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUT_FILE}"
BrandingText "${APP_NAME} ${APP_VERSION}"

; a per-user install, so windows shows no administrator prompt and the
; uninstaller needs no elevation either
RequestExecutionLevel user
SetShellVarContext current

InstallDir "$LOCALAPPDATA\Programs\Swiftify"
InstallDirRegKey HKCU "Software\Swiftify" "InstallDir"

SetCompressor /SOLID lzma
SetCompressorDictSize 64

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "FileDescription" "${APP_NAME} installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "${APP_PUBLISHER}"

!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\bin\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Start ${APP_NAME}"
!define MUI_FINISHPAGE_LINK "Swiftify needs Spotify Premium and a Spotify app client id"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/shredos67/swiftify#before-you-start"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Swiftify" InstallSection
    ; the app is running from the folder being replaced: it has to go first,
    ; or its libraries are locked (the readme asks for this too)
    nsExec::Exec 'taskkill /IM "${APP_EXE}" /F'
    Pop $0

    SetOutPath "$INSTDIR"
    File /r "${SOURCE_DIR}\*.*"

    WriteUninstaller "$INSTDIR\uninstall.exe"

    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\bin\${APP_EXE}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe"

    WriteRegStr HKCU "Software\Swiftify" "InstallDir" "$INSTDIR"

    ; apps & features reads these
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${APP_PUBLISHER}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bin\${APP_EXE}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Desktop shortcut" DesktopShortcut
    CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\bin\${APP_EXE}"
SectionEnd

Section "Uninstall"
    nsExec::Exec 'taskkill /IM "${APP_EXE}" /F'
    Pop $0

    Delete "$DESKTOP\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
    RMDir "$SMPROGRAMS\${APP_NAME}"

    ; everything the installer put down, and only that: settings, the cached
    ; songs and the listening history stay where swiftify kept them
    RMDir /r "$INSTDIR"

    DeleteRegKey HKCU "${UNINSTALL_KEY}"
    DeleteRegKey HKCU "Software\Swiftify"
SectionEnd
