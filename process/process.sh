#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh

img_dir=/vagrant/images
out_dir=/vagrant/output
tmp_dir=$out_dir/tmp

[[ -d "$out_dir" ]] || mkdir -p "$out_dir"
rm -rf "$out_dir"/*
mkdir -p "$tmp_dir"

# Based on 1920x1200
crop_geometry="1181x715+98+310"

cd "$img_dir"
images=(*.bmp)
cd "$out_dir"

function header() { echo "== $@ =="; }

header "Cropping"
for f in "${images[@]}"; do
  echo "Cropping $f"
  convert "$img_dir/$f" -crop $crop_geometry "$tmp_dir/$f"
done

header "Joining"
joined="Joined.png"
echo "Copying ${images[0]} to $joined"
cp "$tmp_dir/${images[0]}" $joined
slice_height=30
for f in "${images[@]:1}"; do
	convert "$tmp_dir/$f" -crop x${slice_height}+0+0 "$tmp_dir/slice.png"
	search="$(compare -metric RMSE -subimage-search $joined "$tmp_dir/slice.png" "$tmp_dir/search.png" 2>&1)"
	offset=$(echo "$search" | sed 's/.*,//')
	echo "$f slice found at ${offset}px in $joined ($search)"
	convert $joined -page +0+$offset "$tmp_dir/$f" -layers mosaic $joined
done
