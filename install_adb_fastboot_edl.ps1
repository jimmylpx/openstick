<#
.SYNOPSIS
    Automated All-in-One Installer for ADB, Fastboot, and Qualcomm EDL Tool on Windows.
.DESCRIPTION
    Installs:
      - Google Android Platform Tools (ADB & Fastboot)
      - Python 3 & Git (via winget)
      - Qualcomm EDL Tool (bkerler/edl) + submodules & requirements
      - UsbDk / Zadig WinUSB Driver for Qualcomm HS-USB QDLoader 9008 (QHSUSB__BULK)
    Configures environment PATH so 'adb', 'fastboot', and 'edl' can be run globally from any terminal.
.NOTES
    OpenStick Project: https://github.com/jimmylpx/openstick
#>

# 1. Pastikan script berjalan sebagai Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Membutuhkan hak akses Administrator. Me-restart PowerShell sebagai Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "OpenStick - ADB, Fastboot & EDL Windows Installer"
Clear-Host

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    AUTO-INSTALLER ADB, FASTBOOT & QUALCOMM EDL TOOL UNTUK WINDOWS    " -ForegroundColor Green
Write-Host "            OpenStick Snapdragon 410 (MSM8916) Project               " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# Direktori Instalasi Tools
$ToolsDir = "C:\OpenStick_Tools"
$PlatformToolsDir = Join-Path $ToolsDir "platform-tools"
$EdlDir = Join-Path $ToolsDir "edl"
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

# -----------------------------------------------------------------------------
# TAHAP 1: INSTALASI DEPENDENSI DASAR (WINGET / GIT / PYTHON)
# -----------------------------------------------------------------------------
Write-Host ">>> [1/5] Memeriksa paket pendukung sistem (Winget / Python / Git)..." -ForegroundColor Yellow

$HasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if (-not $HasWinget) {
    Write-Host "    [!] Winget tidak ditemukan. Mengunduh installer manual jika diperlukan..." -ForegroundColor Yellow
}

# Cek Python
$HasPython = [bool](Get-Command python -ErrorAction SilentlyContinue)
if (-not $HasPython) {
    Write-Host "    [*] Memasang Python via Winget..." -ForegroundColor Cyan
    if ($HasWinget) {
        & winget install --id=Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent --scope machine
    } else {
        Write-Host "    [*] Mengunduh installer resmi Python 3.11..." -ForegroundColor Cyan
        $pyInstaller = "$env:TEMP\python_installer.exe"
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" -OutFile $pyInstaller
        Start-Process -FilePath $pyInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        Remove-Item -Force $pyInstaller -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "    [OK] Python sudah terpasang: $((Get-Command python).Source)" -ForegroundColor Green
}

# Cek Git
$HasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
if (-not $HasGit) {
    Write-Host "    [*] Memasang Git for Windows..." -ForegroundColor Cyan
    if ($HasWinget) {
        & winget install --id=Git.Git --accept-package-agreements --accept-source-agreements --silent --scope machine
    } else {
        $gitInstaller = "$env:TEMP\git_installer.exe"
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/Git-2.45.2-64-bit.exe" -OutFile $gitInstaller
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait
        Remove-Item -Force $gitInstaller -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "    [OK] Git sudah terpasang: $((Get-Command git).Source)" -ForegroundColor Green
}

# Update PATH session saat ini agar mengenali python & git yang baru dipasang
$env:Path = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine) + ";" + [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)

# -----------------------------------------------------------------------------
# TAHAP 2: INSTALASI ANDROID PLATFORM-TOOLS (ADB & FASTBOOT)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [2/5] Memasang Android Platform-Tools (ADB & Fastboot)..." -ForegroundColor Yellow

$AdbExe = Join-Path $PlatformToolsDir "adb.exe"
if (-not (Test-Path $AdbExe)) {
    $PlatformToolsZip = "$env:TEMP\platform-tools.zip"
    Write-Host "    [*] Mengunduh Google Platform-Tools resmi untuk Windows..." -ForegroundColor Cyan
    $AdbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $AdbUrl -OutFile $PlatformToolsZip
    
    Write-Host "    [*] Mengekstrak ke $ToolsDir..." -ForegroundColor Cyan
    Expand-Archive -Path $PlatformToolsZip -DestinationPath $ToolsDir -Force
    Remove-Item -Force $PlatformToolsZip -ErrorAction SilentlyContinue
}
Write-Host "    [OK] ADB & Fastboot siap di: $PlatformToolsDir" -ForegroundColor Green

# -----------------------------------------------------------------------------
# TAHAP 3: INSTALASI QUALCOMM EDL TOOL (BKERLER/EDL)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [3/5] Memasang Qualcomm EDL Tool (bkerler/edl)..." -ForegroundColor Yellow

$GitCmd = if (Get-Command git -ErrorAction SilentlyContinue) { (Get-Command git).Source } else { "${env:ProgramFiles}\Git\cmd\git.exe" }

if (-not (Test-Path "$EdlDir\.git")) {
    Write-Host "    [*] Mengkloning repository bkerler/edl beserta submodules..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force $EdlDir -ErrorAction SilentlyContinue
    & $GitCmd clone --recurse-submodules https://github.com/bkerler/edl.git $EdlDir
} else {
    Write-Host "    [*] Memperbarui repository bkerler/edl..." -ForegroundColor Cyan
    Push-Location $EdlDir
    & $GitCmd submodule update --init --recursive
    Pop-Location
}

Write-Host "    [*] Menginstal library Python pendukung EDL (pyusb, pyserial, capstone, pycryptodome, dll)..." -ForegroundColor Cyan
& python -m pip install --upgrade pip
& python -m pip install -r "$EdlDir\requirements.txt"
& python -m pip install libusb pyusb pyserial

# Buat batch wrapper di folder edl agar 'edl' dapat dipanggil langsung dari CMD / PowerShell
$EdlBat = Join-Path $EdlDir "edl.bat"
$BatWrapper = "@echo off`r`npython `"%~dp0edl.py`" %*`r`n"
[System.IO.File]::WriteAllText($EdlBat, $BatWrapper)
Write-Host "    [OK] Qualcomm EDL Tool siap di: $EdlDir" -ForegroundColor Green

# -----------------------------------------------------------------------------
# TAHAP 4: MENDAFTARKAN PATH SISTEM SECARA GLOBAL
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [4/5] Mengonfigurasi Environment Variable PATH Sistem..." -ForegroundColor Yellow

$MachinePath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$PathsToAdd = @($PlatformToolsDir, $EdlDir)
$Modified = $false

foreach ($p in $PathsToAdd) {
    if ($MachinePath -split ';' -notcontains $p) {
        $MachinePath = "$MachinePath;$p"
        $Modified = $true
        Write-Host "    [+] Menambahkan ke Machine PATH: $p" -ForegroundColor Green
    } else {
        Write-Host "    [OK] Sudah terdaftar di PATH: $p" -ForegroundColor Gray
    }
}

if ($Modified) {
    [Environment]::SetEnvironmentVariable("Path", $MachinePath, [System.EnvironmentVariableTarget]::Machine)
}

# Update PATH sesi sekarang
$env:Path = $MachinePath

# -----------------------------------------------------------------------------
# TAHAP 5: PANDUAN DRIVER QUALCOMM 9008 (USBDK & ZADIG)
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host ">>> [5/5] Penyiapan Driver Qualcomm EDL 9008 (WinUSB)..." -ForegroundColor Yellow

$ZadigExe = Join-Path $ToolsDir "zadig.exe"
if (-not (Test-Path $ZadigExe)) {
    Write-Host "    [*] Mengunduh Zadig (Driver WinUSB Installer)..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri "https://github.com/pbatard/libwdi/releases/download/v1.5.1/zadig-2.9.exe" -OutFile $ZadigExe
    } catch {
        Write-Host "    [!] Gagal mengunduh Zadig otomatis. Anda dapat mengunduh manual dari https://zadig.akeo.ie/" -ForegroundColor Yellow
    }
}

# Memasang UsbDk via winget jika tersedia
if ($HasWinget) {
    Write-Host "    [*] Memeriksa / Memasang RedHat UsbDk 64-bit..." -ForegroundColor Cyan
    & winget install --id=Daynix.UsbDk --accept-package-agreements --accept-source-agreements --silent
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "              INSTALASI TOOLS SELESAI DENGAN SUKSES!                  " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Perintah berikut sekarang dapat dijalankan dari terminal mana saja:"
Write-Host "  - adb       : $(Join-Path $PlatformToolsDir 'adb.exe')" -ForegroundColor Cyan
Write-Host "  - fastboot  : $(Join-Path $PlatformToolsDir 'fastboot.exe')" -ForegroundColor Cyan
Write-Host "  - edl       : $(Join-Path $EdlDir 'edl.bat')" -ForegroundColor Cyan
Write-Host ""
Write-Host "PENTING - DRIVER QUALCOMM 9008 DI WINDOWS:" -ForegroundColor Yellow
Write-Host "  1. Saat modem berada dalam mode EDL (QHSUSB_BULK / Qualcomm 9008),"
Write-Host "     Windows membutuhkan driver WinUSB agar tool 'edl' dapat membacanya."
Write-Host "  2. Jika 'edl' belum mendeteksi perangkat, jalankan Zadig:"
Write-Host "     Location: $ZadigExe" -ForegroundColor Cyan
Write-Host "     - Colokkan OpenStick dalam mode EDL (tahan tombol EDL saat dicolokkan)."
Write-Host "     - Buka Zadig -> Menu 'Options' -> Centang 'List All Devices'."
Write-Host "     - Pilih 'QHSUSB__BULK' atau 'Qualcomm HS-USB QDLoader 9008'."
Write-Host "     - Pada box driver target, pilih 'WinUSB (v6...)' -> Klik 'Replace Driver'."
Write-Host ""
Write-Host "Tekan tombol apa saja untuk menutup installer ini..." -ForegroundColor Gray
$null = $host.UI.RawUI.ReadKey()
