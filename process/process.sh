#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh
# vagrant ssh -c "/vagrant/process/process.sh [-f] [-o]"

ref_dir=/vagrant/reference
img_dir=/images
out_dir=/vagrant/output
bak_dir=$out_dir/backup
tmp_dir=/tmp/process

# Parse CLI options.
while getopts "fo" opt; do
  case "$opt" in
  f) force=1 ;;
  o) once=1 ;;
  esac
done

shopt -s extglob nullglob

# Create directories if necessary.
[[ -d "$out_dir" ]] || mkdir -p "$out_dir"
[[ -d "$bak_dir" ]] || mkdir -p "$bak_dir"
[[ -d "$tmp_dir" ]] || mkdir -p "$tmp_dir"

# Join array.
function join { local IFS="$1"; shift; echo "$*"; }
# Parse number part from Screenshot_0000.bmp.
function image_num() { echo "$1" | sed -r 's/[^0-9]*([0-9]+).*/\1/'; }
# Add suffix to filename, before extension.
function suffix() { echo "$2" | sed -r "s/(\.[^.]+)\$/$1\1/"; }
# Get filename.prev.ext from filename.ext
function prev() { suffix .last "$1"; }
# Move filename.ext to filename.prev.ext
function mv_prev() { mv "$1" "$(prev "$1")"; }
# Move file to backup dir, adding file modification date.
function bak() {
  local file="$(basename "$1")"
  local timestamp="$(date -u +"%Y-%m-%d %H.%M.%S" -r "$1")"
  mv "$1" "$bak_dir/$(suffix " $timestamp" "$file")"
}
# Parse system name from E:D logs.
function system_name() {
  [[ ! -d "/logs" ]] && "NONE" && return 1
  local log="$(ls -t /logs/netLog.*.log | head -1)"
  cat $log | sed -nr 's/.*System:[0-9]+\(([^)]+)\).*/\1/p' | tail -1
}
# Prep OCR word replacements.
ocr_fixes=
function get_ocr_fixes() {
  local line parts
  while read line; do
    [[ "$line" ]] || continue
    parts=($line)
    ocr_fixes="$ocr_fixes;s/\b${parts[0]}\b/${parts[@]:1}/"
  done <"$ref_dir/ocr_fixes.txt"
  ocr_fixes="${ocr_fixes#;}"
}
# Fix (?) bad OCR.
function fix_ocr() {
  echo "$1" | sed -r "$ocr_fixes" | tr -dc "[:alnum:][:blank:]"
}

#############
## UNKNOWN ##
#############

function unknown() { echo "unknown image type, skipping"; }

############
## MARKET ##
############

function market() {
  local k match_threshold result market_match
  local station_name_parsed station_name_file station_name
  match_threshold=2000
  cd "$tmp_dir"
  convert "$img_dir/$img.bmp" $(
    for k in "${!market_crops[@]}"; do
      echo \( +clone -crop ${market_crops[$k]} +repage \
        -write $k.png \
        -sigmoidal-contrast 10,40% -type grayscale -write ${k}_ocr.png \
        +delete \)
    done
  ) null:
  # Abort if market_header crop is not actually from a market image.
  result="$(compare -metric RMSE market_header_ocr.png "$ref_dir/market_header_ocr.png" null: 2>&1)"
  if echo "$result" | awk "{exit \$1 < $match_threshold ? 0 : 1}"; then
    echo "market"
  else
    return 1
  fi
  # Test if station_name crop matches that of the last market.
  market_match=
  if [[ "$(find "$(prev station_name_ocr.png)" -mmin -1 2>/dev/null)" ]]; then
    result="$(compare -metric RMSE station_name_ocr.png "$(prev station_name_ocr.png)" null: 2>&1)"
    if echo "$result" | awk "{exit \$1 < $match_threshold ? 0 : 1}"; then
      echo "- last market match [$result]"
      market_match=1
    else
      echo "- last market nomatch [$result]"
    fi
  else
    echo "- no last market within 1 min"
  fi
  # Get station name.
  if [[ "$market_match" ]]; then
    station_name="$(cat "$(prev station_name.txt)" 2>/dev/null)"
    echo "- station name: $station_name"
  else
    # Good luck with the OCR.
    tesseract station_name_ocr.png station_name -psm 7 >/dev/null
    station_name_parsed="$(<station_name.txt)"
    station_name="$(fix_ocr "$station_name_parsed")"
    echo "$station_name" > station_name.txt
    mv_prev station_name.txt
    echo "- station name: $station_name [$station_name_parsed]"
  fi
  [[ ! "$station_name" ]] && echo "- unable to parse station name" && return
  if [[ "$market_match" ]]; then
    # Continue existing market image.
    market_continue "$station_name"
  else
    # Start new market image.
    market_new "$station_name"
  fi
  # Make backups of market crops.
  for k in "${!market_crops[@]}"; do mv_prev $k.png; mv_prev ${k}_ocr.png; done
  echo "- done"
}

function market_new() {
  local joined="$out_dir/$1.png"
  echo "- new station"
  [[ -e "$joined" ]] && bak "$joined"
  convert -append station_name.png station_info.png market_header.png market_data.png "$joined"
}

function market_continue() {
  local result offset
  local joined="$out_dir/$1.png"
  echo "- continue station"
  result="$(compare -metric RMSE -subimage-search "$joined" market_slice.png null: 2>&1)"
  offset=$(echo "$result" | sed 's/.*,//')
  if (( $offset > 0 )); then
    echo "- slice match at $offset [$result]"
    convert "$joined" -page +0+$offset market_data.png -layers mosaic "$joined"
  else
    echo "- slice nomatch"
  fi
}

declare -A market_crops
function market_crops_init() {
  # Based on 1920x1200
  local x=95 w=1190 k a
  market_crops=(
    [station_name]="132 36"
    [station_info]="168 62"
    [market_header]="230 79"
    [market_data]="310 713"
    [market_slice]="310 50"
  )
  for k in "${!market_crops[@]}"; do
    a=(${market_crops[$k]})
    market_crops[$k]=${w}x${a[1]}+${x}+${a[0]}
  done
}
market_crops_init

##########
## MAIN ##
##########

function process() {
  local images_new f img
  # Get new images.
  cd "$img_dir"
  images_new=( Screenshot_!($(join \| "${images[@]}")).bmp )

  # Abort if no new images found.
  (( ${#images_new[@]} == 0 )) && return 1

  # Per-run initialization.
  get_ocr_fixes

  # Process images.
  for f in "${images_new[@]}"; do
    img=$(basename "$f" .bmp)
    echo -n "$img: "
    # Process image.
    market || \
    unknown
    # Store image number to prevent re-processing.
    images+=($(image_num "$f"))
  done
}

# Get initial image numbers.
if [[ "$force" ]]; then
  images=()
else
  cd "$img_dir"
  images=(Screenshot_*.bmp)
  for i in "${!images[@]}"; do images[$i]=$(image_num "${images[$i]}"); done
  echo "Ignoring ${#images[@]} existing image(s)"
fi

echo "Ready"

while true; do
  process
  [[ "$once" ]] && exit
  sleep 3
done
