# 划词翻译 AHK 自启动管理（任务计划程序 · 最高权限 · 无 UAC 弹窗）
#
# 常用（管理员 PowerShell，在项目目录下执行）：
#   powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Enable     # 开启自启（已存在则重建）
#   powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Disable    # 关闭自启（保留任务，仅禁用）
#   powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Start      # 现在就用管理员权限启动一次
#   powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Status     # 查看状态
#   powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Uninstall  # 彻底删除任务
#
# 也可直接双击同目录下的 autostart-enable.bat / autostart-disable.bat（会弹一次 UAC）。
# 不带参数 = -Enable。详细说明见同目录 README.md

param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Start,
    [switch]$Status,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# ── 路径：全部相对本脚本所在目录，整个文件夹可随意搬动 ────────────────
$Root      = $PSScriptRoot
$AhkScript = Join-Path $Root 'Translation.ahk'
$TaskName  = 'Translation AHK (Admin)'
$User      = "$env:USERDOMAIN\$env:USERNAME"

# AHK v2 解释器：优先 PATH / Scoop 环境变量，其次常见默认安装路径
$AhkCmd = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$AhkExe = if ($AhkCmd) {
    $AhkCmd.Source
} else {
    @(
        $(if ($env:SCOOP) { "$env:SCOOP\apps\autohotkey\current\v2\AutoHotkey64.exe" }),
        "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
                ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw '请以管理员身份运行 PowerShell（或直接双击对应的 .bat）再执行本脚本。' }
}

function Get-MyTask { Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue }

# 默认动作
if (-not ($Enable -or $Disable -or $Start -or $Status -or $Uninstall)) { $Enable = $true }

# ───────────────────────── 状态 ─────────────────────────
if ($Status) {
    Write-Host "脚本目录 : $Root"
    Write-Host "脚本文件 : $AhkScript  $(if (Test-Path -LiteralPath $AhkScript) { '(存在)' } else { '(缺失!)' })"
    Write-Host "AHK 解释器: $(if ($AhkExe) { $AhkExe } else { '(未找到!)' })"
    $t = Get-MyTask
    if (-not $t) {
        Write-Host "计划任务 : 不存在（未开启自启）" -ForegroundColor Yellow
        Write-Host '开启自启：-Enable'
        return
    }
    $i = $t | Get-ScheduledTaskInfo
    Write-Host "计划任务 : $TaskName"
    Write-Host "  状态     : $($t.State)"          # Ready / Disabled / Running
    Write-Host "  上次运行 : $($i.LastRunTime)   结果码 $($i.LastTaskResult)"
    Write-Host "  下次运行 : $($i.NextRunTime)"
    Write-Host "  运行账户 : $($t.Principal.UserId)   级别 $($t.Principal.RunLevel)   登录类型 $($t.Principal.LogonType)"
    Write-Host "  启动命令 : $(($t.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }) -join ' | ')"
    $procs = Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
             Where-Object { $_.CommandLine -like '*Translation.ahk*' }
    if ($procs) {
        foreach ($p in $procs) {
            Write-Host "  运行中   : PID $($p.ProcessId)" -ForegroundColor Green
            Write-Host "             命令行 $($p.CommandLine)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host '  运行中   : 否（当前没有 Translation.ahk 进程）' -ForegroundColor Yellow
    }
    return
}

# ───────────────────────── 禁用 ─────────────────────────
if ($Disable) {
    Assert-Admin
    if (-not (Get-MyTask)) { Write-Host "任务「$TaskName」不存在，无需关闭。" -ForegroundColor Yellow; return }
    Disable-ScheduledTask -TaskName $TaskName | Out-Null
    Write-Host "已关闭自启（任务已禁用，登录后不再启动）：$TaskName" -ForegroundColor Green
    Write-Host '重新开启：-Enable ；彻底删除：-Uninstall'
    return
}

# ───────────────────────── 删除 ─────────────────────────
if ($Uninstall) {
    Assert-Admin
    if (-not (Get-MyTask)) { Write-Host "任务「$TaskName」不存在。" -ForegroundColor Yellow; return }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "已删除计划任务：$TaskName" -ForegroundColor Green
    return
}

# ───────────────────────── 立即启动 ─────────────────────────
if ($Start) {
    Assert-Admin
    if (-not (Get-MyTask)) { throw "任务「$TaskName」不存在，请先 -Enable。" }
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Milliseconds 800
    Write-Host '已以管理员权限启动一次。' -ForegroundColor Green
    return
}

# ───────────────────────── 开启 / 重建 ─────────────────────────
Assert-Admin
if (-not (Test-Path -LiteralPath $AhkScript)) { throw "找不到脚本：$AhkScript" }
if (-not $AhkExe) { throw '找不到 AutoHotkey v2 的 AutoHotkey64.exe（Scoop/Program Files 都没有）。请确认已安装 AHK v2。' }

$action    = New-ScheduledTaskAction -Execute $AhkExe -Argument "`"$AhkScript`"" -WorkingDirectory $Root
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $User
$settings  = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
# LogonType Interactive = 只在当前用户桌面会话中运行（才能出弹窗、注册热键）；RunLevel Highest = 管理员权限
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName `
    -Description '划词翻译 AHK 脚本（Ctrl+Alt+T），登录后以管理员权限静默启动' `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Enable-ScheduledTask -TaskName $TaskName | Out-Null

$old = Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
       Where-Object { $_.CommandLine -like '*Translation.ahk*' }
if ($old) { Write-Host "提示：已有 $($old.Count) 个 Translation.ahk 进程在运行（非提权）。立即切换请执行 -Start。" -ForegroundColor DarkYellow }

Write-Host "已开启自启：$TaskName" -ForegroundColor Green
Write-Host "  登录时运行：`"$AhkExe`" `"$AhkScript`"（管理员权限，无 UAC 弹窗）"
Write-Host '查看状态：-Status   临时关闭：-Disable   彻底删除：-Uninstall'
