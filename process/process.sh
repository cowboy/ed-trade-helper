#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh

img_dir=/images
out_dir=/vagrant/output
tmp_dir=$out_dir/tmp

processed=$out_dir/tmp/processed.txt

shopt -s extglob nullglob

# Create output and temp directories if necessary.
[[ -d "$out_dir" ]] || mkdir -p "$out_dir"
[[ -d "$tmp_dir" ]] || mkdir -p "$tmp_dir"

function system_name() {
  [[ ! -d "/logs" ]] && "NONE" && return 1
  local log="$(ls -t /logs/netLog.*.log | head -1)"
  cat $log | sed -nr 's/.*System:[0-9]+\(([^)]+)\).*/\1/p' | tail -1
}

############
## MARKET ##
############

declare -A market_crops
function market_crops_init() {
  # Based on 1920x1200
  local x=95 w=1190 k a
  market_crops=(
    [station_info]="132 98"
    [market_header]="230 79"
    [market_data]="310 713"
  )
  for k in "${!market_crops[@]}"; do
    a=(${market_crops[$k]})
    market_crops[$k]=${w}x${a[1]}+${x}+${a[0]}
  done
}
market_crops_init

function market() {
  convert "$img_dir/$img.bmp" $(
    for k in "${!market_crops[@]}"; do
      echo \( +clone -crop ${market_crops[$k]} +repage -write "$tmp_dir/$k.png" +delete \)
    done
  ) null:
  # TODO: return 1 if market_header is not actually from a market image
  if market_last >/dev/null; then
    local match_threshold=2000
    local result="$(compare -metric RMSE "$tmp_dir/station_info.png" "$tmp_dir/station_info_last.png" null: 2>&1)"
    if echo "$result" | awk "{exit \$1 < $match_threshold ? 0 : 1}"; then
      echo "last market match [$result]"
    else
      echo "last market NOMATCH [$result]"; false
    fi
  else
    echo "no last market"; false
  fi
  if [[ $? == 0 ]]; then
    market_continue $img
  else
    market_new_station $img
  fi
}

function market_last() {
  local file="$tmp_dir/market_last_image.txt"
  [[ "$1" ]] && echo $1 > "$file" || cat "$file" 2>/dev/null
}

function market_new_station() {
  market_last $1
  local joined="$(market_last).png"
  echo " - create $joined"
  convert -append "$tmp_dir/station_info.png" "$tmp_dir/market_header.png" "$tmp_dir/market_data.png" $joined
  mv "$tmp_dir/station_info.png" "$tmp_dir/station_info_last.png"
}

function market_continue() {
  local joined="$(market_last).png"
  echo " - continue $joined"
  local slice_height=50
  local src="$tmp_dir/market_data.png"
  local slice="$tmp_dir/market_data_slice.png"
  convert "$src" -crop x${slice_height}+0+0 +repage "$slice"
  local result="$(compare -metric RMSE -subimage-search $joined "$slice" null: 2>&1)"
  local offset=$(echo "$result" | sed 's/.*,//')
  if (( $offset == 0 )); then
    echo " - slice NOMATCH"
    return 1
  else
    echo " - slice matched at $offset [$result]"
    convert $joined -page +0+$offset "$src" -layers mosaic $joined
  fi
}

##########
## MAIN ##
##########

function process() {
  # Get remaining unprocessed images.
  cd "$img_dir"
  local images=( !($(cat "$processed" 2>/dev/null | tr "\n" "|")).bmp )

  # images=(
  #   Screenshot_0000.bmp
  #   Screenshot_0001.bmp
  #   Screenshot_0002.bmp
  #   Screenshot_0003.bmp
  #   Screenshot_0004.bmp

  #   Screenshot_0017.bmp
  #   Screenshot_0018.bmp
  #   Screenshot_0019.bmp
  # )

  (( ${#images[@]} == 0 )) && return 1

  cd "$out_dir"
  for i in "${!images[@]}"; do
    local img=$(basename ${images[$i]} .bmp)
    echo -n "$img: "
    market $img
    echo $img >> "$processed"
  done
  echo "Ready..."
}

echo "Ready..."
while true; do
  process
  sleep 10
done
