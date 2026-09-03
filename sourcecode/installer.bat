@echo off
REM ==============================================================================
REM OpenStick Snapdragon 410 (MSM8916) - Direct One-Click Master Installer (Windows)
REM GitHub: https://github.com/jimmylpx/openstick
REM ==============================================================================
setlocal EnableDelayedExpansion
title OpenStick Master Installer for Windows

set "GITHUB_REPO=jimmylpx/openstick"
set "RELEASE_TAG=v1"

REM Warna Konsol
color 0B

echo ======================================================================
echo       OPENSTICK SNAPDRAGON 410 DIRECT ONE-CLICK MASTER INSTALLER     
echo                            (WINDOWS EDITION)                         
echo ======================================================================
echo.

REM ------------------------------------------------------------------------------
REM 0. PENGECEKAN DEPENDENSI TOOL (FASTBOOT, EDL, PYTHON)
REM ------------------------------------------------------------------------------
set "MISSING=0"

where fastboot >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'fastboot' tidak ditemukan di PATH sistem!
    set "MISSING=1"
)

where edl >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'edl' tidak ditemukan di PATH sistem!
    set "MISSING=1"
)

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 'python' tidak ditemukan di PATH sistem!
    set "MISSING=1"
)

if "%MISSING%"=="1" (
    echo.
    echo ======================================================================
    echo [!] DEPENDENSI BELUM LENGKAP PADA SISTEM WINDOWS ANDA!
    echo ======================================================================
    echo Silakan jalankan script instalasi otomatis terlebih dahulu:
    echo   File: install_adb_fastboot_edl.ps1
    echo   Panduan: ADB_FASTBOOT_EDL_INSTALL_WINDOWS.md
    echo.
    echo Buka PowerShell sebagai Administrator dan jalankan:
    echo   powershell -ExecutionPolicy Bypass -File install_adb_fastboot_edl.ps1
    echo ======================================================================
    pause
    exit /b 1
)

REM Deteksi direktori kerja (Semua file diletakkan di folder installer.bat saat ini)
set "CURRENT_DIR=%~dp0"
if "%CURRENT_DIR:~-1%"=="\" set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"

set "ACTUAL_BASE=%CURRENT_DIR%"
set "EXTRACTED_DIR=%CURRENT_DIR%\extracted"
set "DOWNLOADS_DIR=%CURRENT_DIR%\downloads"

if not exist "%EXTRACTED_DIR%" mkdir "%EXTRACTED_DIR%"
if not exist "%DOWNLOADS_DIR%" mkdir "%DOWNLOADS_DIR%"

echo Folder Installer : %CURRENT_DIR%
echo Folder Base      : %ACTUAL_BASE%
echo Folder Extracted : %EXTRACTED_DIR%
echo ======================================================================
echo.

REM Pilihan Varian Debian
echo Pilih Varian Sistem Operasi Debian yang ingin Anda pasang:
echo   1) Debian 12 Bookworm (Standar)        [Rekomendasi - 4G Modem Aktif, RAM ~390MB]
echo   2) Debian 12 Bookworm (Modem-Disabled) [Rekomendasi Server/Homelab - RAM Sekitar ~466MB]
echo   3) Debian 13 Trixie (Standar)          [Eksperimental - 4G Modem Aktif]
echo   4) Debian 13 Trixie (Modem-Disabled)   [Eksperimental - RAM Sekitar ~466MB]
echo.

set /p CHOICE="Masukkan pilihan Anda (1/2/3/4, default: 1): "
if "%CHOICE%"=="" set "CHOICE=1"

if "%CHOICE%"=="2" (
    set "DISTRO_NAME=bookworm-modem-disabled"
    set "DISTRO_TITLE=Debian 12 Bookworm (Modem-Disabled - RAM ~466MB)"
) else if "%CHOICE%"=="3" (
    set "DISTRO_NAME=trixie"
    set "DISTRO_TITLE=Debian 13 Trixie (Standar Eksperimental)"
) else if "%CHOICE%"=="4" (
    set "DISTRO_NAME=trixie-modem-disabled"
    set "DISTRO_TITLE=Debian 13 Trixie (Modem-Disabled - RAM ~466MB)"
) else (
    set "DISTRO_NAME=bookworm"
    set "DISTRO_TITLE=Debian 12 Bookworm (Standar Stabil)"
)

set "DISTRO_DIR=%CURRENT_DIR%\%DISTRO_NAME%"
set "DISTRO_ZIP=%DISTRO_NAME%.zip"
set "DISTRO_URL=https://github.com/%GITHUB_REPO%/releases/download/%RELEASE_TAG%/%DISTRO_ZIP%"
if not exist "%DISTRO_DIR%" mkdir "%DISTRO_DIR%"

echo.
echo [+] Varian terpilih: %DISTRO_TITLE%
echo ======================================================================
echo.

REM ==============================================================================
REM [TAHAP 1/4] DETEKSI STATUS MODEM & MANAJEMEN BACKUP
REM ==============================================================================
echo ^>^>^> [TAHAP 1/4] Memeriksa status koneksi perangkat (EDL 9008 / Fastboot)...

set "FASTBOOT_READY_WITH_BACKUP=0"
set "HAS_ALL_EXTRACTED=1"

for %%P in (fsc fsg modem modemst1 modemst2 persist sec) do (
    if not exist "%EXTRACTED_DIR%\%%P.bin" set "HAS_ALL_EXTRACTED=0"
)

REM Cek apakah perangkat sudah di Fastboot
fastboot devices 2>nul | findstr /R "[a-zA-Z0-9].*fastboot" >nul
if not errorlevel 1 (
    if "%HAS_ALL_EXTRACTED%"=="1" (
        echo [OK] Perangkat terdeteksi di mode Fastboot dan partisi backup asli sudah lengkap!
        set "FASTBOOT_READY_WITH_BACKUP=1"
    )
)

if "%FASTBOOT_READY_WITH_BACKUP%"=="1" goto STAGE_2

echo.
echo Menunggu modem dalam mode EDL (Qualcomm 9008)...
echo Tips: Tahan tombol EDL saat mencolokkan stik USB ke PC Windows.

:WAIT_EDL
edl printgpt >nul 2>&1
if errorlevel 1 (
    <nul set /p=.
    timeout /t 2 /nobreak >nul
    goto WAIT_EDL
)
echo.
echo [OK] Port EDL Qualcomm 9008 terdeteksi dan merespons!

REM Cek backup lama di folder installer saat ini
set "SKIP_BACKUP=0"
set "EXISTING_BACKUP="
for /f "delims=" %%F in ('dir /b /o-d "%CURRENT_DIR%\backup*.bin" 2^>nul') do (
    set "EXISTING_BACKUP=%CURRENT_DIR%\%%F"
    goto FOUND_BACKUP
)
:FOUND_BACKUP
if defined EXISTING_BACKUP (
    echo.
    echo [!] Ditemukan file backup sebelumnya: %EXISTING_BACKUP%
    set /p USE_EXISTING="Apakah file ini adalah backup dari perangkat saat ini? (y/n, default: y): "
    if "!USE_EXISTING!"=="" set "USE_EXISTING=y"
    if /i "!USE_EXISTING!"=="y" (
        echo [OK] Menggunakan file backup yang ada. Proses dump EDL dilewati...
        set "FULL_BACKUP_PATH=!EXISTING_BACKUP!"
        set "SKIP_BACKUP=1"
    )
)

if "!SKIP_BACKUP!"=="0" (
    for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "DT=%%I"
    set "TIMESTAMP=!DT:~0,4!_!DT:~4,2!_!DT:~6,2!_!DT:~8,2!_!DT:~10,2!"
    set "BACKUP_NAME=backup_!TIMESTAMP!.bin"
    set "FULL_BACKUP_PATH=%CURRENT_DIR%\!BACKUP_NAME!"
    
    echo [*] Melakukan FULL RAW DUMP seluruh eMMC flash via edl -^> !BACKUP_NAME!...
    edl rf "!FULL_BACKUP_PATH!"
)

REM Ekstraksi Partisi Asli dari File Backup via Python
if exist "!FULL_BACKUP_PATH!" (
    echo [*] Mengekstrak partisi baseband asli dari !FULL_BACKUP_PATH!...
    python -c "import struct, os, sys; bin_f=sys.argv[1]; out_d=sys.argv[2]; req=['fsc','fsg','modem','modemst1','modemst2','persist','sec']; f=open(bin_f,'rb'); f.seek(512); hdr=f.read(92); part_lba, num_entries, entry_sz = struct.unpack('<QII', hdr[72:88]); f.seek(part_lba*512); [open(os.path.join(out_d,f'{name}.bin'),'wb').write((f.seek(start*512) or True) and f.read((end-start+1)*512)) for e in [f.read(entry_sz) for _ in range(num_entries)] if len(e)>=128 and e[:16]!=b'\x00'*16 for start,end in [struct.unpack('<QQ', e[32:48])] for name in [e[56:128].decode('utf-16le',errors='ignore').rstrip('\x00').lower()] if name in req]; print('[OK] Partisi asli berhasil diekstrak!')" "!FULL_BACKUP_PATH!" "%EXTRACTED_DIR%"
) else (
    echo [*] Mencadangkan partisi individual via edl...
    for %%P in (fsc fsg modem modemst1 modemst2 persist sec) do (
        echo     -^> Dumping %%P...
        edl r %%P "%EXTRACTED_DIR%\%%P.bin"
    )
)

echo [*] Menyiapkan Fastboot direct jump via EDL...
echo     -^> Menulis bootloader aboot...
edl w aboot "%ACTUAL_BASE%\aboot.bin"
echo     -^> Mengosongkan partisi boot (force Fastboot mode)...
edl e boot
echo     -^> Mengirim edl reset (langsung melompat ke Fastboot)...
edl reset >nul 2>&1
echo [OK] Reset terkirim, beralih langsung ke Fastboot mode...
timeout /t 3 /nobreak >nul

:STAGE_2
REM ==============================================================================
REM [TAHAP 2/4] VERIFIKASI FASTBOOT & FLASH BASE GENERIC
REM ==============================================================================
echo.
echo ^>^>^> [TAHAP 2/4] Menunggu perangkat online di Fastboot mode...
:WAIT_FASTBOOT
fastboot devices 2>nul | findstr /R "[a-zA-Z0-9].*fastboot" >nul
if errorlevel 1 (
    <nul set /p=.
    timeout /t 1 /nobreak >nul
    goto WAIT_FASTBOOT
)
echo.
echo [OK] Perangkat terdeteksi di Fastboot:
fastboot devices
echo.

echo ^>^>^> Flashing Base Generic Partitions...
if exist "%ACTUAL_BASE%\gpt_both0.bin" (
    fastboot flash partition "%ACTUAL_BASE%\gpt_both0.bin"
    fastboot flash hyp "%ACTUAL_BASE%\hyp.mbn"
    fastboot flash rpm "%ACTUAL_BASE%\rpm.mbn"
    fastboot flash sbl1 "%ACTUAL_BASE%\sbl1.mbn"
    fastboot flash tz "%ACTUAL_BASE%\tz.mbn"
    if exist "%ACTUAL_BASE%\sbc_1.0_8016.bin" fastboot flash cdt "%ACTUAL_BASE%\sbc_1.0_8016.bin"
    fastboot erase boot >nul 2>&1
    fastboot erase rootfs >nul 2>&1
)
echo [OK] Tahap Base generic selesai!

REM ==============================================================================
REM [TAHAP 3/4] DOWNLOAD & FLASH DEBIAN FIRMWARE (BOOKWORM / TRIXIE)
REM ==============================================================================
echo.
echo ^>^>^> [TAHAP 3/4] Menyiapkan ^& Flashing %DISTRO_TITLE%...

if not exist "%DISTRO_DIR%\rootfs.bin" (
    set "LOCAL_ZIP=%DOWNLOADS_DIR%\%DISTRO_ZIP%"
    if not exist "!LOCAL_ZIP!" if exist "%CURRENT_DIR%\%DISTRO_ZIP%" set "LOCAL_ZIP=%CURRENT_DIR%\%DISTRO_ZIP%"

    if not exist "!LOCAL_ZIP!" (
        echo [*] Mengunduh %DISTRO_ZIP% dari GitHub Releases...
        echo     URL: %DISTRO_URL%
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%DISTRO_URL%', '%DOWNLOADS_DIR%\%DISTRO_ZIP%')"
        set "LOCAL_ZIP=%DOWNLOADS_DIR%\%DISTRO_ZIP%"
    )

    echo [*] Mengekstrak !LOCAL_ZIP! ke %DISTRO_DIR%...
    powershell -Command "Expand-Archive -Path '!LOCAL_ZIP!' -DestinationPath '%DISTRO_DIR%' -Force"
)

echo [*] Flashing firmware %DISTRO_TITLE%...
fastboot flash partition "%DISTRO_DIR%\gpt_both0.bin"
fastboot flash aboot "%DISTRO_DIR%\aboot.mbn"
fastboot flash hyp "%DISTRO_DIR%\hyp.mbn"
fastboot flash rpm "%DISTRO_DIR%\rpm.mbn"
fastboot flash sbl1 "%DISTRO_DIR%\sbl1.mbn"
fastboot flash tz "%DISTRO_DIR%\tz.mbn"
fastboot flash boot "%DISTRO_DIR%\boot.bin"
fastboot -S 200M flash rootfs "%DISTRO_DIR%\rootfs.bin"

echo [OK] Firmware %DISTRO_TITLE% berhasil di-flash!

REM ==============================================================================
REM [TAHAP 4/4] RESTORE ORIGINAL BASEBAND PARTITIONS & REBOOT
REM ==============================================================================
echo.
echo ^>^>^> [TAHAP 4/4] Mengembalikan partisi asli dari folder extracted\...
for %%P in (fsc fsg modem modemst1 modemst2 persist sec) do (
    if exist "%EXTRACTED_DIR%\%%P.bin" (
        echo     -^> Flashing %%P (%EXTRACTED_DIR%\%%P.bin)...
        fastboot flash %%P "%EXTRACTED_DIR%\%%P.bin"
    ) else (
        echo     [!] File %EXTRACTED_DIR%\%%P.bin tidak ditemukan, melewati partisi %%P.
    )
)

echo.
echo ======================================================================
echo    PROSES FLASHING SELESAI! ME-REBOOT PERANGKAT KE LINUX...           
echo ======================================================================
echo [*] Memulai boot ke sistem Linux (Direct Jump / Fastboot Continue)...
fastboot continue >nul 2>&1 || fastboot reboot

echo.
echo [OK] Perangkat sedang booting ke sistem %DISTRO_TITLE%.
echo.
echo ======================================================================
echo PENTING (POWER CYCLE USB):
echo   Jika dalam waktu 1 menit perangkat belum menyala (LED mati/belum terdeteksi),
echo   silakan CABUT dan COLOK KEMBALI stik USB Anda ke port PC!
echo ======================================================================
echo.
echo Setelah booting selesai (~40 detik):
echo   - Wi-Fi Hotspot : SSID '4G-UFI-XX' (Password: 1234567890)
echo   - Koneksi USB   : RNDIS Network Adapter aktif otomatis
echo   - Login SSH     : ssh user@192.168.100.1 (Password: 1)
echo   - Akses ADB     : adb connect 192.168.100.1:5555 ^&^& adb shell
echo.
echo Setelah login, ketik 'sbrmenu' untuk mengelola Hotspot, Wi-Fi, dan USB Mode.
echo Untuk akses administrator: ketik 'sudo su' (Password: 1)
echo ======================================================================
echo.
pause
