@echo off
REM ============================================================
REM  NEU Bank - Auto Backup Script
REM  Chay tu dong moi ngay luc 23:00 qua Windows Task Scheduler
REM  DOI cac bien sau cho dung voi may cua ban:
REM ============================================================

SET MYSQL_PATH=C:\Program Files\MySQL\MySQL Server 8.4\bin
SET DB_NAME=banking
SET DB_USER=root
SET DB_PASS=08122006anhthuDN@@$$
SET BACKUP_DIR=C:\backup\banking

REM Tao thu muc backup neu chua co
IF NOT EXIST "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Ten file backup theo ngay gio (vi du: banking_2025-05-14_23-00.sql)
FOR /F "tokens=1-3 delims=/ " %%a IN ('date /t') DO SET DATE=%%c-%%b-%%a
FOR /F "tokens=1-2 delims=: " %%a IN ('time /t') DO SET TIME=%%a-%%b
SET FILENAME=%BACKUP_DIR%\banking_%DATE%_%TIME%.sql

REM Chay backup
"%MYSQL_PATH%\mysqldump.exe" -u%DB_USER% -p%DB_PASS% --single-transaction --routines --triggers --events %DB_NAME% > "%FILENAME%"

REM Kiem tra ket qua
IF %ERRORLEVEL% EQU 0 (
    echo [%DATE% %TIME%] BACKUP THANH CONG: %FILENAME% >> "%BACKUP_DIR%\backup_log.txt"
    echo Backup thanh cong: %FILENAME%
) ELSE (
    echo [%DATE% %TIME%] BACKUP THAT BAI >> "%BACKUP_DIR%\backup_log.txt"
    echo LOI: Backup that bai!
)

REM Xoa backup cu hon 7 ngay de tiet kiem dung luong
forfiles /P "%BACKUP_DIR%" /S /M *.sql /D -7 /C "cmd /c del @path" 2>nul

echo Hoan tat.
