@echo off
chcp 936 >nul
setlocal
rem ============================================================
rem  划词翻译 —— 开启「登录时以管理员权限自启」
rem  双击运行即可，会弹一次 UAC 请点「是」
rem  关闭 / 状态 / 卸载请用同目录的 autostart-disable.bat
rem ============================================================
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Translation-AdminTask.ps1" -Enable
echo.
pause
