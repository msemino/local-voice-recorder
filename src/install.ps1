# install.ps1 — sets up GrabadorIA: copies files, creates autostart shortcut and Desktop shortcut.
# Run once with: powershell -ExecutionPolicy Bypass -File install.ps1
#   -WhisperDir  : path where whisper.cpp is installed (default D:\whisper)
#   -ModelName   : whisper model file (default ggml-large-v3.bin)

param(
    [string]$WhisperDir = "D:\whisper",
    [string]$ModelName  = "ggml-large-v3.bin"
)

$SRC = $PSScriptRoot

# Copy scripts
Copy-Item "$SRC\GrabadorIA.ps1" "$WhisperDir\GrabadorIA.ps1" -Force
Copy-Item "$SRC\GrabarIA.vbs"   "$WhisperDir\GrabarIA.vbs"   -Force

$VBS = "$WhisperDir\GrabarIA.vbs"

# Desktop shortcut
$WS = New-Object -ComObject WScript.Shell
$SC = $WS.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Grabador IA.lnk")
$SC.TargetPath       = $VBS
$SC.Description      = "Grabador de voz local (Whisper)"
$SC.Save()

# Autostart shortcut
$STARTUP = [Environment]::GetFolderPath("Startup")
$SC2 = $WS.CreateShortcut("$STARTUP\GrabadorIA.lnk")
$SC2.TargetPath = $VBS
$SC2.Description = "GrabadorIA autostart"
$SC2.Save()

Write-Host "Installed. Launch via Desktop shortcut or it will start automatically on next login."
Write-Host "WhisperDir : $WhisperDir"
Write-Host "Model      : $ModelName"
