#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/run_godot.py --headless --path game --editor --import --quit
python3 scripts/run_godot.py --headless --path game --script tests/test_content.gd
python3 scripts/run_godot.py --headless --path game --script tests/test_moves.gd
python3 scripts/run_godot.py --headless --path game --script tests/test_simulation.gd
npm test --prefix services/signaling
python3 scripts/run_godot.py --headless --path game --script tests/test_webrtc.gd
