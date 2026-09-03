@echo off
set "SCRIPT_DIR=%~dp0"
python "%SCRIPT_DIR%win_installer.py" %*
if errorlevel 1 (
    echo.
    echo [!] Terjadi kesalahan saat menjalankan installer.
    pause
)
