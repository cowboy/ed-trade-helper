#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh
# vagrant ssh -c "/vagrant/process/process.sh [-f] [-o]"

ref_dir=/vagrant/reference
img_dir=/images
out_dir=/vagrant/output
bak_dir=$out_dir/backup
tmp_dir=$out_dir/tmp

export TESSDATA_PREFIX=$ref_dir/

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

#############
## UTILITY ##
#############

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

# Do math stuff.
function math() {
  echo "$@" | bc -l
}

# Test that a number ($2) is less than another number ($1)
function below_threshold() {
  echo "$2" | awk "{exit \$1 < $1 ? 0 : 1}"
}

# Parse system name from E:D logs.
function get_system_name() {
  [[ ! -d "/logs" ]] && return 1
  local log="$(ls -t /logs/netLog.*.log | head -1)"
  cat $log | sed -nr 's/.*System:[0-9]+\(([^)]+)\).*/\1/p' | tail -1
}

# Adjust OCR text.
function adjust_ocr() {
  local initial_caps='s/(.*)/\L\1/;s/\b(.)/\U\1/g'
  echo "$1" | sed -r "$initial_caps"
}

#############
## UNKNOWN ##
#############

function unknown() { echo "unknown image type, skipping"; }

############
## MARKET ##
############

# Generate market crop geometries.
rm "$tmp_dir"/* 2>/dev/null
declare -A market_crops
function market_crops_init() {
  local market_x market_w start_y market_h yy hh
  local k a
  local w=${dims[0]} h=${dims[1]}
  if [[ "${w}x${h}" == "1920x1200" ]]; then
    market_x=95; market_w=1190; start_y=132
  elif [[ "${w}x${h}" == "3440x1440" ]]; then
    market_x=567; market_w=1585; start_y=97
  else
    echo "unknown dimensions"
    return 1
  fi
  market_crops=()
  market_h=$(math $market_w / 1.33)
  # market_crops[full]="$start_y $market_h"
  yy=$start_y; hh=$(math $market_h / 24.4)
  market_crops[station_name]="$yy $hh"
  yy=$(math $yy + $hh); hh=$(math $market_h / 14.9)
  market_crops[station_info]="$yy $hh"
  yy=$(math $yy + $hh); hh=$(math $market_h / 11)
  market_crops[market_header]="$yy $hh"
  yy=$(math $yy + $hh); hh=$(math $market_h / 1.25)
  market_crops[market_data]="$yy $hh"
  hh=$(math $hh / 10)
  market_crops[market_slice]="$yy $hh"
  for k in "${!market_crops[@]}"; do
    a=(${market_crops[$k]})
    market_crops[$k]=${market_w}x${a[1]}+${market_x}+${a[0]}
  done
}

# Generate cropped / enhanced images.
function market_generate_crops() {
  local k img1 img2
  convert "$1" $(
    for k in "${!market_crops[@]}"; do
      eval "img1=\$${k}_file"; eval "img2=\$${k}_ocr_file"
      echo \( +clone -crop ${market_crops[$k]} +repage \
        -write "$img1" \
        -sigmoidal-contrast 10,60% -type grayscale -write "$img2" \
        +delete \)
    done
  ) null:
}

# Test to see if market_header crop is actually from a market image.
function market_is_market() {
  local resized="$tmp_dir/market_header_resized.png"
  convert "$market_header_ocr_file" -resize 1585x108 "$resized"
  local result="$(compare -metric RMSE "$resized" "$ref_dir/market_header_ocr.png" null: 2>&1)"
  below_threshold 6000 "$result"
}

# Get market name (system + station).
function get_market_name() {
  local match_string system_name market_name ocr ocr_fixed closest_match
  if [[ ! -e "$market_name_txt_file" ]]; then
    echo " Get market name"
    # Get system name.
    system_name="$(get_system_name)"
    if [[ "$system_name" && ! "$force" ]]; then
      match_string="$system_name "
    else
      system_name="UNKNOWN"
    fi
    echo -n "  System name: $system_name; "
    # Get station name, good luck with the OCR.
    tesseract "$station_name_ocr_file" "$tmp_dir/station_name_ocr" -l small -psm 7 >/dev/null
    ocr="$(<"$tmp_dir/station_name_ocr.txt")"
    ocr_fixed="$(adjust_ocr "$ocr")"
    echo -n "Station name: $ocr_fixed [$ocr]; "
    # Find closest match, if one exists.
    cd "$out_dir"
    ls *.png | sed 's/.png$//' > "$tmp_dir/outfiles.txt"
    match_string="${match_string}- $ocr_fixed"
    closest_match="$(agrep -By -e "${match_string:0:29}" "$tmp_dir/outfiles.txt" 2>/dev/null | head -1)"
    if [[ "$closest_match" ]]; then
      market_name="$closest_match"
      echo "Matched existing"
    else
      market_name="$system_name - $ocr_fixed"
      echo "No match"
    fi
    echo "  Market name: $market_name"
    echo "$market_name" > "$market_name_txt_file"
  fi 1>&2
  echo "$(<"$market_name_txt_file")"
}

# Is this a continuation of the last market?
function market_is_continuation() {
  local market_name market_name_prev
  market_name="$(get_market_name)"
  echo -n " Continuation? "
  if [[ "$(find "$market_name_txt_prev" -mmin -1 2>/dev/null)" ]]; then
    market_name_prev="$(<"$market_name_txt_prev")"
    if [[ "$market_name" == "$market_name_prev" ]]; then
      echo "Yes [last market match]"
    else
      echo "No [last market nomatch: $market_name_prev]"
      return 1
    fi
  else
    echo "No [timeout]"
    return 1
  fi
}

# Create new market image.
function market_create() {
  local market_img
  # Start new market.
  market_img="$out_dir/$(get_market_name).png"
  echo " NEW MARKET"
  # Backup any existing market image.
  [[ -e "$market_img" ]] && bak "$market_img"
  convert -append "$station_name_file" "$station_info_file" "$market_header_file" "$market_data_file" "$market_img"
}

# Create existing market image.
function market_continue() {
  local market_img result offset
  market_img="$out_dir/$(get_market_name).png"
  # Detect vertical offset of slice in existing market image.
  result="$(compare -metric RMSE -subimage-search "$market_img" $market_slice_file null: 2>&1)"
  offset=$(echo "$result" | sed 's/.*,//')
  echo -n " Slice match? "
  if (( $offset > 0 )); then
    echo "Yes @ $offset [$result]"
    echo " CONTINUE MARKET"
    convert "$market_img" -page +0+$offset "$market_data_file" -layers mosaic "$market_img"
  else
    echo "No"
    echo " CANNOT CONTINUE MARKET"
  fi
}

# Make backups of market crops.
function market_backup_files() {
  local k f
  for k in "${!files[@]}"; do
    eval "f=\$${k}_file"
    mv_prev "$f"
  done
}

# Do all the things!
function market() {
  market_crops_init "$img" || return 1
  # Initialize file-named variables
  local k; declare -A files
  for k in "${!market_crops[@]}"; do files[$k]="$k.png"; files[${k}_ocr]="${k}_ocr.png"; done
  for k in market_name; do files[${k}_txt]="$k.txt"; done
  for k in "${!files[@]}"; do
    declare ${k}_file="$tmp_dir/${files[$k]}" ${k}_prev="$(prev "$tmp_dir/${files[$k]}")"
  done
  market_generate_crops "$img"
  market_is_market || return 1
  echo "market"
  market_is_continuation && market_continue || market_create
  market_backup_files
  echo
}

##########
## MAIN ##
##########

function process() {
  local images_new f img dims
  # Get new images.
  cd "$img_dir"
  images_new=( Screenshot_!($(join \| "${images[@]}")).bmp )

  # Abort if no new images found.
  (( ${#images_new[@]} == 0 )) && return 1

  # Process images.
  for f in "${images_new[@]}"; do
    img=$(basename "$f" .bmp)
    echo -n "$img "
    img="$img_dir/$img.bmp"
    dims=($(identify -format "%w %h" "$img"))
    echo -n "[${dims[0]}x${dims[1]}] "
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
