#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
node services/signaling/preview.mjs
