# AHK-Translation

基于 **AutoHotkey v2** 的 Windows AI 划词翻译脚本，支持所有 OpenAI 兼容接口（Gemini、DeepSeek、OpenAI、Ollama 等）。

## 一、快速开始

1. **环境要求**：Windows 10 / 11，安装 [AutoHotkey v2.0+](https://www.autohotkey.com/)。
2. **配置 Key**：复制 `.env.example` 为 `.env`，填入接口密钥（本机 Ollama 可跳过）：

   ```env
   TRANSLATE_API_KEY=你的APIKey
   ```

3. **配置接口**：打开 `Translation.ahk` 顶部的 `CFG` 配置区，按需修改 `ApiUrl`、`Model`、`Proxy` 或快捷键。
4. **运行**：双击 `Translation.ahk` 启动（托盘出现绿色 `H` 图标）；修改配置后右键托盘图标点 **「重新加载」** 生效。

## 二、使用方式

- **划词翻译**：选中文本后按 `Ctrl+Alt+T`（未选中文本时打开空白输入框）。
- **手动输入**：按 `Ctrl+Alt+Y` 打开空白输入框，输入文本后按 `Enter` 翻译。
- **弹窗操作**：
  - 原文框可直接修改，按 `Enter` 重译，`Shift+Enter` 换行；
  - 可切换源语言 / 目标语言或点击 `⇄` 互换，默认 `"自动"` 自动识别中/英/日/韩；
  - 纯代码标识符（驼峰、`user_id`、`user-id` 及多行列表）会自动拆词翻译；
  - 按 `Esc` 关闭窗口，点击 **「重译」** 跳过缓存重新请求。

## 三、开机自启

1. 按 `Win + R`，输入 `shell:startup` 回车打开启动文件夹；
2. 为 `Translation.ahk` 创建快捷方式并拖入该文件夹即可。
