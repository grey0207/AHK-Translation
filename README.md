# AHK-Translation · AI 划词翻译（AutoHotkey v2）

轻量、无外部依赖的 Windows 划词翻译工具，基于 **AutoHotkey v2** 编写，支持所有 OpenAI 兼容接口（Google Gemini、DeepSeek、OpenAI、Kimi、通义千问、本机 Ollama / LM Studio 等）。

- **随选随译**：任意程序内选中文字，按 `Ctrl+Alt+T` 弹窗展示译文，自动完整还原剪贴板。
- **双语种切换**：支持独立设置 **源语言** 与 **目标语言**，一键 `⇄` 互换；默认 `"自动"` 智能识别中文 / 日韩文 / 英文。
- **极致省 Token**：本地语种预判 + 精简英文指令 + 内存缓存（重复划词 0 请求）+ 动态 `max_tokens` 上限 + 无文字内容过滤。

---

## 目录结构

```
AHK-Translation/
├─ Translation.ahk   ← 翻译脚本本体（AHK v2）
├─ .env.example      ← API Key 配置模板（复制为 .env 使用）
├─ .gitignore        ← 忽略 .env 等本地私有文件
└─ README.md         ← 本文件
```

---

## 一、快速开始

### 1. 环境要求

- Windows 10 / 11
- [AutoHotkey v2.0+](https://www.autohotkey.com/)

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

## 二、开机自启（Windows 启动文件夹）

1. 按 `Win + R`，输入 `shell:startup` 回车打开 Windows 启动文件夹；
2. 右键 `Translation.ahk` → **创建快捷方式**，把快捷方式拖入该文件夹即可。

> 如需取消自启，直接删除启动文件夹里的快捷方式即可。

---

## 三、功能与配置说明

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
