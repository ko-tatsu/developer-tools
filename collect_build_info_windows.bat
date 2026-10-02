@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Generic Windows Build / Development Environment Collector
REM
REM Usage:
REM   collect_build_info_windows.bat
REM   collect_build_info_windows.bat output-directory
REM
REM The current working directory is treated as the project root.
REM This script only reads information. It does not modify the
REM project, Git repository, Python environment, or Conda environment.
REM ============================================================

set "PROJECT_DIR=%CD%"

for %%I in ("%PROJECT_DIR%") do set "PROJECT_NAME=%%~nxI"

REM ----- Timestamp -----
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TIMESTAMP=%%I"

if "%~1"=="" (
    set "OUTPUT_DIR=%PROJECT_DIR%"
) else (
    set "OUTPUT_DIR=%~1"
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set "OUTPUT_FILE=%OUTPUT_DIR%\build_info_%PROJECT_NAME%_Windows_%TIMESTAMP%.md"

REM ----- Start report -----

> "%OUTPUT_FILE%" echo # Build / Development Environment Information
>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo ## Project
>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo - Project: `%PROJECT_NAME%`
>> "%OUTPUT_FILE%" echo - Project directory: `%PROJECT_DIR%`

for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'"') do set "COLLECTED=%%I"
>> "%OUTPUT_FILE%" echo - Collected: `%COLLECTED%`
>> "%OUTPUT_FILE%" echo.

REM ----- Operating system -----

>> "%OUTPUT_FILE%" echo ## Operating system
>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo ```text

powershell -NoProfile -Command ^
  "$os=Get-CimInstance Win32_OperatingSystem; " ^
  "'Caption: ' + $os.Caption; " ^
  "'Version: ' + $os.Version; " ^
  "'BuildNumber: ' + $os.BuildNumber; " ^
  "'Architecture: ' + $env:PROCESSOR_ARCHITECTURE" ^
  >> "%OUTPUT_FILE%" 2>nul

>> "%OUTPUT_FILE%" echo ```
>> "%OUTPUT_FILE%" echo.

REM ----- Hardware -----

>> "%OUTPUT_FILE%" echo ## Hardware
>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo ```text

powershell -NoProfile -Command ^
  "$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; $cpu.Name" ^
  > "%TEMP%\build_info_cpu.tmp"

set /p CPU_NAME=<"%TEMP%\build_info_cpu.tmp"
del "%TEMP%\build_info_cpu.tmp" >nul 2>&1

powershell -NoProfile -Command ^
  "$cs=Get-CimInstance Win32_ComputerSystem; " ^
  "'Manufacturer: ' + $cs.Manufacturer; " ^
  "'Model: ' + $cs.Model; " ^
  "'Logical processors: ' + $cs.NumberOfLogicalProcessors; " ^
  "'Memory: ' + [math]::Round($cs.TotalPhysicalMemory/1GB,2) + ' GB'" ^
  > "%TEMP%\build_info_hardware.tmp"

for /f "usebackq delims=" %%L in ("%TEMP%\build_info_hardware.tmp") do (
    >> "%OUTPUT_FILE%" echo %%L
)

del "%TEMP%\build_info_hardware.tmp" >nul 2>&1

>> "%OUTPUT_FILE%" echo Processor: !CPU_NAME!
>> "%OUTPUT_FILE%" echo ```
>> "%OUTPUT_FILE%" echo.

REM ----- Git -----

>> "%OUTPUT_FILE%" echo ## Git
>> "%OUTPUT_FILE%" echo.

where git >nul 2>&1
if errorlevel 1 (
    >> "%OUTPUT_FILE%" echo Git not found.
) else (
    git rev-parse --is-inside-work-tree >nul 2>&1
    if errorlevel 1 (
        >> "%OUTPUT_FILE%" echo Not inside a Git repository.
    ) else (
        for /f "delims=" %%I in ('git rev-parse --show-toplevel') do set "GIT_ROOT=%%I"
        for /f "delims=" %%I in ('git branch --show-current') do set "GIT_BRANCH=%%I"
        for /f "delims=" %%I in ('git rev-parse HEAD') do set "GIT_COMMIT=%%I"
        for /f "delims=" %%I in ('git rev-parse --short HEAD') do set "GIT_SHORT=%%I"
        for /f "delims=" %%I in ('git show -s --format^=%%cI HEAD') do set "GIT_DATE=%%I"

        set "GIT_TAG=None"
        for /f "delims=" %%I in ('git describe --tags --exact-match HEAD 2^>nul') do set "GIT_TAG=%%I"

        set "GIT_DESCRIBE="
        for /f "delims=" %%I in ('git describe --tags --always --dirty 2^>nul') do set "GIT_DESCRIBE=%%I"

        set "GIT_REMOTE="
        for /f "delims=" %%I in ('git remote get-url origin 2^>nul') do set "GIT_REMOTE=%%I"

        git status --porcelain > "%TEMP%\build_info_git_status.tmp"

        for %%I in ("%TEMP%\build_info_git_status.tmp") do set "STATUS_SIZE=%%~zI"

        if "!STATUS_SIZE!"=="0" (
            set "GIT_STATUS=Clean"
        ) else (
            set "GIT_STATUS=Modified / untracked files present"
        )

        del "%TEMP%\build_info_git_status.tmp" >nul 2>&1

        >> "%OUTPUT_FILE%" echo - Repository root: `!GIT_ROOT!`
        >> "%OUTPUT_FILE%" echo - Branch: `!GIT_BRANCH!`
        >> "%OUTPUT_FILE%" echo - Commit: `!GIT_COMMIT!`
        >> "%OUTPUT_FILE%" echo - Short commit: `!GIT_SHORT!`
        >> "%OUTPUT_FILE%" echo - Commit date: `!GIT_DATE!`
        >> "%OUTPUT_FILE%" echo - Exact tag: `!GIT_TAG!`

        if defined GIT_DESCRIBE (
            >> "%OUTPUT_FILE%" echo - Nearest Git description: `!GIT_DESCRIBE!`
        )

        >> "%OUTPUT_FILE%" echo - Working tree: `!GIT_STATUS!`

        if defined GIT_REMOTE (
            >> "%OUTPUT_FILE%" echo - Origin: `!GIT_REMOTE!`
        )
    )
)

>> "%OUTPUT_FILE%" echo.

REM ----- Python -----

>> "%OUTPUT_FILE%" echo ## Python
>> "%OUTPUT_FILE%" echo.

where python >nul 2>&1
if errorlevel 1 (
    >> "%OUTPUT_FILE%" echo Python not found.
) else (
    for /f "delims=" %%I in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%I"
    for /f "delims=" %%I in ('where python') do (
        if not defined PYTHON_EXE set "PYTHON_EXE=%%I"
    )

    >> "%OUTPUT_FILE%" echo - Version: `!PYTHON_VERSION!`
    >> "%OUTPUT_FILE%" echo - Executable: `!PYTHON_EXE!`
)

>> "%OUTPUT_FILE%" echo.

REM ----- Conda -----

>> "%OUTPUT_FILE%" echo ## Conda
>> "%OUTPUT_FILE%" echo.

where conda >nul 2>&1
if errorlevel 1 (
    >> "%OUTPUT_FILE%" echo Conda not found.
) else (
    set "CONDA_ENV=%CONDA_DEFAULT_ENV%"

    if not defined CONDA_ENV set "CONDA_ENV=None"

    for /f "delims=" %%I in ('where conda') do (
        if not defined CONDA_EXE set "CONDA_EXE=%%I"
    )

    for /f "delims=" %%I in ('conda --version 2^>^&1') do set "CONDA_VERSION=%%I"

    >> "%OUTPUT_FILE%" echo - Active environment: `!CONDA_ENV!`
    >> "%OUTPUT_FILE%" echo - Conda executable: `!CONDA_EXE!`
    >> "%OUTPUT_FILE%" echo - Conda version: `!CONDA_VERSION!`
)

>> "%OUTPUT_FILE%" echo.

REM ----- PyInstaller -----

>> "%OUTPUT_FILE%" echo ## PyInstaller
>> "%OUTPUT_FILE%" echo.

python -m PyInstaller --version >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%I in ('python -m PyInstaller --version 2^>^&1') do set "PYINSTALLER_VERSION=%%I"
    >> "%OUTPUT_FILE%" echo - Version: `!PYINSTALLER_VERSION!`
) else (
    >> "%OUTPUT_FILE%" echo PyInstaller not found in the active Python environment.
)

>> "%OUTPUT_FILE%" echo.

REM ----- Dependency / environment files -----

>> "%OUTPUT_FILE%" echo ## Environment / dependency files
>> "%OUTPUT_FILE%" echo.

set "FOUND_ENV_FILE=0"

for %%F in (
    requirements.txt
    requirements-build.txt
    environment.yml
    environment.yaml
    pyproject.toml
    setup.py
    setup.cfg
    Pipfile
    poetry.lock
    uv.lock
    Dockerfile
    docker-compose.yml
    compose.yml
) do (
    if exist "%%F" (
        >> "%OUTPUT_FILE%" echo - `%%F`
        set "FOUND_ENV_FILE=1"
    )
)

if "!FOUND_ENV_FILE!"=="0" (
    >> "%OUTPUT_FILE%" echo No common environment/dependency files detected.
)

>> "%OUTPUT_FILE%" echo.

REM ----- PyInstaller spec files -----

>> "%OUTPUT_FILE%" echo ## PyInstaller specification files
>> "%OUTPUT_FILE%" echo.

set "FOUND_SPEC=0"

for %%F in (*.spec) do (
    if exist "%%F" (
        >> "%OUTPUT_FILE%" echo - `%%F`
        set "FOUND_SPEC=1"
    )
)

if "!FOUND_SPEC!"=="0" (
    >> "%OUTPUT_FILE%" echo No PyInstaller .spec files detected.
)

>> "%OUTPUT_FILE%" echo.

REM ----- Release artifacts -----

>> "%OUTPUT_FILE%" echo ## Release artifacts
>> "%OUTPUT_FILE%" echo.

set "FOUND_ARTIFACT=0"

for %%D in (release dist) do (
    if exist "%%D\" (
        for %%F in ("%%D\*.zip" "%%D\*.7z") do (
            if exist "%%~fF" (
                set "FOUND_ARTIFACT=1"

                set "FILE_SHA="

                for /f "skip=1 tokens=* delims=" %%H in ('certutil -hashfile "%%~fF" SHA256 2^>nul') do (
                    if not defined FILE_SHA (
                        set "FILE_SHA=%%H"
                    )
                )

                for /f "delims=" %%S in ('powershell -NoProfile -Command "$x=Get-Item -LiteralPath '%%~fF'; [math]::Round($x.Length/1MB,2)"') do set "FILE_SIZE=%%S"

                >> "%OUTPUT_FILE%" echo ### `%%~nxF`
                >> "%OUTPUT_FILE%" echo.
                >> "%OUTPUT_FILE%" echo - Path: `%%~fF`
                >> "%OUTPUT_FILE%" echo - Size: `!FILE_SIZE! MB`
                >> "%OUTPUT_FILE%" echo - SHA-256: `!FILE_SHA!`
                >> "%OUTPUT_FILE%" echo.
            )
        )
    )
)

if "!FOUND_ARTIFACT!"=="0" (
    >> "%OUTPUT_FILE%" echo No common release archives detected in `release/` or `dist/`.
    >> "%OUTPUT_FILE%" echo.
)

REM ----- Collector -----

>> "%OUTPUT_FILE%" echo ## Collector
>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo - Script: `collect_build_info_windows.bat`
>> "%OUTPUT_FILE%" echo - This script only collected information and did not modify the development environment.
>> "%OUTPUT_FILE%" echo.

echo.
echo Build information collected successfully.
echo Project: %PROJECT_NAME%
echo Output: %OUTPUT_FILE%
echo.

endlocal