#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/{web,linux,macos}
python3 scripts/run_godot.py --headless --path game --editor --import --quit
python3 scripts/run_godot.py --headless --path game --export-release "${1:-Web}"
