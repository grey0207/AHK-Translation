# AHK-Translation · AI 划词翻译（AutoHotkey v2）

轻量、无外部依赖的 Windows 划词翻译工具，基于 **AutoHotkey v2** 编写，支持所有 OpenAI 兼容接口（Google Gemini、DeepSeek、OpenAI、Kimi、通义千问、本机 Ollama / LM Studio 等）。

- **随选随译**：任意程序内选中文字，按 `Ctrl+Alt+T` 弹窗展示译文，自动完整还原剪贴板。
- **双语种切换**：支持独立设置 **源语言** 与 **目标语言**，一键 `⇄` 互换；默认 `"自动"` 智能识别中文 / 日韩文 / 英文。
- **极致省 Token**：本地语种预判 + 精简英文指令 + 内存缓存（重复划词 0 请求）+ 动态 `max_tokens` 上限 + 无文字内容过滤。
- **静默提权自启**：可选通过 Windows 任务计划程序以管理员权限开机自启，全程无 UAC 弹窗，任务管理器/管理员终端内也能正常划词。

---

## 目录结构

```
AHK-Translation/
├─ Translation.ahk           ← 翻译脚本本体（AHK v2）
├─ .env.example              ← API Key 配置模板（复制为 .env 使用）
├─ .gitignore                ← 忽略 .env 等本地私有文件
├─ Translation-AdminTask.ps1 ← 自启管理脚本（开/关/启/查/删）
├─ autostart-enable.bat      ← 双击开启自启
├─ autostart-disable.bat     ← 双击关闭自启
└─ README.md                 ← 本文件
```

---

## 一、快速开始

### 1. 环境要求

- Windows 10 / 11
- [AutoHotkey v2.0+](https://www.autohotkey.com/)（支持 Scoop、官方安装包或绿色版）

### 2. 配置 API Key 与接口

1. 复制 `.env.example` 为 `.env`，填入你的 Key（`.env` 已被 `.gitignore` 忽略，不会被提交到 Git）：

   ```env
   TRANSLATE_API_KEY=你的APIKey
   ```

   > 本机 Ollama / LM Studio 不需要 Key，可跳过这一步；也可直接将 Key 填入 `Translation.ahk` 的 `CFG.ApiKey`（留空则自动读取 `.env`）。

2. 打开 `Translation.ahk` 顶部的 `CFG` 配置区，按需修改 `ApiUrl` 与 `Model`（脚本内附有 Gemini、OpenAI、Ollama 的现成示例）。

### 3. 运行与使用

- 双击 `Translation.ahk` 即可启动（托盘出现绿色 `H` 图标）。
- **划词翻译**：在任意窗口选中文字 → 按 `Ctrl+Alt+T`。
- **常用操作**：`Esc` 关闭弹窗 / 点击「复制译文」/ 切换源或目标语言后点「重译」/ 右键托盘图标可「编辑脚本」「重新加载」「退出」。

---

## 二、功能与配置说明

- **源语言 / 目标语言**：
  - 弹窗底栏支持分别设置 **源语言** 与 **目标语言**，中间 `⇄` 可一键互换。
  - 默认均为 `"自动"`：本地正则自动预判——含日文假名/韩文谚文或英文等非中文内容时译为简体中文，中文内容译为地道英文。
  - 若指定了相同的非 `"自动"` 语种，会直接跳过请求。
- **省 Token 机制**：
  - 精简英文 System Prompt + 关闭思考（`ReasoningEffort: ""`）+ 动态 `max_tokens` 上限。
  - 内置内存缓存（按 `源语言->目标语言 + 原文` 缓存最近 100 条），重复划词或切换已缓存语向时直接命中缓存（状态栏显示 `缓存 · ...`）；点击 **「重译」** 会强制重新请求。
  - 选中纯数字、标点等无文字内容时自动跳过请求。
- **热键与代理**：
  - 可在 `CFG` 中自定义 `Hotkey`（默认 `^!t`）、开启连按两次 `Ctrl+C` 触发（`DoubleCtrlC: true`）、设置 `Proxy`（例如 `"127.0.0.1:7890"`）或 `MaxInputChars`（默认 `4000`）。
  - 改完配置后右键托盘图标点击 **「重新加载」** 即可生效。

---

## 三、开机自启（管理员权限、无 UAC 弹窗）

本目录可整体移动到任意位置，自启脚本内部全部使用相对路径。计划任务名：`Translation AHK (Admin)`。

### 开启自启（任选其一）

- **方式 A（双击，最省事）**：双击 `autostart-enable.bat` → UAC 点「是」→ 看到绿色「已开启自启」即成功。
- **方式 B（管理员 PowerShell / 终端）**：

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Enable
  ```

任务配置：程序 `AutoHotkey64.exe`，参数 `"...\Translation.ahk"`，起始位置＝本目录，触发＝**当前用户登录时**，运行级别＝**最高权限**，登录类型＝`Interactive`（有桌面会话，能出弹窗），无执行时限、忽略新实例、失败重试 3 次。

### 关闭自启

- **临时关闭（推荐，保留任务，随时可再开）**：双击 `autostart-disable.bat`，或执行：
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Disable
  ```
  > 效果：下次登录不再自启，当前正在运行的进程不受影响（立即退出请右键托盘图标 → **「退出」**）。

- **彻底删除任务**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Uninstall
  ```

### 其它常用管理命令

```powershell
$ps = '.\Translation-AdminTask.ps1'

powershell -ExecutionPolicy Bypass -File $ps -Status    # 查看任务状态、结果码、进程与启动命令
powershell -ExecutionPolicy Bypass -File $ps -Start     # 立刻以管理员权限启动一次
powershell -ExecutionPolicy Bypass -File $ps -Enable    # 开启或重建任务（移动目录后跑这个）
powershell -ExecutionPolicy Bypass -File $ps -Disable   # 禁用任务
powershell -ExecutionPolicy Bypass -File $ps -Uninstall # 删除任务
```

图形界面管理：`taskschd.msc` → 任务计划程序库 → `Translation AHK (Admin)`。

### 怎么确认真的提权了

1. **最直接**：打开任务管理器或「管理员: CMD」，选中其中文字按 `Ctrl+Alt+T`；弹窗正常出现即说明已具备管理员权限（普通权限脚本无法对提权窗口取词或发按键）。
2. **看任务定义**：`-Status` 输出中 `级别 Highest`、`登录类型 Interactive`。

---

## 四、搬家 / 迁移

整个文件夹复制到新位置后：

1. 先执行 `-Uninstall` 删除旧路径任务；
2. 在新位置双击 `autostart-enable.bat` 重建任务。

AHK 解释器按以下顺序自动查找，命中第一个即用：

```
PATH 中的 AutoHotkey64.exe / AutoHotkey.exe
%SCOOP%\apps\autohotkey\current\v2\AutoHotkey64.exe
%USERPROFILE%\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe
%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe
%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe
```

---

## 五、常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 登录后没启动 | 运行 `-Status` 看状态是 `Disabled` 还是 `Ready`；`结果码 0x41301` 表示仍在运行（正常） |
| 弹窗起不来 | 触发必须是「登录时」且 `LogonType=Interactive`，不要用「计算机启动时」 |
| 每次开机弹 UAC | 说明用的是「启动」文件夹里的快捷方式，删掉它，改用本计划任务 |
| 换了 AHK 安装位置后失效 | 将 AHK v2 加入 `PATH`，或在 `Translation-AdminTask.ps1` 补充 `$AhkExe` 候选路径后再 `-Enable` |
| 脚本报「请以管理员身份运行」 | 用 `.bat` 双击，或用管理员终端；普通 PowerShell 无法注册最高权限任务 |
| 双开 / 热键冲突 | 脚本含 `#SingleInstance Force`，新实例会顶掉旧实例，不会双弹窗 |
| 关掉自启但进程还在 | `-Disable` 只管下次登录；退出当前实例请右键托盘图标 → **「退出」** |

---

## 六、为什么用计划任务而不是「启动」文件夹

- 「启动」文件夹（`shell:startup`）放需要提权的程序时，**每次登录都会弹 UAC**，除非把 UAC 关到最低（不建议）。
- 任务计划程序由系统代为提权，**完全静默**，还能随时禁用与审计。
- 「计算机启动时」触发发生在无桌面会话阶段，GUI 与热键都无法使用，因此正确组合是 **「用户登录时」+「最高权限」**。
