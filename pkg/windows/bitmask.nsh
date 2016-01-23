# pwd is a ro-mounted source-tree that had all dependencies build into
# package-name directories
!define PKGNAMEPATH ..\..\build\executables\${PKGNAME}
!include .\bitmask_client_product.nsh
!include ${PKGNAMEPATH}_install_files_size.nsh

RequestExecutionLevel admin ;Require admin rights on NT6+ (When UAC is turned on)

InstallDir "$PROGRAMFILES\${APPNAME}"

LicenseData "..\..\LICENSE"
Name "${COMPANYNAME} - ${APPNAME}"
Icon "..\..\build\executables\mask-icon.ico"

# /var/dist is a rw mounted volume
outFile "/var/dist/${PKGNAME}-${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}.exe"

!include LogicLib.nsh

# Just three pages - license agreement, install location, and installation
page license
page directory
Page instfiles

!macro VerifyUserIsAdmin
UserInfo::GetAccountType
pop $0
${If} $0 != "admin" ;Require admin rights on NT4+
        messageBox mb_iconstop "Administrator rights required!"
        setErrorLevel 740 ;ERROR_ELEVATION_REQUIRED
        quit
${EndIf}
!macroend

function .onInit
    setShellVarContext all
    !insertmacro VerifyUserIsAdmin
functionEnd

section "install"
    setOutPath $INSTDIR

    !include ${PKGNAMEPATH}_install_files.nsh

    # Uninstaller - See function un.onInit and section "uninstall" for configuration
    writeUninstaller "$INSTDIR\uninstall.exe"

    # Start Menu
    createDirectory "$SMPROGRAMS\${COMPANYNAME}"
    createShortCut "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk" "$INSTDIR\bitmask.exe" "" "$INSTDIR\bitmask.exe"

    !include bitmask_client_registry_install.nsh
sectionEnd

# Uninstaller

function un.onInit
    SetShellVarContext all
    !insertmacro VerifyUserIsAdmin
functionEnd

section "uninstall"

    delete "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk"
    # Try to remove the Start Menu folder - this will only happen if it is empty
    rmDir "$SMPROGRAMS\${COMPANYNAME}"

    # Remove files
    !include ${PKGNAMEPATH}_uninstall_files.nsh

    # Always delete uninstaller as the last action
    delete $INSTDIR\uninstall.exe

    # Try to remove the install directory - this will only happen if it is empty
    rmDir $INSTDIR

    # Remove uninstaller information from the registry
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}"
sectionEnd