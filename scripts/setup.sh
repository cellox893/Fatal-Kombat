#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.7.2
mkdir -p .downloads .tools
for artifact in "Godot_v${version}-stable_linux.x86_64.zip" "Godot_v${version}-stable_export_templates.tpz"; do
  test -f ".downloads/$artifact" || curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${version}-stable/$artifact" -o ".downloads/$artifact"
  (cd .downloads; rg "  ${artifact}$" ../scripts/godot-SHA512-SUMS.txt | sha512sum -c -)
done
unzip -oq ".downloads/Godot_v${version}-stable_linux.x86_64.zip" -d .tools
ln -sf "Godot_v${version}-stable_linux.x86_64" .tools/godot
chmod +x .tools/godot
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
mkdir -p "$template_dir"
python3 - "$template_dir" <<'PY'
import sys,zipfile,pathlib
with zipfile.ZipFile('.downloads/Godot_v4.7.2-stable_export_templates.tpz') as z:
 for name in z.namelist():
  if not name.endswith('/'):
   pathlib.Path(sys.argv[1],pathlib.Path(name).name).write_bytes(z.read(name))
PY
.tools/godot --version
npm ci --prefix services/signaling
test -f .downloads/webrtc-native-1.2.1.zip || curl -fL --retry 3 https://github.com/godotengine/webrtc-native/releases/download/1.2.1-stable/godot-extension-webrtc_native.zip -o .downloads/webrtc-native-1.2.1.zip
sha256sum -c scripts/webrtc-SHA256.txt
unzip -oq .downloads/webrtc-native-1.2.1.zip -d game
