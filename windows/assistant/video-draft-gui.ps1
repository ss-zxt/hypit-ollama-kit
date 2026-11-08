# video-draft-gui.ps1 - a small Windows Forms front end for the local
# assistant (video-draft.ps1). Paste a TikTok URL (or pick a local
# video file), click Start, watch the pipeline log live, then open the
# finished DRAFT_NOTES.md from the window.
#
# How it works: the worker is the existing video-draft.ps1, started as
# a hidden PowerShell process with its console output redirected to a
# log file; this form tails the log file on a timer. The pipeline code
# itself is unchanged, so the GUI can never diverge from the CLI flow.
#
# Launch via video-draft-gui.bat (or: powershell -STA -File this).

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$workerScript = Join-Path $PSScriptRoot 'video-draft.ps1'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Hypit 本地助手 - 视频拆解初稿'
$form.Size = New-Object System.Drawing.Size(780, 580)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'TikTok 链接，或本地视频文件：'
$lbl.Location = New-Object System.Drawing.Point(12, 14)
$lbl.AutoSize = $true
$form.Controls.Add($lbl)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(12, 36)
$txtSource.Size = New-Object System.Drawing.Size(600, 24)
$txtSource.Anchor = 'Top,Left,Right'
$form.Controls.Add($txtSource)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '选文件...'
$btnBrowse.Location = New-Object System.Drawing.Point(620, 34)
$btnBrowse.Size = New-Object System.Drawing.Size(70, 28)
$btnBrowse.Anchor = 'Top,Right'
$form.Controls.Add($btnBrowse)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = '开始生成初稿'
$btnStart.Location = New-Object System.Drawing.Point(698, 34)
$btnStart.Size = New-Object System.Drawing.Size(54, 28)
$btnStart.Anchor = 'Top,Right'
$form.Controls.Add($btnStart)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = '待开始：粘贴链接后点「开始生成初稿」。读图较慢（纯 CPU），请耐心等。'
$lblStatus.Location = New-Object System.Drawing.Point(12, 68)
$lblStatus.AutoSize = $true
$form.Controls.Add($lblStatus)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = '停止'
$btnStop.Location = New-Object System.Drawing.Point(698, 62)
$btnStop.Size = New-Object System.Drawing.Size(54, 26)
$btnStop.Anchor = 'Top,Right'
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtLog.Location = New-Object System.Drawing.Point(12, 94)
$txtLog.Size = New-Object System.Drawing.Size(740, 396)
$txtLog.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($txtLog)

$btnOpenDraft = New-Object System.Windows.Forms.Button
$btnOpenDraft.Text = '打开初稿 DRAFT_NOTES.md'
$btnOpenDraft.Location = New-Object System.Drawing.Point(12, 502)
$btnOpenDraft.Size = New-Object System.Drawing.Size(190, 30)
$btnOpenDraft.Anchor = 'Bottom,Left'
$btnOpenDraft.Enabled = $false
$form.Controls.Add($btnOpenDraft)

$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = '打开项目文件夹'
$btnOpenFolder.Location = New-Object System.Drawing.Point(212, 502)
$btnOpenFolder.Size = New-Object System.Drawing.Size(130, 30)
$btnOpenFolder.Anchor = 'Bottom,Left'
$btnOpenFolder.Enabled = $false
$form.Controls.Add($btnOpenFolder)

# ------------------------------------------------------------- state
$script:worker = $null
$script:logFile = $null
$script:errFile = $null
$script:logPos = 0
$script:draftPath = $null
$script:projectDir = $null

function Append-Log {
    param([string]$Text)
    if ($Text) {
        $txtLog.AppendText($Text)
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }
}

function Read-NewLog {
    if (-not $script:logFile -or -not (Test-Path $script:logFile)) { return }
    try {
        $fs = [System.IO.File]::Open($script:logFile, 'Open', 'Read', 'ReadWrite')
        try {
            if ($fs.Length -lt $script:logPos) { $script:logPos = 0 }
            [void]$fs.Seek($script:logPos, 'Begin')
            $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
            $new = $sr.ReadToEnd()
            $script:logPos = $fs.Length
            $sr.Dispose()
        } finally { $fs.Dispose() }
        if ($new) { Append-Log $new }
    } catch { }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 600
$timer.Add_Tick({
    Read-NewLog
    if ($script:worker -and $script:worker.HasExited) {
        $timer.Stop()
        Read-NewLog
        if ($script:errFile -and (Test-Path $script:errFile)) {
            $errText = Get-Content $script:errFile -Raw -ErrorAction SilentlyContinue
            if ($errText) { Append-Log "`r`n$errText" }
        }
        $code = $script:worker.ExitCode
        $script:worker = $null
        $btnStart.Enabled = $true
        $btnStop.Enabled = $false
        # Find the finished draft path in the log.
        $m = [regex]::Match($txtLog.Text, '初稿已写入: (.+)')
        if ($m.Success) {
            $script:draftPath = $m.Groups[1].Value.Trim()
            $script:projectDir = Split-Path $script:draftPath -Parent
            $btnOpenDraft.Enabled = $true
            $btnOpenFolder.Enabled = $true
        }
        if ($code -eq 0) {
            $lblStatus.Text = '完成！初稿已生成，点下面按钮打开。'
        } else {
            $lblStatus.Text = "已结束（退出码 $code），看日志最后几行找原因。"
        }
    }
})

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = '视频文件 (*.mp4;*.mkv;*.webm;*.mov)|*.mp4;*.mkv;*.webm;*.mov|所有文件 (*.*)|*.*'
    if ($dlg.ShowDialog() -eq 'OK') { $txtSource.Text = $dlg.FileName }
})

$btnStart.Add_Click({
    $src = $txtSource.Text.Trim()
    if (-not $src) {
        [System.Windows.Forms.MessageBox]::Show('先粘贴一个 TikTok 链接，或选一个本地视频文件。', '提示') | Out-Null
        return
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logDir = Join-Path ([System.IO.Path]::GetTempPath()) 'hypit-kit-gui'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $script:logFile = Join-Path $logDir "run-$stamp.log"
    $script:errFile = Join-Path $logDir "run-$stamp.err.log"
    $script:logPos = 0
    $script:draftPath = $null
    $script:projectDir = $null
    $btnOpenDraft.Enabled = $false
    $btnOpenFolder.Enabled = $false
    $txtLog.Clear()
    Append-Log "开始处理: $src`r`n"
    $lblStatus.Text = '运行中...（下载 → 拆帧 → 逐图读取 → 出初稿）'
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$workerScript`" `"$src`""
    $script:worker = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList `
        -RedirectStandardOutput $script:logFile -RedirectStandardError $script:errFile `
        -WindowStyle Hidden -PassThru
    $timer.Start()
})

$btnStop.Add_Click({
    if ($script:worker -and -not $script:worker.HasExited) {
        & taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null
        Append-Log "`r`n（已被你停止）`r`n"
        $lblStatus.Text = '已停止。已经读完的拼图笔记已保存在项目文件里。'
    }
    $timer.Stop()
    $script:worker = $null
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
})

$btnOpenDraft.Add_Click({
    if ($script:draftPath -and (Test-Path $script:draftPath)) {
        Start-Process $script:draftPath
    }
})

$btnOpenFolder.Add_Click({
    if ($script:projectDir -and (Test-Path $script:projectDir)) {
        Start-Process 'explorer.exe' $script:projectDir
    }
})

$form.Add_FormClosing({
    if ($script:worker -and -not $script:worker.HasExited) {
        & taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null
    }
})

[void]$form.ShowDialog()
