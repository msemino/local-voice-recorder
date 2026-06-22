# GrabadorIA.ps1 — Local voice recorder: speak -> whisper.cpp -> clipboard
# Requires: whisper.cpp build with CUDA in $WHISPER_DIR, ffmpeg on PATH
# Usage: run via GrabarIA.vbs (hidden) or directly with -ExecutionPolicy Bypass
# IMPORTANT: keep this file ASCII-only. PowerShell 5.1 parses it as ANSI;
#            accented chars in CODE (not runtime strings) cause parse errors.

param(
    [string]$WhisperDir = "D:\whisper",
    [string]$Model      = "ggml-large-v3.bin",
    [string]$Language   = "es"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- singleton guard ----
$mutex = New-Object System.Threading.Mutex($false, "GrabadorIA_SingleInstance")
if (-not $mutex.WaitOne(0)) {
    [System.Windows.Forms.MessageBox]::Show("GrabadorIA ya esta corriendo.", "Aviso")
    exit 0
}

$WHISPER_EXE = Join-Path $WhisperDir "bin\Release\whisper-cli.exe"
$MODEL_PATH  = Join-Path $WhisperDir "models\$Model"
$LOG_FILE    = Join-Path $WhisperDir "grabador.log"
$DESKTOP     = [Environment]::GetFolderPath("Desktop")

function Write-Log([string]$msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

# ---- icon factory (no .ico files needed) ----
function New-Icon([System.Drawing.Color]$color, [bool]$blink) {
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush($color)
    $g.FillEllipse($brush, 2, 2, 12, 12)
    $brush.Dispose(); $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$iconRed    = New-Icon ([System.Drawing.Color]::FromArgb(220, 50, 50))   $false
$iconYellow = New-Icon ([System.Drawing.Color]::FromArgb(220, 180, 0))   $false
$iconGreen  = New-Icon ([System.Drawing.Color]::FromArgb(50, 180, 50))   $false

# ---- tray icon ----
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = $iconRed
$tray.Visible = $true
$tray.Text    = "GrabadorIA — listo"

$menuRecord = New-Object System.Windows.Forms.ToolStripMenuItem("Grabar / Parar")
$menuExit   = New-Object System.Windows.Forms.ToolStripMenuItem("Salir")
$ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip
$ctxMenu.Items.Add($menuRecord) | Out-Null
$ctxMenu.Items.Add($menuExit)   | Out-Null
$tray.ContextMenuStrip = $ctxMenu

# ---- state ----
$script:recording   = $false
$script:ffmpegProc  = $null
$script:tmpWav      = $null
$script:tmpMp3      = $null
$script:blinkTimer  = $null

# ---- find microphone (Alternative/ASCII device name via dshow) ----
function Get-MicDevice {
    $out = & ffmpeg -list_devices true -f dshow -i dummy 2>&1 | Out-String
    $lines = $out -split "`n"
    foreach ($line in $lines) {
        if ($line -match 'Alternative name\s+"([^"]+)"') {
            $alt = $matches[1]
            Write-Log "Mic device: $alt"
            return $alt
        }
    }
    Write-Log "WARN: no mic Alternative name found, using 'Microphone'"
    return "Microphone"
}

function Start-Recording {
    $script:tmpWav = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.wav'
    $script:tmpMp3 = Join-Path $DESKTOP ("nota_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".mp3")

    $mic = Get-MicDevice
    $args = @(
        "-y", "-f", "dshow", "-i", "audio=`"$mic`"",
        "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
        $script:tmpWav
    )
    Write-Log "START recording -> $($script:tmpWav)"

    $psi = New-Object System.Diagnostics.ProcessStartInfo("ffmpeg", ($args -join " "))
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError  = $false
    $psi.CreateNoWindow         = $true
    $script:ffmpegProc = [System.Diagnostics.Process]::Start($psi)

    # blink icon while recording
    $script:blinkTimer = New-Object System.Windows.Forms.Timer
    $script:blinkTimer.Interval = 500
    $blink = $false
    $script:blinkTimer.Add_Tick({
        $blink = -not $blink
        $tray.Icon = if ($blink) { $iconRed } else { New-Icon ([System.Drawing.Color]::FromArgb(255,100,100)) $true }
    })
    $script:blinkTimer.Start()
    $tray.Text = "GrabadorIA — GRABANDO..."
    $tray.BalloonTipTitle = "GrabadorIA"
    $tray.BalloonTipText  = "Grabando... Clic para parar."
    $tray.ShowBalloonTip(2000)
}

function Stop-Recording {
    if ($script:blinkTimer) { $script:blinkTimer.Stop(); $script:blinkTimer.Dispose(); $script:blinkTimer = $null }
    $tray.Icon = $iconYellow
    $tray.Text = "GrabadorIA — procesando..."

    # stop ffmpeg gracefully by sending 'q' via stdin
    if ($script:ffmpegProc -and -not $script:ffmpegProc.HasExited) {
        try { $script:ffmpegProc.StandardInput.WriteLine("q"); $script:ffmpegProc.WaitForExit(8000) } catch {}
        if (-not $script:ffmpegProc.HasExited) { $script:ffmpegProc.Kill() }
    }
    Write-Log "STOP recording. wav size=$(if(Test-Path $script:tmpWav){(Get-Item $script:tmpWav).Length}else{0}) bytes"

    # convert to mp3 for desktop archive
    & ffmpeg -y -i $script:tmpWav -codec:a libmp3lame -q:a 4 $script:tmpMp3 2>&1 | Out-Null

    # transcribe with whisper.cpp (GPU, large-v3, spanish)
    Write-Log "Transcribing with whisper.cpp..."
    $wArgs = @("-m", $MODEL_PATH, "-f", $script:tmpWav, "-l", $Language, "-otxt", "--no-timestamps")
    $result = & $WHISPER_EXE @wArgs 2>&1
    Write-Log "whisper result: $($result | Select-Object -Last 5 | Out-String)"

    $txtFile = $script:tmpWav -replace '\.wav$', '.wav.txt'
    $text = if (Test-Path $txtFile) {
        (Get-Content $txtFile -Encoding UTF8 -Raw).Trim()
    } else {
        $result | Where-Object { $_ -notmatch '^\[' } | Select-Object -Last 10 | Out-String | ForEach-Object { $_.Trim() }
    }

    # copy to clipboard
    if ($text) {
        Set-Clipboard -Value $text
        Write-Log "Copied to clipboard: $($text.Substring(0, [Math]::Min(80, $text.Length)))..."
        $preview = if ($text.Length -gt 80) { $text.Substring(0, 80) + "..." } else { $text }
        $tray.Icon = $iconGreen
        $tray.Text = "GrabadorIA — listo"
        $tray.BalloonTipTitle = "Transcripcion copiada al portapapeles"
        $tray.BalloonTipText  = $preview
        $tray.ShowBalloonTip(4000)
        # back to red after 3s
        $resetTimer = New-Object System.Windows.Forms.Timer
        $resetTimer.Interval = 3000
        $resetTimer.Add_Tick({ $tray.Icon = $iconRed; $resetTimer.Stop(); $resetTimer.Dispose() })
        $resetTimer.Start()
    } else {
        Write-Log "WARN: empty transcription"
        $tray.Icon = $iconRed
        $tray.BalloonTipTitle = "GrabadorIA"
        $tray.BalloonTipText  = "Transcripcion vacia. Revisa grabador.log."
        $tray.ShowBalloonTip(3000)
    }

    # cleanup temp wav and txt
    foreach ($f in @($script:tmpWav, $txtFile)) { try { if (Test-Path $f) { Remove-Item $f -Force } } catch {} }
}

function Toggle-Recording {
    if ($script:recording) {
        $script:recording = $false
        Stop-Recording
    } else {
        $script:recording = $true
        Start-Recording
    }
}

$tray.Add_MouseClick({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Toggle-Recording } })
$menuRecord.Add_Click({ Toggle-Recording })
$menuExit.Add_Click({
    if ($script:recording) { $script:recording = $false; Stop-Recording }
    $tray.Visible = $false
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

Write-Log "GrabadorIA started. whisper=$WHISPER_EXE model=$MODEL_PATH"
[System.Windows.Forms.Application]::Run()
$mutex.ReleaseMutex()
