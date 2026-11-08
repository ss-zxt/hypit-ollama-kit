# prepare-reference.ps1 - archive a downloaded TikTok reference video
# into a standard decomposition project and generate the frame
# evidence. The Windows counterpart of tiktok/prepare-reference.sh.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\prepare-reference.ps1 <video-file> <project-name>
#
# Creates %USERPROFILE%\workspace\hypit-projects\<project-name>\ with:
#   references\source.mp4   the original, renamed
#   references\PROBE.txt    specs + visual-change candidates + audio levels
#   evidence\tiles\         0.5s time-labeled frame grids (hypit media tiles)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$VideoFile,
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ProjectName
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'common.ps1')

try {
    if (-not (Test-Path $VideoFile)) { Die "file not found: $VideoFile" }

    $hypitCmd = Join-Path $script:HypitPrefix 'hypit.cmd'
    if (-not (Test-Path $hypitCmd)) {
        $cmd = Get-Command 'hypit.cmd' -ErrorAction SilentlyContinue
        if ($cmd) { $hypitCmd = $cmd.Source } else { Die 'hypit CLI not found - run the kit installer first' }
    }
    $ffprobePath = $null
    $probeCmd = Get-Command 'ffprobe.exe' -ErrorAction SilentlyContinue
    if ($probeCmd) { $ffprobePath = $probeCmd.Source }
    if (-not $ffprobePath) {
        $ffprobePath = Find-FirstFile $script:FfmpegDir 'ffprobe.exe'
        if (-not $ffprobePath) { Die 'ffprobe (FFmpeg) is required' }
    }
    $ffmpegPath = $null
    $ffmpegCmd = Get-Command 'ffmpeg.exe' -ErrorAction SilentlyContinue
    if ($ffmpegCmd) { $ffmpegPath = $ffmpegCmd.Source }
    if (-not $ffmpegPath) {
        $ffmpegPath = Find-FirstFile $script:FfmpegDir 'ffmpeg.exe'
        if (-not $ffmpegPath) { Die 'ffmpeg is required' }
    }

    $project = Join-Path $env:USERPROFILE "workspace\hypit-projects\$ProjectName"
    $refDir  = Join-Path $project 'references'
    $tileDir = Join-Path $project 'evidence\tiles'
    New-Item -ItemType Directory -Path $refDir -Force | Out-Null
    New-Item -ItemType Directory -Path $tileDir -Force | Out-Null

    $video = Join-Path $refDir 'source.mp4'
    Copy-Item $VideoFile $video -Force

    $duration = & $ffprobePath -v error -show_entries format=duration -of csv=p=0 $video
    $end = [math]::Max(0.1, [double]$duration - 0.1)

    $probe = @()
    $probe += 'file: references/source.mp4'
    $probe += "downloaded_from: $VideoFile"
    $probe += '--- probe ---'
    $probe += (& $hypitCmd media probe $video 2>&1 | ForEach-Object { [string]$_ })
    $probe += '--- boundaries (visual-change candidates, NOT shot labels) ---'
    $bounds = & $hypitCmd media boundaries $video 2>&1 | ForEach-Object { [string]$_ }
    $probe += ($bounds | Select-Object -Last 25)
    $probe += '--- audio levels ---'
    $vol = & $ffmpegPath -i $video -vn -af volumedetect -f null - 2>&1 | ForEach-Object { [string]$_ } |
        Where-Object { $_ -match 'mean_volume|max_volume' }
    $probe += $vol
    $probe | Set-Content -Path (Join-Path $refDir 'PROBE.txt') -Encoding UTF8

    & $hypitCmd media tiles $video --start 0 --end $end --every 0.5 --cell 320 --columns 5 --to $tileDir | Out-Host
    if ($LASTEXITCODE -ne 0) { Die 'hypit media tiles failed' }

    Write-Host "Project ready: $project"
    Write-Host "  references\source.mp4  ($duration s)"
    Write-Host '  references\PROBE.txt'
    Write-Host '  evidence\tiles\ (0.5s grids)'
    Write-Host 'Next: watch the tiles in full, then write references\TIMELINE.md + ANALYSIS.md.'
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
