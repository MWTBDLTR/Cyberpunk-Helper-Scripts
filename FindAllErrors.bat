@echo off
setlocal enabledelayedexpansion
:: AUTHOR: https://github.com/DoctorPresto
:: FIXED & UPDATED BY ME: https://github.com/MWTBDLTR - MrChurch
:: I have only updated some sections that weren't working correctly and updated the exe version check for 2.02
:START
:: Check if we are in the Cyberpunk directory or if the Cyberpunk directory was dragged onto the script. Mostly stolen from Mana
if "%~1" == "" (
  pushd "%~dp0"
  set "CYBERPUNKDIR=!CD!"
  popd
) else (
  set "CYBERPUNKDIR=%~1"
)

:: Check for read-only
pushd %~dp0
if not %errorlevel%==0 (
    echo ERROR: The script folder is set to read-only.
    echo Please ensure write permissions are available and try again.
    popd
    pause
    exit /b
)
popd

::Wrong directory m8
if not exist "%CYBERPUNKDIR%\bin\x64\Cyberpunk2077.exe" (
  echo.
  echo This is NOT your Cyberpunk directory
  echo Place me in your Cyberpunk 2077 folder and try again
  echo or drag and drop it onto me from Windows Explorer
  echo.
  echo Deploying BetterThanBartmoss Sniffer Drones...
  FOR /L %%S IN (10, -1, 1) DO (
    set /p =%%S ...!carret!<nul
    ping -n 2 127.0.0.1 > nul 2>&1
  )
  goto :eof
)

echo Please select an option:
echo.
echo 1. Delete all current log files (so that you may populate new log files with new errors)
echo.
echo 2. Check for errors (use this option after your game crashes)
echo.

set /p userOption=Enter your choice: 
if "%userOption%"=="1" (
    echo.
    echo Deleting all log files...
    for /R "%~dp0" %%G in (*.log) do (
        del /F /Q "%%G"
    )
    echo.
    echo All log files deleted successfully.
    goto :eof
) else if "%userOption%"=="2" (
    echo.
    echo Deploying BetterThanBartmoss Protocols
) else (
    CLS
    goto START
)

:: Check if the _LOGS folder already exists in the directory, if not, then create it
if not exist "%CYBERPUNKDIR%\_LOGS" mkdir "%CYBERPUNKDIR%\_LOGS"

:: Set the output file path for the "FilteredLogs" file
set "output_file=%CYBERPUNKDIR%\_LOGS\FilteredLogs.txt"

:: If there's already a "FilteredLogs" file, clear the content so that all of the errors listed were recorded on this run
break > "%output_file%"

:: Set path to the game exe
set "exe_path=%CYBERPUNKDIR%\bin\x64\Cyberpunk2077.exe"

:: Get .exe version using wmic datafile command
for /f "tokens=2 delims==" %%a in ('wmic datafile where name^="!exe_path:\=\\!" get version /value') do (
    for /f "delims=" %%b in ("%%a") do set "version=%%b"
)      

:: If not the current game version
if not "!version!"=="3.0.75.25522" (
    echo.
    echo Please update the game before proceeding
    echo.
    FOR /L %%S IN (10, -1, 1) DO (
        set /p =%%S ...!carret!<nul
        ping -n 2 127.0.0.1 > nul 2>&1
    )
    goto :eof
)

:: Append version info to the output file
echo Cyberpunk2077 EXE Version: !version! > "%output_file%"

:: get CET Version from the log file 
set "cet_log=%CYBERPUNKDIR%\bin\x64\plugins\cyber_engine_tweaks\cyber_engine_tweaks.log"
set "cet_version="
set "cet_found="

if exist "%cet_log%" (
    for /f "tokens=9 delims= " %%a in ('findstr /I /C:"CET version " "%cet_log%"') do (
        set "cet_version=%%a"
        set "cet_found=1"
        :: Strip the 'v' from the beginning of the version string
        set "cet_version=!cet_version:v=!"
    )
)

:: if CET is not found, add CET to dll_not_found
if not defined cet_found (
    if defined dll_not_found (
        set "dll_not_found=!dll_not_found!, CET"
    ) else (
        set "dll_not_found=CET"
    )
)

:: Search for red4ext framework mod DLL files and check their versions
set "dll_files=RED4ext.dll ArchiveXL.dll TweakXL.dll Codeware.dll"

for %%D in (%dll_files%) do (
    set "dll_version="
    set "dll_found="
    for /R "%CYBERPUNKDIR%\red4ext" %%F in ("*%%D") do (
        for /f "delims=" %%a in ('powershell -Command "$versionInfo = Get-Command '%%F' | ForEach-Object { $_.FileVersionInfo.ProductVersion }; if ($versionInfo) { Write-Output $versionInfo }"') do (
            set "dll_version=%%a"
            set "dll_found=1"
        )
    )
    if not defined dll_found (
        if defined dll_not_found (
            set "dll_not_found=!dll_not_found!, %%~nD"
        ) else (
            set "dll_not_found=%%~nD"
        )
    ) else (
        echo %%~nD Version: !dll_version! >> "%output_file%"
    )
)

:: If any core mod dlls or CET is/are not found, display to the output file
if defined dll_not_found (
    echo The following framework mods are not installed: %dll_not_found% >> "%output_file%"
)

:: Print CET version if it was found
if defined cet_found (
    echo CET Version: !cet_version! >> "%output_file%"
)

:: Parse through all files ending with .log, excluding those with .number.log pattern
echo. >> "%output_file%" 
echo ======================================================== >> "%output_file%"
echo Directory Scanned: %cyberpunkdir% >> "%output_file%"
echo The following log files have errors: >> "%output_file%"
echo ======================================================== >> "%output_file%"

for /R "%CYBERPUNKDIR%" %%F in (*.log) do (
    set "filename=%%~nxF"
    setlocal enabledelayedexpansion
    set "exclude=false"

    :: Check if the file name contains two dots
    echo "!filename!" | findstr /R /C:".*\..*\.." >nul
    if !errorlevel! equ 0 (
        set "exclude=true"
    )

    :: Process non-excluded log files
    if "!exclude!"=="false" (
        :: Initialize error flag to false
        set "has_error=false"
        
        :: Check for any errors in the file. If found, set error flag to true
        for /F "delims=" %%L in ('findstr /I "exception error failed" "%%F" ^| findstr /V /I /C:"Failed to create record" ^| findstr /I "error" ^| findstr /V /I /C:"reason: Record already exists" ^| findstr /V /I /C:"[Info]"') do (
            set "has_error=true"
        )
        
        :: If error is found, print filepath and process the error lines
        if "!has_error!"=="true" (
            echo. >> "%output_file%"
            set "relative_path=%%~dpF"
            set "relative_path=!relative_path:%CYBERPUNKDIR%=!"
            echo !relative_path:~1!%%~nxF >> "%output_file%"
            echo. >> "%output_file%"

            for /F "delims=" %%L in ('findstr /I "exception error failed" "%%F" ^| findstr /V /I /C:"Failed to create record" ^| findstr /I "error" ^| findstr /V /I /C:"reason: Record already exists" ^| findstr /V /I /C:"[Info]"') do (
                echo     %%L >> "%output_file%"
                echo SnifferDrones deployed successfully, error data was found
            )
        )
    )
    endlocal
)

:: Open the LOGS folder in a new File Explorer window for easy navigation and uploading to Discord
start "" "%CYBERPUNKDIR%\_LOGS"
start "" "%CYBERPUNKDIR%\_LOGS\FilteredLogs.txt"

endlocal
