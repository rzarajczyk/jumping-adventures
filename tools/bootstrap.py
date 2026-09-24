"""Download the pinned official macOS Godot editor and Android templates."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
VERSION = "4.7.2-stable"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}/"
TOOLS.mkdir(exist_ok=True)
(TOOLS / ".gdignore").touch()


def download(name, target):
    subprocess.run(["curl", "--fail", "--location", "--retry", "2", BASE + name, "--output", str(target)], check=True)


checks_path = TOOLS / "SHA512-SUMS.txt"
download("SHA512-SUMS.txt", checks_path)
checks = {line.split()[-1].lstrip("*"): line.split()[0] for line in checks_path.read_text().splitlines() if line.strip()}
for name, local in [(f"Godot_v{VERSION}_macos.universal.zip", "godot.zip"), (f"Godot_v{VERSION}_export_templates.tpz", "templates.tpz")]:
    path = TOOLS / local
    if not path.exists():
        download(name, path)
    with path.open("rb") as f:
        digest = hashlib.file_digest(f, "sha512").hexdigest()
    if digest != checks[name]:
        raise SystemExit(f"Checksum mismatch: {path}; remove the incomplete archive and retry.")
    print("SHA512 verified:", name)

with zipfile.ZipFile(TOOLS / "godot.zip") as archive:
    archive.extractall(TOOLS)
with zipfile.ZipFile(TOOLS / "templates.tpz") as archive:
    for name in archive.namelist():
        if name.endswith(("android_source.zip", "android_debug.apk", "android_release.apk", "version.txt")):
            archive.extract(name, TOOLS)
engine = TOOLS / "Godot.app/Contents/MacOS/Godot"
engine.chmod(0o755)
(engine.parent / "_sc_").touch()
print("Godot ready:", engine)
