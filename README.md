# 划词翻译（AutoHotkey v2）— 使用与自启说明

登录 Windows 后自动以**管理员权限**运行翻译脚本，全程**不弹 UAC**，
热键（默认 `Ctrl+Alt+T`）立即可用。本目录可整体搬到任意位置，脚本内部全部用相对路径。

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

计划任务名：`Translation AHK (Admin)`

---

## 一、开启自启（任选其一）

**方式 A：双击（最省事）**

双击 `autostart-enable.bat` → UAC 点「是」→ 看到绿色「已开启自启」即成功。

**方式 B：管理员 PowerShell / 终端**（Win+X → 终端(管理员)）

```powershell
powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Enable
```

任务配置：程序 `AutoHotkey64.exe`，参数 `"...\Translation.ahk"`，
起始位置＝本目录，触发＝**当前用户登录时**，运行级别＝**最高权限**，
登录类型＝Interactive（有桌面会话，能出弹窗），无执行时限、忽略新实例、失败重试 3 次。

---

## 二、关闭自启

**临时关闭（推荐，任务保留，随时可再开）**

- 双击 `autostart-disable.bat`，或
- `... -File .\Translation-AdminTask.ps1 -Disable`

效果：任务被**禁用**，下次登录不再启动；当前正在运行的进程不受影响
（要立刻退出就右键托盘图标 → Exit，或在任务管理器结束 `AutoHotkey64.exe`）。

**彻底删除**

```powershell
powershell -ExecutionPolicy Bypass -File .\Translation-AdminTask.ps1 -Uninstall
```

---

## 三、其它常用操作

```powershell
$ps = '.\Translation-AdminTask.ps1'

powershell -ExecutionPolicy Bypass -File $ps -Status    # 状态：任务/结果码/进程/实际启动命令
powershell -ExecutionPolicy Bypass -File $ps -Start     # 现在立刻用管理员权限启动一次
powershell -ExecutionPolicy Bypass -File $ps -Enable    # 开启或重建（改了路径后跑这个）
powershell -ExecutionPolicy Bypass -File $ps -Disable   # 关闭
powershell -ExecutionPolicy Bypass -File $ps -Uninstall # 删除任务
```

图形界面：`taskschd.msc` → 任务计划程序库 → `Translation AHK (Admin)`（可运行/结束/禁用/删除）。

日常改配置可直接右键托盘图标点击 **「编辑脚本」**，或右键 `Translation.ahk` → Edit with…
（AHK 会自动用 `A_ScriptFullPath` 定位自己，跟目录无关。）

### 配置与功能说明

- **API Key 配置**：复制 `.env.example` 为 `.env`，填入 `TRANSLATE_API_KEY=你的Key`（`.env` 已被 `.gitignore` 忽略，不会被提交到 Git；也可直接填在 `Translation.ahk` 的 `CFG.ApiKey` 中，留空则自动读取 `.env`）。日常更换 Key 直接修改 `.env` 后在托盘菜单点击 **「重新加载」** 即可。
- **源语言 / 目标语言**：弹窗底栏支持分别设置 **源语言** 与 **目标语言**，中间 `⇄` 可一键互换。
  - 源语言和目标语言默认均为 `"自动"`：原文以中文为主时自动译为地道英文，其他语言统一译为简体中文。
  - 若指定了相同语种（非 `"自动"`），会直接跳过请求。
- **省 token 优化**：
  - 精简英文 System Prompt + 关闭思考（`ReasoningEffort: ""`）+ 动态 `max_tokens` 上限。
  - 内置内存缓存（按 `源语言->目标语言 + 原文` 缓存最近 100 条），重复划词或切换已缓存语向时直接命中缓存（状态栏显示 `缓存 · ...`）；点击 **「重译」** 会强制重新请求。
  - 选中纯数字/标点等无文字内容时自动跳过请求。

---

## 四、怎么确认真的提权了

1. **最直接**：打开任务管理器或「管理员: CMD」，在那儿选中文字按 `Ctrl+Alt+T`。
   弹窗出现＝脚本是管理员权限（普通权限脚本无法对提权窗口取词/发按键）。
2. 看任务定义：`-Status` 输出里 `级别 Highest`、`登录类型 Interactive`。
3. 看进程：`-Status` 会打印运行中进程的完整命令行。

---

## 五、搬家 / 迁移

整个文件夹复制到新位置后：

1. 先 `-Uninstall`（若旧位置已建过任务，任务里记的是绝对路径）；
2. 在新位置双击 `autostart-enable.bat` 重建任务。

AHK 解释器按此顺序查找，命中第一个即用：

```
PATH 中的 AutoHotkey64.exe / AutoHotkey.exe
%SCOOP%\apps\autohotkey\current\v2\AutoHotkey64.exe
%USERPROFILE%\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe
%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe
%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe
```

都不存在时 `-Enable` 会直接报错提示安装 AHK v2。

---

## 六、常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 登录后没启动 | `-Status` 看 `状态` 是 `Disabled` 还是 `Ready`；`结果码 0x41301` 表示仍在运行（正常） |
| 弹窗起不来 | 触发必须是「登录时」且 `LogonType=Interactive`，不要用「计算机启动时」 |
| 每次开机弹 UAC | 说明用的是「启动」文件夹里的快捷方式，删掉它，改用本计划任务 |
| 换了 AHK 安装位置后失效 | 改 `Translation-AdminTask.ps1` 顶部 `$AhkExe` 候选列表，再 `-Enable` |
| 脚本报「请以管理员身份运行」 | 用 `.bat` 双击，或用管理员终端；普通 PowerShell 无法注册最高权限任务 |
| 双开 / 热键冲突 | 脚本含 `#SingleInstance Force`，新实例会顶掉旧实例，不会双弹窗 |
| 关掉自启但进程还在 | `-Disable` 只管下次登录；退出当前实例请点托盘 Exit |

---

## 七、为什么用计划任务而不是「启动」文件夹

- 「启动」文件夹 (`shell:startup`) 放需要提权的程序，**每次登录都弹 UAC**，除非把 UAC 关到最低（不建议）。
- 任务计划程序由系统代提权，**完全静默**，还能随时禁用/审计。
- 「计算机启动时」触发发生在无桌面会话阶段，GUI 与热键都用不了，
  所以正确组合是「**用户登录时**」+「**最高权限**」。
