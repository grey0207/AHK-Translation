@echo off
chcp 936 >nul
setlocal
rem ============================================================
rem  划词翻译 —— 关闭自启（保留计划任务，仅禁用，可随时再开）
rem  双击运行即可，会弹一次 UAC 请点「是」
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Translation-AdminTask.ps1" -Disable
echo.
pause
