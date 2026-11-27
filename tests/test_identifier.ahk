#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\Translation.ahk

failures := 0

AssertEq(actual, expected, name) {
    global failures
    if (actual !== expected) {
        failures += 1
        FileAppend("FAIL: " . name . " | expected=" . String(expected) . " actual=" . String(actual) . "`n", "*")
    }
}

; 应当识别为标识符的用例
AssertEq(IsIdentifierText("getUserProfile"), true, "camelCase")
AssertEq(IsIdentifierText("UserProfile"), true, "PascalCase")
AssertEq(IsIdentifierText("XMLParser"), true, "AcronymPrefixPascalCase")
AssertEq(IsIdentifierText("userID"), true, "AcronymSuffixCamelCase")
AssertEq(IsIdentifierText("v2Api"), true, "DigitCamelCase")
AssertEq(IsIdentifierText("user_id"), true, "snake_case")
AssertEq(IsIdentifierText("MAX_RETRY_COUNT"), true, "SCREAMING_SNAKE_CASE")
AssertEq(IsIdentifierText("user-id"), true, "kebab-case")
AssertEq(IsIdentifierText("_internalValue"), true, "leading_underscore")
AssertEq(IsIdentifierText("getUserProfile`r`nmaxRetryCount`r`nuser_id"), true, "multiline_crlf_identifiers")
AssertEq(IsIdentifierText("XMLParser HTTP"), true, "identifier_with_acronym")

; 不应当识别为标识符的用例
AssertEq(IsIdentifierText("hello"), false, "single_plain_word")
AssertEq(IsIdentifierText("hello world"), false, "plain_words")
AssertEq(IsIdentifierText("Hello World"), false, "title_case_words")
AssertEq(IsIdentifierText("getUserProfile is a function"), false, "mixed_sentence")
AssertEq(IsIdentifierText("Call getUserProfile() now."), false, "sentence_with_punctuation")
AssertEq(IsIdentifierText("12345"), false, "digits_only")
AssertEq(IsIdentifierText("2026-11-27"), false, "date_string")
AssertEq(IsIdentifierText("_123_456"), false, "underscore_digits_only")
AssertEq(IsIdentifierText("user-"), false, "trailing_hyphen")
AssertEq(IsIdentifierText("-flag"), false, "leading_hyphen")
AssertEq(IsIdentifierText("HTTP"), false, "acronym_only_no_compound")
AssertEq(IsIdentifierText(""), false, "empty")

; Prompt 分支测试
p1 := BuildSystemPrompt("自动", "Simplified Chinese", true)
AssertEq(InStr(p1, "If the input is a code identifier") > 0, true, "prompt_identifier")
AssertEq(InStr(p1, "programming meaning") = 0, true, "prompt_identifier_no_forced_jargon")

p2 := BuildSystemPrompt("自动", "Simplified Chinese", false)
AssertEq(InStr(p2, "preserve formatting, code, and identifiers") > 0, true, "prompt_normal")

if (failures > 0) {
    FileAppend("TOTAL FAILURES: " . failures . "`n", "*")
    ExitApp(1)
}
FileAppend("ALL TESTS PASSED`n", "*")
ExitApp(0)
