<#  burn-ass.ps1 | FFmpeg 2-pass ABR hard-sub (ASS -> burn-in), size ~ source
Usage:
  .\burn-ass.ps1 -In "D:\video_temp\input.mp4" -Ass "D:\video_temp\subtitle.ass"
  .\burn-ass.ps1 -In "in.mp4" -Ass "sub.ass" -Out "out.mp4"
  .\burn-ass.ps1 -In "in.mp4" -Ass "sub.ass" -FontsDir "C:\Windows\Fonts"
  .\burn-ass.ps1 -In "in.mp4" -Ass "sub.ass" -Hevc -Preset slower

Notes:
- Reads source VIDEO bitrate via ffprobe; runs 2-pass ABR to match it.
- Audio is copied; size may differ slightly due to container overhead.
- Subtitles filter uses RELATIVE path (we cd to ASS dir) to avoid drive colon issues.
#>

param(
  [Parameter(Mandatory=$true )][string]$In,
  [Parameter(Mandatory=$true )][string]$Ass,
  [Parameter(Mandatory=$false)][string]$Out = "",
  [Parameter(Mandatory=$false)][string]$Preset = "slow",
  [Parameter(Mandatory=$false)][int]$BufFactor = 2,
  [switch]$Hevc,
  [string]$FontsDir = ""
)

$ErrorActionPreference = "Stop"

# ---- Use ffmpeg/ffprobe under current script folder ----
$FFMPEG  = Join-Path $PSScriptRoot "ffmpeg\ffmpeg.exe"
$FFPROBE = Join-Path $PSScriptRoot "ffmpeg\ffprobe.exe"

function Require-Cmd($path) {
  if (-not (Test-Path $path)) {
    throw "Command not found: $path"
  }
}

Require-Cmd $FFMPEG
Require-Cmd $FFPROBE

if (-not (Test-Path $In))  { throw "Input video not found: $In" }
if (-not (Test-Path $Ass)) { throw "Subtitle file not found: $Ass" }

# Output path
if ([string]::IsNullOrWhiteSpace($Out)) {
  $dir  = Split-Path -Parent $In
  $base = [IO.Path]::GetFileNameWithoutExtension($In)
  $Out  = Join-Path $dir "$base.hardsub.mp4"
}

# --- Read source VIDEO bitrate; fallback: container - sum(audio) ---
$vbr_bps = & $FFPROBE -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$In"
if ([string]::IsNullOrWhiteSpace($vbr_bps) -or $vbr_bps -eq "N/A" -or [int64]$vbr_bps -le 0) {
  $tbr  = & $FFPROBE -v error -show_entries format=bit_rate -of csv=p=0 "$In"
  $abrs = & $FFPROBE -v error -select_streams a -show_entries stream=bit_rate -of csv=p=0 "$In"
  $abr_sum = 0; foreach ($a in $abrs) { $abr_sum += ([int64]$a) }
  $vbr_bps = ([int64]$tbr - $abr_sum)
}
if ([int64]$vbr_bps -le 0) { $vbr_bps = 5000000 } # fallback 5 Mbps

$vbr_k = [int]([math]::Round([double]$vbr_bps / 1000.0))
$buf_k = $vbr_k * [math]::Max(1,$BufFactor)

Write-Host ("Target video bitrate: {0} kb/s; buffer: {1} kb" -f $vbr_k, $buf_k) -ForegroundColor Cyan

# Codec
if ($Hevc) { $codec = "libx265" } else { $codec = "libx264" }

# Passlog (avoid clashes)
$passlog = [IO.Path]::ChangeExtension($Out, ".ffmpeg2pass")

# Build subtitles filter with RELATIVE path
$assDir  = Split-Path -Parent $Ass
$assName = [IO.Path]::GetFileName($Ass)
$filter  = "subtitles='$assName'"

if (-not [string]::IsNullOrWhiteSpace($FontsDir)) {
  if (-not (Test-Path $FontsDir)) { throw "FontsDir not found: $FontsDir" }
  # fontsdir: prefer forward slashes; escape colon
  $fontsEsc = ($FontsDir -replace '\\','/').Replace(':','\:')
  $filter  += ":fontsdir='$fontsEsc'"
}

# --- Two presets for rate control ---
# 1) With VBV (more constrained, may be below target avg)
$commonArgsVbv = @(
  "-hide_banner","-stats","-loglevel","warning",
  "-vf",$filter,
  "-c:v",$codec,
  "-b:v","${vbr_k}k","-maxrate","${vbr_k}k","-bufsize","${buf_k}k",
  "-preset",$Preset,"-passlogfile",$passlog
)

# 2) No VBV (usually closer to target size/avg bitrate)
$commonArgsNoVbv = @(
  "-hide_banner","-stats","-loglevel","warning",
  "-vf",$filter,
  "-c:v",$codec,
  "-b:v","${vbr_k}k",
  "-preset",$Preset,"-passlogfile",$passlog
)

# Choose which set to use (recommend NoVbv for matching source size)
$argsToUse = $commonArgsNoVbv

Push-Location $assDir
try {
  Write-Host "`n=== Pass 1/2 ===" -ForegroundColor Yellow
  & $FFMPEG -y -i "$In" @argsToUse -pass 1 -an -sn -f mp4 NUL

  Write-Host "`n=== Pass 2/2 ===" -ForegroundColor Yellow
  & $FFMPEG -i "$In" @argsToUse -pass 2 -c:a copy -sn -movflags +faststart "$Out"
}
finally {
  Pop-Location
}

# --- Cleanup pass logs (robust) ---
$cleanup = @("$passlog-0.log", "$passlog.log")
foreach ($p in $cleanup) {
  if ($p -and (Test-Path -LiteralPath $p)) {
    Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
  }
}
Get-ChildItem -ErrorAction SilentlyContinue -Filter "ffmpeg2pass*.log*" |
  Remove-Item -Force -ErrorAction SilentlyContinue

# Report output info
if (Test-Path $Out) {
  $fi = Get-Item $Out
  Write-Host "`nDone!  Output:" -ForegroundColor Green
  Write-Host $fi.FullName
  "{0:N2} MB" -f ($fi.Length/1MB) | Write-Host
} else {
  throw "FFmpeg finished without producing output."
}
