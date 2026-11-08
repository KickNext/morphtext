#!/usr/bin/env bash
# Renders the demo frames (tool/record_demo_test.dart) and encodes them as
# doc/demo.webp (README) and doc/demo.gif (for places without WebP).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter test tool/record_demo_test.dart
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i doc/frames/frame_%03d.png \
  -c:v libwebp_anim -lossless 0 -quality 75 -compression_level 6 -loop 0 doc/demo.webp
ffmpeg -hide_banner -loglevel error -y -framerate 30 -i doc/frames/frame_%03d.png \
  -vf "scale=600:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=32[p];[b][p]paletteuse=dither=none" \
  -loop 0 doc/demo.gif
ls -la doc/demo.webp doc/demo.gif
