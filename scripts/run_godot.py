#!/usr/bin/env python3
"""Make CLI script/import errors fail CI even if Godot returns exit code zero."""
import pathlib
import subprocess
import sys
root = pathlib.Path(__file__).resolve().parent.parent
try:
    result = subprocess.run([str(root / '.tools/godot'), *sys.argv[1:]], cwd=root,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=180)
except subprocess.TimeoutExpired:
    sys.exit('Godot command exceeded 180 seconds')
print(result.stdout, end='')
sys.exit(result.returncode or int('ERROR:' in result.stdout))
