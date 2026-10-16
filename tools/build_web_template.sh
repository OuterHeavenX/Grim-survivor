#!/usr/bin/env bash
# Rebuilds web/godot.web.template_release.wasm32.nothreads.zip: a Godot 4.7.2
# single-threaded web export template with 3D and every module this 2D game
# does not use compiled out. It halves the download (wasm 39.5 MB -> 20 MB).
#
# If the game starts using something listed in OFF below (3D nodes, RegEx,
# SVG at runtime, networking, ...), take it out of the list and rebuild.
#
#   EMSDK=~/emsdk GODOT_SRC=~/godot-src ./tools/build_web_template.sh
#
# Needs Emscripten 4.0.20 (the version 4.7.2's official templates use), Python
# and SCons, and a checkout of godotengine/godot at tag 4.7.2-stable.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$PWD/web"
: "${EMSDK:?point EMSDK at an emsdk checkout with 4.0.20 activated}"
: "${GODOT_SRC:?point GODOT_SRC at a godot 4.7.2-stable checkout}"
# shellcheck disable=SC1091
source "$EMSDK/emsdk_env.sh" >/dev/null
OFF=""
for m in astcenc basis_universal bcdec betsy bmp camera csg cvtt dds enet etcpak \
	fbx glslang gltf godot_physics_3d gridmap hdr interactive_music jolt_physics \
	jpg jsonrpc ktx lightmapper_rd meshoptimizer mobile_vr mono mp3 msdfgen \
	multiplayer navigation_2d navigation_3d objectdb_profiler openxr raycast regex \
	svg text_server_adv theora tinyexr upnp vhacd visual_shader webrtc websocket \
	webxr xatlas_unwrap mbedtls; do
	OFF="$OFF module_${m}_enabled=no"
done
cd "$GODOT_SRC"
# shellcheck disable=SC2086
scons -j"$(nproc)" platform=web target=template_release threads=no production=yes \
	optimize=size_extra disable_3d=yes module_text_server_fb_enabled=yes $OFF
cp bin/godot.web.template_release.wasm32.nothreads.zip "$OUT/"
echo "Template written to $OUT/godot.web.template_release.wasm32.nothreads.zip"
