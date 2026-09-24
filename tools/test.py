"""Run actual Godot scene tests; fail on script errors even if Godot exits with 0."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
engine = os.environ.get("PENGUIN_GODOT", str(root / ".tools/Godot.app/Contents/MacOS/Godot"))
result = subprocess.run([engine, "--headless", "--path", str(root), "--fixed-fps", "60", "tests/runner.tscn"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
log = result.stdout
(root / "build").mkdir(exist_ok=True)
(root / "build/test-results.txt").write_text(log)
print(log)
summary = re.search(r"RESULT: (\d+) checks, (\d+) failures", log)
ok = result.returncode == 0 and summary and int(summary[1]) >= 1158 and int(summary[2]) == 0
ok = ok and "SCRIPT ERROR" not in log and "ERROR:" not in log and log.count("finished=true, fish=10") == 9
sys.exit(0 if ok else 1)
