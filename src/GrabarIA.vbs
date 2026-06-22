' GrabarIA.vbs — hidden launcher for GrabadorIA.ps1
' Double-click this file (or put it in shell:startup) to start the tray app without a console window.
Set oShell = CreateObject("WScript.Shell")
oShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & _
    Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "GrabadorIA.ps1""", 0, False
