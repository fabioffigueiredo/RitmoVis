#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
destination="$project_root/Sources/SquatCounter/Resources/Models"
mkdir -p "$destination"

download_verified() {
  name=$1
  expected=$2
  url=$3
  temp=$(mktemp "$destination/.${name}.XXXXXX")
  trap 'rm -f "$temp"' EXIT HUP INT TERM
  curl --fail --location --retry 3 --output "$temp" "$url"
  actual=$(shasum -a 256 "$temp" | cut -d ' ' -f 1)
  if [ "$actual" != "$expected" ]; then
    echo "Checksum mismatch for $name: got $actual; expected $expected" >&2
    exit 1
  fi
  mv "$temp" "$destination/$name"
  trap - EXIT HUP INT TERM
}

# Checksums observed in the original project on 2026-09-23. The upstream
# /latest/ endpoint can change; a change fails closed until reviewed.
download_verified pose_landmarker_lite.task \
  59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a \
  https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task
download_verified pose_landmarker_full.task \
  4eaa5eb7a98365221087693fcc286334cf0858e2eb6e15b506aa4a7ecdcec4ad \
  https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task
