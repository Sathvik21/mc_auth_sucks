; AutoHotkey v2 script — binds Ctrl+Alt+T to run totp.ps1 and shows a
; toast with the code (it's already on your clipboard either way).
;
; Setup:
;   1. Install AutoHotkey v2: https://www.autohotkey.com/
;   2. Edit the $scriptPath below to point at totp.ps1's actual location.
;   3. Double-click this file to run it, or put a shortcut to it in
;      shell:startup so it loads automatically at login.
;
; Change the hotkey below if Ctrl+Alt+T collides with something else on
; your system (e.g. some terminal apps use it).

scriptPath := A_ScriptDir . "\totp.ps1"

^!t:: {
    result := ""
    try {
        result := RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' scriptPath '"', , "Hide")
    }
    ; Clipboard is set by the PowerShell script itself; give it a moment.
    Sleep 300
    code := A_Clipboard
    TrayTip("TOTP code", code . " — copied", 1)
}
