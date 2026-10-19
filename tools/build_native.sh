#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
TARGET="${TARGET:-template_debug}"
git submodule update --init --depth 1
python3 -m venv .tools/venv
.tools/venv/bin/python -m pip install --disable-pip-version-check 'scons==4.11.1'
mkdir -p native/.build
(cd native/.build && "$GODOT_BIN" --headless --dump-extension-api)
cd native
../.tools/venv/bin/python -m SCons platform=macos arch=universal target="$TARGET" custom_api_file=.build/extension_api.json build_profile=build_profile.json -j4
