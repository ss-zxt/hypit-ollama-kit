# video-draft.ps1 - the kit's local "assistant" pipeline on Windows.
#
# Give it a TikTok URL or a local video file. It will:
#   1. download the video (URLs only, via tiktok\download-tiktok.ps1)
#   2. archive it and cut 0.5s frame grids (tiktok\prepare-reference.ps1)
#   3. feed every grid image to the local vision model in Ollama and
#      collect per-grid timeline notes (the model must be a VL model,
#      e.g. qwen3-vl:4b-instruct - a text-only model cannot see frames)
#   4. ask the model to merge the notes into a shot-breakdown draft
#   5. write DRAFT_NOTES.md into the project folder
#
# The output is a DRAFT: local small models miss details and sometimes
# misread actions. Use it as the raw material for a human / stronger
# model to write the final prompt pack - that division of labor is the
# kit's standing rule.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\video-draft.ps1 "<TikTok URL>"
#   powershell -ExecutionPolicy Bypass -File .\video-draft.ps1 "C:\path\video.mp4" [-ProjectName name] [-Model qwen3-vl:4b-instruct]

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Source,
    [string]$ProjectName,
    [string]$Model,
    [int]$MaxGrids = 12
)

$ErrorActionPreference = 'Stop'
$WindowsDir = Split-Path $PSScriptRoot -Parent
. (Join-Path $WindowsDir 'common.ps1')
$paths = Get-KitPaths

try {
    # Model: explicit > recorded by the installer > VL default.
    if (-not $Model) { $Model = Get-RecordedModel }
    if (-not $Model) { $Model = 'qwen3-vl:4b-instruct' }
    if ($Model -notmatch 'vl|vision|llava|minicpm-v') {
        Write-Warn "模型 '$Model' 看起来不是视觉模型, 帧图可能被忽略或拒绝; 建议用 VL 模型 (如 qwen3-vl:4b-instruct)。"
    }

    # Make sure the local Ollama API is up before doing any work.
    [void](Start-OllamaServer)
    Write-Info "助手模型: $Model (接口 $($paths.OllamaApi))"

    # ------------------------------------------------------------ 1. get the file
    $videoFile = $null
    if ($Source -match '^https?://') {
        Write-Log '下载参考视频'
        # Do NOT parse the child's console text: download-tiktok.ps1
        # prints its "Downloaded:" line with Write-Host, which renders
        # to the host and never enters a captured pipeline (field bug
        # 2026-11-08: download succeeded, the parse found nothing).
        # Locate the result by snapshotting the download folder instead.
        $dlDir = Get-DownloadsDir
        $before = @{}
        if (Test-Path $dlDir) {
            Get-ChildItem $dlDir -File | ForEach-Object { $before[$_.FullName] = $_.LastWriteTimeUtc }
        }
        $startUtc = [DateTime]::UtcNow
        & (Join-Path $WindowsDir 'tiktok\download-tiktok.ps1') $Source | Out-Host
        $fresh = @(Get-ChildItem $dlDir -File -ErrorAction SilentlyContinue | Where-Object {
            (-not $before.ContainsKey($_.FullName)) -or ($_.LastWriteTimeUtc -gt $before[$_.FullName])
        } | Where-Object { $_.LastWriteTimeUtc -ge $startUtc.AddMinutes(-2) } |
            Sort-Object LastWriteTimeUtc -Descending)
        if ($fresh.Count -gt 0) { $videoFile = $fresh[0].FullName }
        if (-not $videoFile -or -not (Test-Path $videoFile)) { Die "下载没有在 $dlDir 产生新文件" }
        Write-Info "已下载文件: $videoFile"
    } else {
        if (-not (Test-Path $Source)) { Die "找不到文件: $Source" }
        $videoFile = (Resolve-Path $Source).Path
    }

    if (-not $ProjectName) {
        $base = [IO.Path]::GetFileNameWithoutExtension($videoFile) -replace '[^A-Za-z0-9_-]', '-'
        if (-not $base) { $base = 'video' }
        $ProjectName = "$base-draft"
    }

    # ------------------------------------------------------------ 2. archive + frame grids
    Write-Log '准备项目 (归档 + 拆帧拼图)'
    & (Join-Path $WindowsDir 'tiktok\prepare-reference.ps1') $videoFile $ProjectName | Out-Host
    # The child has its own try/catch + exit; check it, or a child
    # failure surfaces later as a misleading "no frame grids" error
    # (field bug 2026-11-08).
    if ($LASTEXITCODE -ne 0) { Die '拆帧失败 —— 看上面那行红字' }

    $projectDir = Join-Path (Get-ProjectsRoot) $ProjectName
    $tileDir = Join-Path $projectDir 'evidence\tiles'
    $grids = @(Get-ChildItem $tileDir -File -ErrorAction Stop |
        Where-Object { $_.Extension -in '.png', '.jpg', '.jpeg' } |
        Sort-Object Name | Select-Object -First $MaxGrids)
    if ($grids.Count -eq 0) { Die "在 $tileDir 没找到帧拼图" }
    Write-Info "共 $($grids.Count) 张拼图待读取"

    # ------------------------------------------------------------ 3. per-grid vision notes
    $gridPrompt = 'This is a frame grid sampled from a short video, one frame every 0.5 seconds, in time order (left to right, top to bottom). Describe the frames one by one: what is in the picture, how the subject moves or changes, and any scene or camera changes. Write ONLY what you can actually see; do not invent anything. Answer in Chinese, as concise timeline notes.'
    $notes = @()
    $notes += "# DRAFT_NOTES —— 本地助手初稿"
    $notes += ""
    $notes += "来源: $Source"
    $notes += "模型: $Model"
    $notes += "生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $notes += ""
    $notes += "## 逐拼图笔记"
    $i = 0
    foreach ($grid in $grids) {
        $i++
        Write-Info "正在读取拼图 $i/$($grids.Count): $($grid.Name) ..."
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($grid.FullName))
        $body = @{
            model    = $Model
            messages = @(@{ role = 'user'; content = $gridPrompt; images = @($b64) })
            stream   = $false
            think    = $false
        } | ConvertTo-Json -Depth 6
        $resp = Invoke-RestMethod -Uri "$($paths.OllamaApi)/api/chat" -Method Post -Body $body `
            -ContentType 'application/json' -TimeoutSec 900 -ErrorAction Stop
        $text = [string]$resp.message.content
        $notes += ""
        $notes += "### $($grid.Name)"
        $notes += $text.Trim()
        Write-Info "拼图 $i 读完"
    }

    # ------------------------------------------------------------ 4. merged breakdown draft
    Write-Log '汇总成拆解初稿'
    $allNotes = ($notes -join "`n")
    $mergePrompt = "Below are per-grid timeline notes of a short video, written by a vision model. Merge them into ONE shot-breakdown draft in Chinese: combine consecutive frames into continuous actions in time order, mark likely shot boundaries, and for each segment add one draft sentence that could seed a video-generation prompt. Keep only what the notes support; do not invent new content.`n`n$allNotes"
    $body2 = @{
        model    = $Model
        messages = @(@{ role = 'user'; content = $mergePrompt })
        stream   = $false
        think    = $false
        options  = @{ num_predict = 1200 }
    } | ConvertTo-Json -Depth 6
    $resp2 = Invoke-RestMethod -Uri "$($paths.OllamaApi)/api/chat" -Method Post -Body $body2 `
        -ContentType 'application/json' -TimeoutSec 900 -ErrorAction Stop
    $notes += ""
    $notes += "## 汇总拆解草案"
    $notes += ""
    $notes += ([string]$resp2.message.content).Trim()

    # ------------------------------------------------------------ 5. save
    $outFile = Join-Path $projectDir 'DRAFT_NOTES.md'
    $notes | Set-Content -Path $outFile -Encoding UTF8
    Write-Log '完成'
    Write-Host "初稿已写入: $outFile"
    Write-Host '这是本地模型的第一版初稿 —— 把它发给你的主 AI 或人工, 在初稿上整理成定稿提示词包。'
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
