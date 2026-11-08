# download-tiktok.ps1 - one command downloads one TikTok video on
# Windows: info first (title / formats), then the download via
# omniget-cli, then an ffprobe verification of the landed file.
# The Windows counterpart of tiktok/download-tiktok.sh.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\download-tiktok.ps1 "<TikTok URL>" [-OutputDir <dir>]
#
# Notes:
#   - Short links (vt.tiktok.com) resolve directly.
#   - A proxy is honored via the HTTPS_PROXY environment variable when
#     set (personal Windows machines usually have direct egress and
#     need none). The value is never printed.
#   - If omniget-cli fails twice, the pinned yt-dlp.exe runs directly
#     as the fallback engine and the output says so.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url,
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'common.ps1')
$paths = Get-KitPaths

try {
    $cli = Join-Path $paths.OmnigetDir 'omniget-cli.exe'
    if (-not (Test-Path $cli)) { Die 'omniget-cli not found - run install-omniget.ps1 first' }
    $ytdlp = Join-Path $paths.OmnigetDir 'yt-dlp.exe'

    if (-not $OutputDir) {
        $OutputDir = Get-DownloadsDir
    }
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

    $proxyArgs = @()
    $proxy = $env:HTTPS_PROXY
    if (-not $proxy) { $proxy = $env:https_proxy }
    if ($proxy) { $proxyArgs = @('--proxy', $proxy) }

    $ffprobePath = $null
    $ffprobeCmd = Get-Command 'ffprobe.exe' -ErrorAction SilentlyContinue
    if ($ffprobeCmd) { $ffprobePath = $ffprobeCmd.Source }
    if (-not $ffprobePath) { $ffprobePath = Find-FirstFile $paths.FfmpegDir 'ffprobe.exe' }

    function Find-NewestVideo {
        Get-ChildItem $OutputDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.mp4', '.mkv', '.webm' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }

    $before = Find-NewestVideo
    $beforeTime = $null
    if ($before) { $beforeTime = $before.LastWriteTime }

    Write-Host '--- info ---'
    & $cli info $Url @proxyArgs | Out-Host

    Write-Host '--- download ---'
    $ok = $false
    for ($attempt = 1; $attempt -le 2 -and -not $ok; $attempt++) {
        & $cli download $Url -o $OutputDir @proxyArgs | Out-Host
        $ok = ($LASTEXITCODE -eq 0)
        if (-not $ok -and $attempt -eq 1) { Write-Warn 'download failed once; retrying the same command ...' }
    }

    $file = Find-NewestVideo
    if ((-not $ok) -or (-not $file) -or ($beforeTime -and $file.LastWriteTime -le $beforeTime)) {
        if (Test-Path $ytdlp) {
            Write-Warn 'omniget-cli did not produce a file; falling back to the pinned yt-dlp.exe directly ...'
            & $ytdlp -o (Join-Path $OutputDir 'tiktok_%(uploader_id)s_%(id)s.%(ext)s') $Url | Out-Host
            if ($LASTEXITCODE -ne 0) { Die 'download failed with both omniget-cli and yt-dlp.exe' }
            $file = Find-NewestVideo
        } else {
            Die 'download failed and no yt-dlp.exe fallback is installed'
        }
    }
    if (-not $file) { Die 'download produced no video file' }

    Write-Host '--- verify ---'
    if ($ffprobePath) {
        & $ffprobePath -v error -show_entries stream=codec_name,width,height -show_entries format=duration `
            -of default=noprint_wrappers=1 $file.FullName | Out-Host
    } else {
        Write-Warn 'ffprobe not found; skipped the probe (install FFmpeg via the kit installer)'
    }
    Write-Host "Downloaded: $($file.FullName)"
    Write-Host 'Next (archive + frame evidence):'
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSScriptRoot\prepare-reference.ps1`" `"$($file.FullName)`" <english-project-name>"
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
