@echo off
setlocal
cd /d "%~dp0"

echo === FunPayCardinal One-Click PaaS (Windows) ===
echo.
echo Запускаю установщик...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0paas-one-click.ps1"
if errorlevel 1 (
  echo.
  echo Произошла ошибка. Проверьте сообщение выше.
  pause
  exit /b 1
)

echo.
echo Готово.
pause
