@echo off
rem ---------------------------------------------------------------------------
rem Compile the pack's .hlsl files into the .fxc files the Direct3D 11 runtime
rem loads. Run this on Windows, from anywhere:
rem
rem     tools\compile_dx11.bat
rem
rem Direct3D 9 applications and the Fusion frame editor do not need this - they
rem read the .fx files directly. Only build .fxc if your application's display
rem mode is Direct3D 11.
rem
rem Needs fxc.exe, which ships with the Windows SDK (installed by any recent
rem Visual Studio) or the old DirectX SDK. If it is on your PATH this script
rem finds it; otherwise it looks through the usual Windows Kits folders.
rem ---------------------------------------------------------------------------
setlocal enabledelayedexpansion

set "PACK=%~dp0..\shaders\dist\CyberMushroom"
if not exist "%PACK%" (
    echo Could not find the built pack at "%PACK%".
    echo Run "python tools\build_shaders.py" first.
    exit /b 1
)

set "FXC="
for /f "delims=" %%F in ('where fxc.exe 2^>nul') do (
    if not defined FXC set "FXC=%%F"
)

if not defined FXC (
    for %%R in ("%ProgramFiles(x86)%\Windows Kits\10\bin" "%ProgramFiles%\Windows Kits\10\bin") do (
        for /f "delims=" %%F in ('dir /b /s /o-n "%%~R\fxc.exe" 2^>nul') do (
            if not defined FXC set "FXC=%%F"
        )
    )
)

if not defined FXC (
    echo fxc.exe not found.
    echo Install the Windows SDK, or add the folder holding fxc.exe to your PATH.
    exit /b 1
)

echo Using "%FXC%"
echo.

set /a BUILT=0
set /a FAILED=0

for /r "%PACK%" %%S in (*.hlsl) do (
    echo   %%~nxS

    "%FXC%" /nologo /T ps_4_0 /E ps_main /Fo "%%~dpnS.fxc" "%%S" >nul
    if errorlevel 1 (
        echo     FAILED: ps_main
        set /a FAILED+=1
    ) else (
        set /a BUILT+=1
    )

    rem The premultiplied build is what Fusion uses when the application has
    rem "Premultiplied alpha in effects" switched on. Building both costs
    rem nothing and means the pack works either way.
    "%FXC%" /nologo /T ps_4_0 /E ps_main_pm /Fo "%%~dpnS.premultiplied.fxc" "%%S" >nul
    if errorlevel 1 (
        echo     FAILED: ps_main_pm
        set /a FAILED+=1
    ) else (
        set /a BUILT+=1
    )
)

echo.
echo Compiled !BUILT! shader^(s^), !FAILED! failure^(s^).
if !FAILED! gtr 0 exit /b 1
exit /b 0
