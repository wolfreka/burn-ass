#!/usr/bin/env bash
# burn-ass.sh | FFmpeg 2-pass ABR hard-sub (ASS -> burn-in) for Linux/macOS
# 使用系统安装的 ffmpeg/ffprobe
# - Ubuntu/Debian: sudo apt install ffmpeg
# - CentOS/RHEL:  sudo yum install ffmpeg
# - macOS:        brew install ffmpeg

set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }
abs() { perl -MCwd -e 'print Cwd::abs_path(shift)' "$1"; }

# ---- 使用系统安装的 ffmpeg/ffprobe ----
FFMPEG="ffmpeg"
FFPROBE="ffprobe"

need "$FFMPEG"
need "$FFPROBE"

IN=""
ASS=""
OUT=""
PRESET="slow"
BUF_FACTOR=2
HEVC=0
FONTSDIR=""
BATCH_DIR=""
USE_VBV=0   # 0 = closer to source size, 1 = VBV constrained

print_help() {
cat <<EOF
Usage:
  单文件:
    $(basename "$0") -i input.mp4 -s subtitle.ass [-o output.mp4]
                     [--hevc] [--preset slow|slower|veryslow]
                     [--fontsdir /path/to/fonts] [--vbv] [--buf-factor N]

  批量模式 (同目录下 foo.mp4 + foo.ass -> foo.hardsub.mp4):
    $(basename "$0") -D /path/to/dir [options]
EOF
}

while (( "$#" )); do
  case "$1" in
    -i|--in)       IN="${2-}"; shift 2;;
    -s|--sub)      ASS="${2-}"; shift 2;;
    -o|--out)      OUT="${2-}"; shift 2;;
    -D|--dir)      BATCH_DIR="${2-}"; shift 2;;
    --hevc)        HEVC=1; shift;;
    --preset)      PRESET="${2-}"; shift 2;;
    --fontsdir)    FONTSDIR="${2-}"; shift 2;;
    --vbv)         USE_VBV=1; shift;;
    --buf-factor)  BUF_FACTOR="${2-}"; shift 2;;
    -h|--help)     print_help; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

escape_for_filter() {
  local s="$1"
  s="${s//:/\\:}"
  s="${s//\'/\\\'}"
  printf "%s" "$s"
}

get_video_bitrate_k() {
  local in="$1"
  local vbr tbr abr_sum a
  vbr="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=bit_rate \
        -of default=nw=1:nk=1 "$in" || true)"
  if [[ -z "$vbr" || "$vbr" == "N/A" || "$vbr" -le 0 ]]; then
    tbr="$("$FFPROBE" -v error -show_entries format=bit_rate \
          -of default=nw=1:nk=1 "$in" || true)"
    abr_sum=0
    while IFS= read -r a; do
      [[ -n "$a" && "$a" != "N/A" ]] && abr_sum=$((abr_sum + a))
    done < <("$FFPROBE" -v error -select_streams a -show_entries stream=bit_rate \
              -of default=nw=1:nk=1 "$in" || true)
    if [[ -n "$tbr" && "$tbr" -gt 0 ]]; then
      vbr=$((tbr - abr_sum))
    fi
  fi
  [[ -z "$vbr" || "$vbr" -le 0 ]] && vbr=5000000  # fallback 5 Mbps
  python3 - <<PY
print(round($vbr/1000))
PY
}

encode_one() {
  local in="$1" ass="$2" out="$3" preset="$4" use_vbv="$5" buf_factor="$6" hevc="$7" fontsdir="$8"

  [[ -f "$in" ]]  || die "Input not found: $in"
  [[ -f "$ass" ]] || die "ASS not found: $ass"

  local dir base passlog codec
  dir="$(dirname "$in")"
  base="$(basename "$in")"
  [[ -z "$out" ]] && out="${dir}/${base%.*}.hardsub.mp4"

  codec="libx264"
  (( hevc == 1 )) && codec="libx265"

  local vbr_k buf_k
  vbr_k="$(get_video_bitrate_k "$in")"
  buf_k=$(( vbr_k * (buf_factor > 0 ? buf_factor : 2) ))

  echo "==> Target video bitrate: ${vbr_k} kb/s; buffer: ${buf_k} kb"
  echo "==> Codec: $codec; Preset: $preset"
  [[ -n "$fontsdir" ]] && echo "==> fontsdir: $fontsdir"

  local ass_abs fonts_arg filter
  ass_abs="$(abs "$ass")"
  filter="subtitles='$(escape_for_filter "$ass_abs")'"
  if [[ -n "$fontsdir" ]]; then
    fonts_arg="$(abs "$fontsdir")"
    fonts_arg="$(escape_for_filter "$fontsarg")"
    filter+=":fontsdir='${fontsarg}'"
  fi

  passlog="${out%.*}.ffmpeg2pass"
  if (( use_vbv == 1 )); then
    common=(-hide_banner -stats -loglevel warning
            -vf "$filter"
            -c:v "$codec" -b:v "${vbr_k}k" -maxrate "${vbr_k}k" -bufsize "${buf_k}k"
            -preset "$preset" -passlogfile "$passlog")
  else
    common=(-hide_banner -stats -loglevel warning
            -vf "$filter"
            -c:v "$codec" -b:v "${vbr_k}k"
            -preset "$preset" -passlogfile "$passlog")
  fi

  echo "=== Pass 1/2 ==="
  "$FFMPEG" -y -i "$in" "${common[@]}" -pass 1 -an -sn -f mp4 /dev/null

  echo "=== Pass 2/2 ==="
  "$FFMPEG" -i "$in"  "${common[@]}" -pass 2 -c:a copy -sn -movflags +faststart "$out"

  rm -f "${passlog}-0.log" "${passlog}.log" ffmpeg2pass*.log* 2>/dev/null || true

  if [[ -f "$out" ]]; then
    echo "Done ✓  Output: $out"
    du -h "$out" | awk '{print "Size:", $1}'
  else
    die "FFmpeg finished without producing output."
  fi
}

if [[ -n "$BATCH_DIR" ]]; then
  dir="$(abs "$BATCH_DIR")"
  [[ -d "$dir" ]] || die "Not a directory: $dir"
  shopt -s nullglob
  mapfile -t vids < <(find "$dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' \) | sort)
  (( ${#vids[@]} == 0 )) && die "No video files in $dir"

  for v in "${vids[@]}"; do
    base="${v##*/}"
    stem="${base%.*}"
    s1="${dir}/${stem}.ass"
    if [[ -f "$s1" ]]; then
      echo
      echo ">>> Processing: $base + ${stem}.ass"
      encode_one "$v" "$s1" "" "$PRESET" "$USE_VBV" "$BUF_FACTOR" "$HEVC" "$FONTSDIR"
    else
      echo "Skip (no .ass): $base"
    fi
  done
  exit 0
fi

[[ -n "$IN" && -n "$ASS" ]] || { print_help; die "Need -i INPUT and -s SUB"; }
encode_one "$IN" "$ASS" "$OUT" "$PRESET" "$USE_VBV" "$BUF_FACTOR" "$HEVC" "$FONTSDIR"
