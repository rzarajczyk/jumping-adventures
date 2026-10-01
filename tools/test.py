"""Run actual Godot scene tests; fail on script errors even if Godot exits with 0."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
engine = os.environ.get("PENGUIN_GODOT", str(root / ".tools/Godot.app/Contents/MacOS/Godot"))
build = root / "build"
build.mkdir(exist_ok=True)
# A fresh checkout has neither imported textures nor the global script-class cache.
imported = subprocess.run([engine, "--headless", "--path", str(root), "--editor", "--import", "--quit"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
(build / "test-import.txt").write_text(imported.stdout)
if imported.returncode != 0 or "SCRIPT ERROR" in imported.stdout or "ERROR:" in imported.stdout:
    print(imported.stdout)
    sys.exit(1)
result = subprocess.run([engine, "--headless", "--path", str(root), "--fixed-fps", "60", "tests/runner.tscn"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
log = result.stdout
(build / "test-results.txt").write_text(log)
print(log)
summary = re.search(r"RESULT: (\d+) checks, (\d+) failures", log)
ok = result.returncode == 0 and summary and int(summary[1]) >= 1388 and int(summary[2]) == 0
ok = ok and "SCRIPT ERROR" not in log and "ERROR:" not in log and log.count("finished=true, stars=11") == 9
sys.exit(0 if ok else 1)
