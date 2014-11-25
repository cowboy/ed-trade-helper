#!/bin/bash

# vagrant ssh -c /vagrant/process/process.sh

img_dir=/vagrant/images
out_dir=/vagrant/output

cd "$img_dir"

[[ -d "$out_dir" ]] && rm -rf "$out_dir"
mkdir -p "$out_dir"

# Based on 1920x1200
crop_geometry="1181x715+98+310"

for f in *.bmp; do
  echo "Processing $f"
  convert "$f" -crop "$crop_geometry" "$out_dir/$f"
done

