@echo off
setlocal enabledelayedexpansion

REM Move to the script directory (handle spaces in path)
cd /d "%~dp0"

echo [1/6] Checking for nasm...
where nasm >nul 2>&1
if errorlevel 1 (
    echo Error: nasm not found. Install nasm and ensure it is in PATH.
    echo Hint: winget install nasm
    exit /b 1
)

echo [2/6] Assembling kernel.asm...
nasm -f bin kernel.asm -o kernel.bin
if errorlevel 1 (
    echo Error: Failed to assemble kernel.asm.
    exit /b 1
)

echo [3/6] Calculating sectors from kernel.bin size...
for /f %%S in ('powershell -NoProfile -Command "(Get-Item 'kernel.bin').Length"') do set KERNEL_SIZE=%%S
if not defined KERNEL_SIZE (
    echo Error: Failed to get kernel.bin size.
    exit /b 1
)
set /a KERNEL_SECTORS=(KERNEL_SIZE + 511) / 512
set /a KERNEL_BYTES_ALIGNED=KERNEL_SECTORS * 512
echo  - Size: %KERNEL_SIZE% bytes / Sectors: %KERNEL_SECTORS% / Padded: %KERNEL_BYTES_ALIGNED% bytes

echo [4/6] Padding kernel.bin to 512-byte boundary...
powershell -NoProfile -Command "$p='kernel.bin';$n=%KERNEL_BYTES_ALIGNED%;$fs=[IO.File]::OpenWrite($p);$fs.SetLength($n);$fs.Close()" >nul 2>&1
if errorlevel 1 (
    echo Error: Failed to pad kernel.bin.
    exit /b 1
)

echo Generating kernel_sectors.inc...
powershell -NoProfile -Command "$v=%KERNEL_SECTORS%; Set-Content -Path 'kernel_sectors.inc' -Value \"KERNEL_SECTORS equ $v\" -NoNewline" >nul 2>&1
if errorlevel 1 (
    echo Error: Failed to generate kernel_sectors.inc.
    exit /b 1
)

echo [5/6] Assembling boot.asm...
nasm -f bin boot.asm -o boot.bin
if errorlevel 1 (
    echo Error: Failed to assemble boot.asm.
    exit /b 1
)

echo [6/6] Creating os-image.img (boot.bin + kernel.bin)...
del /f /q os-image.img >nul 2>&1
copy /b boot.bin + kernel.bin os-image.img >nul
if errorlevel 1 (
    echo Error: Failed to create image.
    exit /b 1
)

echo Done: Created os-image.img.
echo  - KERNEL_SECTORS=%KERNEL_SECTORS%
echo  - Output: %CD%\os-image.img

endlocal
exit /b 0