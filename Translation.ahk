#Requires AutoHotkey v2.0
#SingleInstance Force

;═══════════════════════════════════════════════════════════════════════════
;  划词翻译 · AI 版  （AutoHotkey v2）
;
;  用法：在任意程序里选中文字 → 按 Ctrl+Alt+T → 弹窗显示译文
;        Esc 关闭弹窗 / Ctrl+C 复制结果 / 可切换目标语言后点「重译」
;
;  支持任何 OpenAI 兼容接口：DeepSeek、Google AI Studio (Gemini)、OpenAI、
;  Kimi、通义千问、智谱 GLM、本机 Ollama、LM Studio、one-api 中转站 ……
;
;  只需要改下面【配置区】的 ApiUrl / Model / ApiKey 三项即可。
;═══════════════════════════════════════════════════════════════════════════


;───────────────────────────── ① 配置区 ─────────────────────────────
;
;  现成方案（把对应三行贴进下面的配置即可）：
;
;  ▸ Google AI Studio / Gemini（OpenAI 兼容层，key 形如 AIza...）
;      ApiUrl: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
;      Model:  "gemini-3.8-flash"
;      ApiKey: "AIza..."
;
;  ▸ OpenAI
;      ApiUrl: "https://api.openai.com/v1/chat/completions"
;      Model:  "gpt-4o-mini"
;
;  ▸ 本机 Ollama（不需要 Key）
;      ApiUrl: "http://127.0.0.1:11434/v1/chat/completions"
;      Model:  "qwen2.5:7b"
;
global CFG := {
    ; 触发快捷键（AHK 语法：^=Ctrl  !=Alt  +=Shift  #=Win）
    Hotkey:          "^!t",

    ; 是否额外支持「连按两次 Ctrl+C」触发（不需要选中后按快捷键）
    DoubleCtrlC:     false,

    ; 接口地址：需以 /chat/completions 结尾（OpenAI 兼容格式）
    ApiUrl:          "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",

    ; 模型名（DeepSeek 目前是 deepseek-flash / deepseek-v4-pro，以官方文档为准）
    Model:           "gemini-3.5-flash-lite",

    ; API Key。留空则依次读取同目录 .env 中的 TRANSLATE_API_KEY、系统环境变量 TRANSLATE_API_KEY；
    ; 本机 Ollama / LM Studio 不需要 Key，留空即可。
    ApiKey:          "",

    ; 首次打开时的源语言与目标语言（可选值见下方 LANGS 列表）
    SourceLang:      "自动",
    TargetLang:      "自动",

    ; 单次请求超时（秒）
    Timeout:         60,

    ; 原文超过这么多字符就截断，防止烧 token
    MaxInputChars:   4000,

    ; 收到译文后自动复制到剪贴板
    AutoCopyResult:  false,

    ; 取词时发送的复制按键（个别软件需要 "^c" 改成 "^ins"）
    CopyKeys:        "^c",

    ; 可选：给翻译请求单独指定 HTTP 代理，例如 "127.0.0.1:7890"（Clash 混合端口）。
    ; 留空 = 跟随系统/WinHTTP 代理；用 TUN 模式的话留空也能通。
    Proxy:           "",

    ; 可选：推理强度 "minimal" / "low" / "medium" / "high"（各模型档位不同）。
    ; Gemini 3.8 Flash 默认 medium（思考会消耗免费额度、也慢），翻译设 "low" 更合适。
    ; 注意：gemini-3.5-flash-lite 默认就不思考，这里必须留空！给它设 low 会把思考打开（更慢更费）；DeepSeek / Ollama 也留空。
    ReasoningEffort: ""
}

; 可选的目标语言（下拉框内容，可自行增删）
global LANGS := ["自动", "简体中文", "英文", "日文", "韩文", "法文", "德文",
                 "俄文", "西班牙文", "葡萄牙文", "意大利文", "繁体中文"]


;───────────────────────────── ② 运行时状态 ─────────────────────────────
global G := 0                 ; 主窗口对象
global SrcEdit := 0           ; 原文框
global ResEdit := 0           ; 译文框
global StatusText := 0        ; 顶部状态文字
global DdlSrcLang := 0        ; 源语言下拉框
global BtnSwap := 0           ; 互换语言按钮
global DdlLang := 0           ; 目标语言下拉框
global BtnRetry := 0
global BtnCopy := 0
global BtnClose := 0
global Cur := 0               ; 当前请求 {req, start}
global Busy := false          ; 是否正在请求
global GuiReady := false      ; 界面是否已创建
global LastText := ""         ; 上一次翻译的原文
global TapTick := 0           ; 连按 Ctrl+C 的计时
global Cache := Map()         ; 内存翻译缓存（key: 目标语言 + 原文）

; 只在「直接运行本文件」时启动界面；被其它脚本 #Include 时只提供函数
if (A_LineFile = A_ScriptFullPath)
    Main()


; 连按两次 Ctrl+C 也可以触发（只在 CFG.DoubleCtrlC 为 true 时才注册，避免干扰平时的复制）
DoubleCtrlCHandler(*) {
    global TapTick, Busy
    if Busy
        return
    now := A_TickCount
    if (TapTick && now - TapTick < 500) {
        TapTick := 0
        DoTranslate()
    } else {
        TapTick := now
    }
}


;═══════════════════════════════════════════════════════════════════════════
;  主流程
;═══════════════════════════════════════════════════════════════════════════

Main() {
    SendMode("Input")
    CoordMode("Mouse", "Screen")
    CoordMode("ToolTip", "Screen")
    SetupTray()
    SetupGui()
    try Hotkey(CFG.Hotkey, (*) => DoTranslate())
    catch as e
        MsgBox("快捷键 " . CFG.Hotkey . " 注册失败：" . e.Message, "划词翻译", "Icon!")
    if CFG.DoubleCtrlC {
        try Hotkey("~^c", DoubleCtrlCHandler)
        catch
            ShowTip("~^c 注册失败，连按 Ctrl+C 触发不可用")
    }
    A_IconTip := "划词翻译 · " . CFG.Model
}


SetupTray() {
    menu := A_TrayMenu
    menu.Add()
    menu.Add("翻译选中文本`t" . PrettyHotkey(CFG.Hotkey), (*) => DoTranslate())
    menu.Add("编辑脚本", (*) => OpenScriptForEdit())
    menu.Add("重新加载", (*) => Reload())
    menu.Add("退出", (*) => ExitApp())
}


OpenScriptForEdit() {
    try
        Run("*Edit " . A_ScriptFullPath)
    catch
        Run('notepad.exe "' . A_ScriptFullPath . '"')
}


;───────────────────────────── 取词 & 翻译 ─────────────────────────────

DoTranslate() {
    global Busy, LastText

    if Busy {
        ShowTip("上一次翻译还没结束…")
        return
    }

    text := GetSelectedText()
    text := Trim(text, " `t`r`n")
    if (text = "") {
        ShowTip("没有取到选中文本：先选中文字，再按 " . PrettyHotkey(CFG.Hotkey))
        return
    }
    if !RegExMatch(text, "[\p{L}]") {
        ShowTip("选中内容不含文字，已跳过翻译")
        return
    }

    if (StrLen(text) > CFG.MaxInputChars) {
        text := SubStr(text, 1, CFG.MaxInputChars)
        ShowTip("原文过长，只翻译前 " . CFG.MaxInputChars . " 个字符")
    }

    LastText := text
    ShowPanel(text)
    RequestTranslation(text)
}


; 用「复制」取词，并完整还原用户原来的剪贴板内容
GetSelectedText() {
    saved := ClipboardAll()
    A_Clipboard := ""

    ; 热键里的 Ctrl/Alt 可能还按着，等用户松开，否则应用收到的是 Ctrl+Alt+C
    KeyWait("Alt", "T0.3")
    KeyWait("Ctrl", "T0.3")
    KeyWait("Shift", "T0.3")
    Sleep(30)

    Send(CFG.CopyKeys)
    got := ClipWait(0.7)
    text := got ? A_Clipboard : ""
    Sleep(60)                    ; 等目标程序写完剪贴板再还原
    A_Clipboard := saved
    return text
}


RequestTranslation(text, force := false) {
    global CFG, Cur, Busy, Cache

    AbortRequest()
    if IsObject(ResEdit)
        ResEdit.Value := ""

    source := SourceLangNow()
    target := TargetLangNow()
    if (source != "自动" && source = target) {
        if IsObject(ResEdit)
            ResEdit.Value := text
        SetStatus("源语言与目标语言相同 · 已跳过请求")
        return
    }
    cacheKey := source . "->" . target . "`n" . text
    if (!force && Cache.Has(cacheKey)) {
        ShowResult(Cache[cacheKey], 0, true)
        return
    }

    if (Trim(CFG.ApiUrl) = "") {
        ShowError("还没有配置接口地址。`n请修改脚本顶部的 CFG.ApiUrl。")
        return
    }

    effectiveTarget := (target = "" || target = "自动") ? ResolveAutoTarget(text) : target
    maxOut := Min(4096, Max(256, StrLen(text) * 4))
    payload := Map(
        "model", CFG.Model,
        "temperature", 0.3,
        "max_tokens", maxOut,
        "messages", [
            Map("role", "system", "content", BuildSystemPrompt(source, effectiveTarget)),
            Map("role", "user", "content", text)
        ]
    )
    if (Trim(CFG.ReasoningEffort) != "")
        payload["reasoning_effort"] := Trim(CFG.ReasoningEffort)
    body := JsonEncode(payload)

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", Trim(CFG.ApiUrl), true)
        req.SetRequestHeader("Content-Type", "application/json")
        req.SetRequestHeader("Accept", "application/json")
        req.SetRequestHeader("Accept-Encoding", "identity")
        if (Trim(CFG.Proxy) != "")
            req.SetProxy(2, Trim(CFG.Proxy))       ; 2 = 使用指定代理服务器
        key := GetApiKey()
        if (key != "")
            req.SetRequestHeader("Authorization", "Bearer " . key)
        req.Send(body)
    } catch as e {
        ShowError("请求发送失败：`n" . e.Message . "`n`n请检查网络、代理或 CFG.ApiUrl。")
        return
    }

    Busy := true
    Cur := {req: req, start: A_TickCount, key: cacheKey}
    SetStatus("翻译中… 0.0s · " . CFG.Model)
    SetTimer(PollTimer, 80)
}


; 轮询异步请求，避免界面卡死
PollTimer() {
    global CFG, Cur, Busy

    if !IsObject(Cur) {
        SetTimer(PollTimer, 0)
        return
    }

    start := Cur.start
    elapsed := (A_TickCount - start) / 1000

    if (elapsed > CFG.Timeout) {
        AbortRequest()
        ShowError("请求超时（" . CFG.Timeout . " 秒）。`n可在 CFG.Timeout 里调大，或检查网络/代理。")
        return
    }

    SetStatus("翻译中… " . Format("{:.1f}", elapsed) . "s · " . CFG.Model)

    ready := false
    try {
        ready := Cur.req.WaitForResponse(0)
    } catch as e {
        AbortRequest()
        ShowError("网络错误：`n" . e.Message)
        return
    }
    if !ready
        return

    SetTimer(PollTimer, 0)
    req := Cur.req
    cacheKey := Cur.key
    Cur := 0
    Busy := false

    status := 0
    try status := req.Status
    body := ReadResponseText(req)
    cost := (A_TickCount - start) / 1000

    if (status != 200) {
        hint := ""
        if (status = 401)
            hint := "`n`n（401：API Key 无效或没填）"
        else if (status = 404)
            hint := "`n`n（404：ApiUrl 或 Model 名字不对）"
        else if (status = 429)
            hint := "`n`n（429：请求太频繁或余额不足）"
        ShowError("接口返回 HTTP " . status . "：" . hint . "`n`n" . Shorten(body, 600))
        return
    }

    content := ""
    reason := ""
    try {
        j := JsonParse(body)
        if (Type(j) = "Map" && j.Has("error")) {
            ShowError("接口报错：`n`n" . Shorten(body, 600))
            return
        }
        if (Type(j) = "Map" && j.Has("choices") && Type(j["choices"]) = "Array"
            && j["choices"].Length >= 1) {
            choice := j["choices"][1]
            if (Type(choice) = "Map" && choice.Has("message") && Type(choice["message"]) = "Map") {
                msgObj := choice["message"]
                if msgObj.Has("content")
                    content := AsText(msgObj["content"])
                if (Trim(content) = "") {
                    ; 部分推理模型（DeepSeek-R1 / Gemini 3 thinking）只有思考内容
                    if msgObj.Has("reasoning_content")
                        reason := AsText(msgObj["reasoning_content"])
                    else if msgObj.Has("reasoning")
                        reason := AsText(msgObj["reasoning"])
                }
            }
        }
    } catch as e {
        ShowError("解析响应失败：" . e.Message . "`n`n" . Shorten(body, 400))
        return
    }

    if (Trim(content) != "") {
        SaveCache(cacheKey, content)
        ShowResult(content, cost)
        return
    }
    if (Trim(reason) != "") {
        ResEdit.Value := reason
        SetStatus("模型只返回了思考内容 · " . Format("{:.1f}", cost) . "s")
        return
    }
    ShowError("接口没有返回译文。`n`n原始响应：`n" . Shorten(body, 600))
}


; 模型偶尔把 content 返回成分段数组，这里统一转成文本
AsText(v) {
    if (Type(v) = "String")
        return v
    if (Type(v) = "Array") {
        out := ""
        for part in v {
            if (Type(part) = "Map" && part.Has("text"))
                out .= AsText(part["text"])
            else
                out .= AsText(part)
        }
        return out
    }
    if (Type(v) = "Map")
        return v.Has("text") ? AsText(v["text"]) : ""
    return ""
}


AbortRequest() {
    global Cur, Busy
    SetTimer(PollTimer, 0)
    if IsObject(Cur) {
        try Cur.req.Abort()
    }
    Cur := 0
    Busy := false
}


GetApiKey() {
    global CFG
    if (Trim(CFG.ApiKey) != "")
        return Trim(CFG.ApiKey)
    envKey := ReadDotEnvKey(A_ScriptDir . "\.env", "TRANSLATE_API_KEY")
    if (envKey != "")
        return envKey
    return Trim(EnvGet("TRANSLATE_API_KEY"))
}


ReadDotEnvKey(filePath, keyName) {
    if !FileExist(filePath)
        return ""
    try content := FileRead(filePath, "UTF-8")
    catch
        return ""
    for rawLine in StrSplit(content, "`n", "`r") {
        line := Trim(rawLine, " `t")
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        pos := InStr(line, "=")
        if (!pos)
            continue
        k := Trim(SubStr(line, 1, pos - 1), " `t")
        if (k = keyName)
            return Trim(SubStr(line, pos + 1), " `t`r`n`"'")
    }
    return ""
}


GetLangFromDdl(ddl, fallback) {
    global LANGS
    if !IsObject(ddl)
        return fallback
    idx := ddl.Value
    return (idx >= 1 && idx <= LANGS.Length) ? LANGS[idx] : "自动"
}

SourceLangNow() => GetLangFromDdl(DdlSrcLang, CFG.SourceLang)

TargetLangNow() => GetLangFromDdl(DdlLang, CFG.TargetLang)


SaveCache(key, val) {
    global Cache
    if (Cache.Count >= 100)
        Cache.Clear()
    Cache[key] := val
}


ResolveAutoTarget(text) {
    if RegExMatch(text, "[\x{3040}-\x{30ff}\x{ac00}-\x{d7af}]")
        return "Simplified Chinese"
    zhLen := StrLen(RegExReplace(text, "[^\x{4e00}-\x{9fff}]"))
    enLen := StrLen(RegExReplace(text, "[^A-Za-z]"))
    if (zhLen >= 2 || (zhLen = 1 && enLen < 4))
        return "English"
    return "Simplified Chinese"
}


BuildSystemPrompt(source, target) {
    srcPart := (source = "" || source = "自动") ? "" : " from " . source
    return "Translate" . srcPart . " to " . target . ". Output translation only; preserve formatting, code, and identifiers; no explanations."
}


;───────────────────────────── 界面 ─────────────────────────────

SetupGui() {
    global G, SrcEdit, ResEdit, StatusText, DdlSrcLang, BtnSwap, DdlLang, BtnRetry, BtnCopy, BtnClose, CFG

    g := Gui("+AlwaysOnTop +Resize +MinSize480x280", "划词翻译 · AI")
    g.BackColor := "0xFFFFFF"
    g.MarginX := 12
    g.MarginY := 10
    g.SetFont("s10", "Microsoft YaHei UI")

    StatusText := g.AddText("x12 y8 w520 h18 c0x888888", "就绪 · " . CFG.Model)
    StatusText.SetFont("s9", "Microsoft YaHei UI")

    SrcEdit := g.AddEdit("x12 y30 w520 h62 ReadOnly +VScroll", "")
    SrcEdit.SetFont("s9", "Microsoft YaHei UI")

    ResEdit := g.AddEdit("x12 y104 w520 h248 ReadOnly +VScroll", "")
    ResEdit.SetFont("s11", "Microsoft YaHei UI")

    DdlSrcLang := g.AddDropDownList("x12 y364 w90", LANGS)
    BtnSwap := g.AddButton("x106 y364 w24 h26", "⇄")
    DdlLang := g.AddDropDownList("x134 y364 w90", LANGS)
    SelectLangDdl(DdlSrcLang, CFG.SourceLang)
    SelectLangDdl(DdlLang, CFG.TargetLang)

    BtnRetry := g.AddButton("x324 y364 w60 h26", "重译")
    BtnCopy := g.AddButton("x390 y364 w76 h26", "复制译文")
    BtnClose := g.AddButton("x472 y364 w64 h26", "关闭")

    DdlSrcLang.OnEvent("Change", (*) => TryShowCached())
    DdlLang.OnEvent("Change", (*) => TryShowCached())
    BtnSwap.OnEvent("Click", (*) => SwapLangs())
    BtnRetry.OnEvent("Click", (*) => Retranslate())
    BtnCopy.OnEvent("Click", (*) => CopyResult())
    BtnClose.OnEvent("Click", (*) => ClosePanel())
    g.OnEvent("Close", (*) => ClosePanel())
    g.OnEvent("Size", (guiObj, minMax, w, h) => (minMax = -1 ? 0 : Relayout()))

    ; 窗口是活动窗口时，Esc 关闭
    HotIf((*) => WinActive("ahk_id " . g.Hwnd))
    try Hotkey("$Esc", (*) => ClosePanel())
    HotIf()

    G := g
    GuiReady := true
}


SelectLangDdl(ddl, langName) {
    global LANGS
    ddl.Value := 1
    for i, name in LANGS {
        if (name = langName) {
            ddl.Value := i
            break
        }
    }
}


SwapLangs() {
    global DdlSrcLang, DdlLang
    if !(IsObject(DdlSrcLang) && IsObject(DdlLang))
        return
    srcIdx := DdlSrcLang.Value
    DdlSrcLang.Value := DdlLang.Value
    DdlLang.Value := srcIdx
    TryShowCached()
}


TryShowCached() {
    global LastText, Busy, Cache
    if (Busy || Trim(LastText) = "")
        return
    key := SourceLangNow() . "->" . TargetLangNow() . "`n" . LastText
    if Cache.Has(key)
        ShowResult(Cache[key], 0, true)
}


EnsureGui() {
    global GuiReady
    if (GuiReady && IsObject(G))
        return
    SetupGui()
}


LayoutGui(w, h) {
    global SrcEdit, ResEdit, StatusText, DdlSrcLang, BtnSwap, DdlLang, BtnRetry, BtnCopy, BtnClose
    if !IsObject(SrcEdit)
        return

    m := 12
    innerW := w - m * 2
    if (innerW < 120)
        innerW := 120

    StatusText.Move(m, 8, innerW, 18)
    SrcEdit.Move(m, 30, innerW, 62)

    resH := h - 106 - 46
    if (resH < 40)
        resH := 40
    ResEdit.Move(m, 104, innerW, resH)

    by := h - 36
    DdlSrcLang.Move(m, by, 90, 26)
    BtnSwap.Move(m + 94, by, 24, 26)
    DdlLang.Move(m + 122, by, 90, 26)
    BtnClose.Move(w - m - 64, by, 64, 26)
    BtnCopy.Move(w - m - 64 - 6 - 76, by, 76, 26)
    BtnRetry.Move(w - m - 64 - 6 - 76 - 6 - 60, by, 60, 26)
}


; 统一用「客户区逻辑尺寸」排版（AHK 会在高 DPI 下自动缩放控件）
Relayout() {
    global G
    try {
        G.GetClientPos(&cx, &cy, &cw, &ch)
        LayoutGui(cw, ch)
    }
}


ShowPanel(text) {
    global G, SrcEdit, ResEdit

    EnsureGui()
    SrcEdit.Value := text
    ResEdit.Value := ""

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    area := GetWorkArea(mx, my)

    ; 屏幕坐标是物理像素，先用鼠标位置摆好，再按实测窗口尺寸校正
    gx := mx + 16
    gy := my + 20
    if (gx + 100 > area.r)
        gx := area.r - 200
    if (gy + 100 > area.b)
        gy := area.b - 200

    G.Show("x" . gx . " y" . gy . " w560 h400")
    Relayout()

    ww := 560, wh := 400
    try WinGetPos(, , &ww, &wh, "ahk_id " . G.Hwnd)

    nx := gx
    ny := gy
    if (nx + ww > area.r)
        nx := area.r - ww - 8
    if (ny + wh > area.b)
        ny := area.b - wh - 8
    if (nx < area.l + 4)
        nx := area.l + 4
    if (ny < area.t + 4)
        ny := area.t + 4
    if (nx != gx || ny != gy)
        G.Move(nx, ny)

    ResEdit.Focus()
}


GetWorkArea(x, y) {
    n := 1
    try n := MonitorGetCount()
    loop n {
        i := A_Index
        l := 0, t := 0, r := 0, b := 0
        try MonitorGet(i, &l, &t, &r, &b)
        catch
            continue
        if (x >= l && x < r && y >= t && y < b) {
            wl := l, wt := t, wr := r, wb := b
            try MonitorGetWorkArea(i, &wl, &wt, &wr, &wb)
            return {l: wl, t: wt, r: wr, b: wb}
        }
    }
    wl := 0, wt := 0, wr := A_ScreenWidth, wb := A_ScreenHeight
    try MonitorGetWorkArea(1, &wl, &wt, &wr, &wb)
    return {l: wl, t: wt, r: wr, b: wb}
}


ShowResult(text, cost, cached := false) {
    global ResEdit, CFG
    ResEdit.Value := text
    langPair := SourceLangNow() . " → " . TargetLangNow()
    prefix := cached ? "缓存 · " : "完成 · "
    SetStatus(prefix . StrLen(text) . " 字 · " . Format("{:.1f}", cost) . "s · " . langPair)
    if CFG.AutoCopyResult {
        A_Clipboard := text
        SetStatus("已复制结果 · " . Format("{:.1f}", cost) . "s · " . langPair)
    }
    ResEdit.Focus()
    PutCaretAtStart(ResEdit)
}


; 让结果框显示时没有整段高亮，光标停在开头
PutCaretAtStart(ctl) {
    try PostMessage(0x00B1, 0, 0, ctl.Hwnd)      ; EM_SETSEL
}


ShowError(msg) {
    global ResEdit, Busy
    Busy := false
    if IsObject(ResEdit)
        ResEdit.Value := "⚠ " . msg
    SetStatus("出错")
}


SetStatus(msg) {
    global StatusText
    if IsObject(StatusText)
        StatusText.Text := msg
}


Retranslate() {
    global LastText, Busy, ResEdit
    if (Busy || Trim(LastText) = "")
        return
    ResEdit.Value := ""
    RequestTranslation(LastText, true)
}


CopyResult() {
    global ResEdit
    if !IsObject(ResEdit)
        return
    txt := ResEdit.Value
    if (Trim(txt) = "")
        return
    A_Clipboard := txt
    ShowTip("已复制译文")
}


ClosePanel() {
    global G
    AbortRequest()
    if IsObject(G)
        G.Hide()
}


ShowTip(msg, ms := 1600) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ToolTip(msg, mx + 16, my + 24, 3)
    SetTimer(() => ToolTip("", , , 3), -ms)
}


;───────────────────────────── 小工具 ─────────────────────────────

PrettyHotkey(hk) {
    out := hk
    out := StrReplace(out, "+", "Shift+")
    out := StrReplace(out, "!", "Alt+")
    out := StrReplace(out, "^", "Ctrl+")
    out := StrReplace(out, "#", "Win+")
    return StrUpper(out)
}


Shorten(s, n) {
    s := StrReplace(s, "`r`n", "`n")
    return StrLen(s) > n ? SubStr(s, 1, n) . " …" : s
}


;═══════════════════════════════════════════════════════════════════════════
;  JSON：解析（响应）与生成（请求）——不依赖任何外部库
;═══════════════════════════════════════════════════════════════════════════

JsonParse(src) {
    ctx := {s: src, i: 1, n: StrLen(src)}
    SkipWS(ctx)
    val := ParseValue(ctx)
    SkipWS(ctx)
    if (ctx.i <= ctx.n)
        throw ValueError("多余的字符，位置 " . ctx.i)
    return val
}


SkipWS(ctx) {
    while (ctx.i <= ctx.n) {
        c := SubStr(ctx.s, ctx.i, 1)
        if (c = " " || c = "`t" || c = "`r" || c = "`n" || c = Chr(0xFEFF))
            ctx.i += 1
        else
            break
    }
}


ParseValue(ctx) {
    c := SubStr(ctx.s, ctx.i, 1)
    if (c = "{")
        return ParseObject(ctx)
    if (c = "[")
        return ParseArray(ctx)
    if (c = '"')
        return ParseString(ctx)
    if (c = "t") {
        Expect(ctx, "true")
        return true
    }
    if (c = "f") {
        Expect(ctx, "false")
        return false
    }
    if (c = "n") {
        Expect(ctx, "null")
        return ""
    }
    return ParseNumber(ctx)
}


Expect(ctx, word) {
    if (SubStr(ctx.s, ctx.i, StrLen(word)) != word)
        throw ValueError("期望 " . word . "，位置 " . ctx.i)
    ctx.i += StrLen(word)
}


ParseObject(ctx) {
    obj := Map()
    ctx.i += 1                        ; 跳过 {
    SkipWS(ctx)
    if (SubStr(ctx.s, ctx.i, 1) = "}") {
        ctx.i += 1
        return obj
    }
    loop {
        SkipWS(ctx)
        key := ParseString(ctx)
        SkipWS(ctx)
        if (SubStr(ctx.s, ctx.i, 1) != ":")
            throw ValueError("对象缺少冒号，位置 " . ctx.i)
        ctx.i += 1
        SkipWS(ctx)
        obj[key] := ParseValue(ctx)
        SkipWS(ctx)
        c := SubStr(ctx.s, ctx.i, 1)
        if (c = ",") {
            ctx.i += 1
            continue
        }
        if (c = "}") {
            ctx.i += 1
            return obj
        }
        throw ValueError("对象缺少 , 或 }，位置 " . ctx.i)
    }
}


ParseArray(ctx) {
    arr := []
    ctx.i += 1                        ; 跳过 [
    SkipWS(ctx)
    if (SubStr(ctx.s, ctx.i, 1) = "]") {
        ctx.i += 1
        return arr
    }
    loop {
        SkipWS(ctx)
        arr.Push(ParseValue(ctx))
        SkipWS(ctx)
        c := SubStr(ctx.s, ctx.i, 1)
        if (c = ",") {
            ctx.i += 1
            continue
        }
        if (c = "]") {
            ctx.i += 1
            return arr
        }
        throw ValueError("数组缺少 , 或 ]，位置 " . ctx.i)
    }
}


ParseString(ctx) {
    s := ctx.s
    n := ctx.n
    if (SubStr(s, ctx.i, 1) != '"')
        throw ValueError("字符串开头缺少引号，位置 " . ctx.i)

    ctx.i += 1
    start := ctx.i
    out := ""
    while (ctx.i <= n) {
        c := SubStr(s, ctx.i, 1)
        if (c = '"') {
            out .= SubStr(s, start, ctx.i - start)
            ctx.i += 1
            return out
        }
        if (c = "\") {
            out .= SubStr(s, start, ctx.i - start)
            ctx.i += 1
            esc := SubStr(s, ctx.i, 1)
            if (esc = "u") {
                hex := SubStr(s, ctx.i + 1, 4)
                if (StrLen(hex) < 4 || !RegExMatch(hex, "^[0-9a-fA-F]{4}$"))
                    throw ValueError("\\u 转义不完整，位置 " . ctx.i)
                code := Integer("0x" . hex)
                ctx.i += 5
                ; 代理对 \uD83D\uDE00
                if (code >= 0xD800 && code <= 0xDBFF && SubStr(s, ctx.i, 2) = "\u") {
                    hex2 := SubStr(s, ctx.i + 2, 4)
                    if (StrLen(hex2) = 4 && RegExMatch(hex2, "^[0-9a-fA-F]{4}$")) {
                        low := Integer("0x" . hex2)
                        if (low >= 0xDC00 && low <= 0xDFFF) {
                            code := 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                            ctx.i += 6
                        }
                    }
                }
                out .= Chr(code)
            } else {
                switch esc {
                    case '"':  out .= '"'
                    case "\":  out .= "\"
                    case "/":  out .= "/"
                    case "b":  out .= Chr(8)
                    case "f":  out .= Chr(12)
                    case "n":  out .= "`n"
                    case "r":  out .= "`r"
                    case "t":  out .= "`t"
                    default:   out .= esc
                }
                ctx.i += 1
            }
            start := ctx.i
            continue
        }
        ctx.i += 1
    }
    throw ValueError("字符串没有闭合")
}


ParseNumber(ctx) {
    rest := SubStr(ctx.s, ctx.i)
    if !RegExMatch(rest, "^-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?", &m)
        throw ValueError("不是合法的数字，位置 " . ctx.i)
    token := m[0]
    ctx.i += StrLen(token)
    if (InStr(token, ".") || InStr(token, "e") || InStr(token, "E"))
        return Float(token)
    return Integer(token)
}


JsonEncode(v) {
    t := Type(v)
    switch t {
        case "String":
            return '"' . JsonEscape(v) . '"'
        case "Integer":
            return String(v)
        case "Float":
            return Format("{:g}", v)
        case "Array":
            out := "["
            for i, item in v {
                if (i > 1)
                    out .= ","
                out .= JsonEncode(item)
            }
            return out . "]"
        case "Map", "Object":
            out := "{"
            first := true
            for k, item in v {
                if !first
                    out .= ","
                first := false
                out .= '"' . JsonEscape(String(k)) . '":' . JsonEncode(item)
            }
            return out . "}"
        default:
            return "null"
    }
}


JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    if RegExMatch(s, "[\x00-\x1F]") {
        res := ""
        loop StrLen(s) {
            ch := SubStr(s, A_Index, 1)
            if (Ord(ch) < 0x20)
                res .= Format("\u{:04x}", Ord(ch))
            else
                res .= ch
        }
        s := res
    }
    return s
}


;═══════════════════════════════════════════════════════════════════════════
;  HTTP：响应体按 UTF-8 解码（WinHttp 默认可能按 Latin-1 解释中文）
;═══════════════════════════════════════════════════════════════════════════

ReadResponseText(req) {
    try {
        st := ComObject("ADODB.Stream")
        st.Type := 1                  ; adTypeBinary
        st.Open()
        st.Write(req.ResponseBody)
        st.Position := 0
        st.Type := 2                  ; adTypeText
        st.Charset := "utf-8"
        txt := st.ReadText()
        st.Close()
        return txt
    } catch {
        return req.ResponseText
    }
}
