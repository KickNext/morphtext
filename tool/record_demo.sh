#!/usr/bin/env bash
# Renders the hero frames (tool/record_demo_test.dart, 1280x720 at 60 fps)
# and encodes them as doc/demo.webp (README) and doc/demo.gif (a lighter
# 640px, 30 fps copy for places without WebP).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter test tool/record_demo_test.dart
ffmpeg -hide_banner -loglevel error -y -framerate 60 -i doc/frames/frame_%04d.png \
  -c:v libwebp_anim -lossless 0 -quality 80 -compression_level 6 -loop 0 doc/demo.webp
ffmpeg -hide_banner -loglevel error -y -framerate 60 -i doc/frames/frame_%04d.png \
  -vf "fps=30,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" \
  -loop 0 doc/demo.gif
ls -la doc/demo.webp doc/demo.gif
