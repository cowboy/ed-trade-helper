#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh

img_dir=/images
out_dir=/vagrant/output
tmp_dir=$out_dir/tmp
proc_file=$out_dir/processed.txt

function header() { echo "== $@ =="; }

# Get all not-previously-processed images.
cd "$img_dir"
shopt -s extglob nullglob
p="$(cat "$proc_file" 2>/dev/null | tr "\n" "|")"
images=(!($p).bmp)

if (( ${#images[@]} == 0 )); then
  echo "No new screenshots to process!"
  exit
fi

# Create output directory
[[ -d "$out_dir" ]] || mkdir -p "$out_dir"
cd "$out_dir"
# Cleanup temp directory
[[ -d "$tmp_dir" ]] && rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

header "Cropping"
crop_geometry="1181x715+98+310" # Based on 1920x1200
for f in "${images[@]}"; do
  echo "Cropping $f"
  convert "$img_dir/$f" -crop $crop_geometry "$tmp_dir/$f"
done

header "Joining"
function join_new_image() {
  ((joined_i++))
  joined="$2-joined.png"
  echo "Copying $2 to $joined"
  cp "$tmp_dir/$2.bmp" $joined
}
function join_next_image() {
  local slice_height=30
  local src="$tmp_dir/$2.bmp"
  local slice="$tmp_dir/slice$1.png"
  convert "$src" -crop x${slice_height}+0+0 "$slice"
  search="$(compare -metric RMSE -subimage-search $joined "$slice" "$tmp_dir/search.png" 2>&1)"
  offset=$(echo "$search" | sed 's/.*,//')
  (( $offset == 0 )) && return 1
  echo " $2 slice matched at $offset ($search)"
  convert $joined -page +0+$offset "$src" -layers mosaic $joined
}

for i in "${!images[@]}"; do
  img=$(basename ${images[$i]} .bmp)
  (( $i > 0 )) && join_next_image $i $img || join_new_image $i $img
  echo $img >> "$proc_file"
done
