#!/usr/bin/env bash
# Renders a reel frame by frame (1280x720 at 60 fps, as a widget test) and
# encodes it.
#
#   tool/record_demo.sh demo   # the README hero: doc/demo.webp and doc/demo.gif
#   tool/record_demo.sh ldr    # the nod: doc/reels/ldr.webp and .gif
#   tool/record_demo.sh vinyl  # MorphText in a Hero: doc/reels/vinyl.webp and .gif
#
# Both also get an H.264 MP4 in doc/reels/ for posting. None of doc/ ships
# in the pub package (.pubignore).
set -euo pipefail
cd "$(dirname "$0")/.."

reel="${1:-demo}"
case "$reel" in
  demo) test=tool/record_demo_test.dart frames=doc/frames out=doc ;;
  ldr) test=tool/record_ldr_test.dart frames=build/ldr_frames out=doc/reels ;;
  vinyl) test=tool/record_vinyl_test.dart frames=build/vinyl_frames out=doc/reels ;;
  *) echo "usage: $0 [demo|ldr|vinyl]" >&2; exit 64 ;;
esac
mkdir -p "$out" doc/reels

flutter test "$test"
ffmpeg -hide_banner -loglevel error -y -framerate 60 -i "$frames/frame_%04d.png" \
  -c:v libwebp_anim -lossless 0 -quality 80 -compression_level 6 -loop 0 \
  "$out/$reel.webp"
ffmpeg -hide_banner -loglevel error -y -framerate 60 -i "$frames/frame_%04d.png" \
  -vf "fps=30,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" \
  -loop 0 "$out/$reel.gif"
ffmpeg -hide_banner -loglevel error -y -framerate 60 -i "$frames/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow -movflags +faststart \
  "doc/reels/$reel.mp4"
ls -la "$out/$reel.webp" "$out/$reel.gif" "doc/reels/$reel.mp4"
