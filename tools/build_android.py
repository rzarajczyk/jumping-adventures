"""Repeatable macOS Android export. Key and passwords stay inside ignored .tools/."""
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import zipfile
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(os.environ.get("PENGUIN_GODOT", str(ROOT / ".tools/Godot.app/Contents/MacOS/Godot")))
SDK = Path(os.environ.get("PENGUIN_ANDROID_SDK", str(Path.home() / "Library/Android/sdk")))
JDK = Path(os.environ.get("PENGUIN_JAVA", "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"))
TOOLS = ROOT / ".tools"


def run(*args, **kwargs):
    subprocess.run([str(x) for x in args], cwd=ROOT, check=True, **kwargs)


def main():
    for p in [ENGINE, SDK / "platform-tools/adb", JDK / "bin/keytool", TOOLS / "templates/android_release.apk"]:
        if not p.exists():
            raise SystemExit(f"Missing dependency: {p}. See README.md.")
    (ENGINE.parent / "_sc_").touch()
    android = ROOT / "android/build"
    if not (android / "build.gradle").exists():
        source = TOOLS / "templates/android_source.zip"
        if not source.exists():
            raise SystemExit("Extract templates/android_source.zip from the Godot export templates first.")
        android.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(source) as archive:
            archive.extractall(android)
        (android / "gradlew").chmod(0o755)
        (android / ".gdignore").touch()
    source = TOOLS / "templates/android_source.zip"
    identifier = ".tools/templates/android_source.zip [" + hashlib.md5(source.read_bytes()).hexdigest() + "]"
    (ROOT / "android/.build_version").write_text(identifier + "\n")
    # Build the native QR plugin from source against the matching local engine
    # template. Nothing is patched into Godot's generated Gradle project.
    plugin_env = {**os.environ, "JAVA_HOME": str(JDK), "ANDROID_HOME": str(SDK)}
    run(android / "gradlew", "-p", ROOT / "android/lan_plugin", "--no-daemon", "assembleRelease", env=plugin_env)
    plugin_output = ROOT / "addons/lan_pairing/bin"
    plugin_output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "android/lan_plugin/build/outputs/aar/JumpingLan-release.aar", plugin_output / "JumpingLan.aar")
    run(ENGINE, "--headless", "--path", ROOT, "--editor", "--import", "--quit")
    settings = TOOLS / "editor_data/editor_settings-4.7.tres"
    if not settings.exists():
        raise SystemExit(f"Expected self-contained editor settings at {settings}")
    data = settings.read_text()
    for key, val in {"export/android/android_sdk_path": str(SDK), "export/android/java_sdk_path": str(JDK)}.items():
        line = f"{key} = {json.dumps(val)}"
        data = re.sub(rf"^{re.escape(key)} = .*\n?", "", data, flags=re.M)
        data += line + "\n"
    settings.write_text(data)
    credentials_path = TOOLS / "signing.json"
    key = TOOLS / "jumping-penguin.keystore"
    if not credentials_path.exists():
        if key.exists():
            raise SystemExit("Signing key exists but credentials are missing; restore signing.json to preserve app updates.")
        credentials_path.write_text(json.dumps({"password": secrets.token_urlsafe(30), "alias": "penguin"}))
        credentials_path.chmod(0o600)
    credentials = json.loads(credentials_path.read_text())
    env = dict(os.environ)
    env["PENGUIN_STOREPASS"] = credentials["password"]
    if not key.exists():
        run(JDK / "bin/keytool", "-genkeypair", "-keystore", key, "-storepass:env", "PENGUIN_STOREPASS", "-keypass:env", "PENGUIN_STOREPASS", "-alias", credentials["alias"], "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=Jumping Penguin", env=env)
        key.chmod(0o600)
    env["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"] = str(key)
    env["GODOT_ANDROID_KEYSTORE_RELEASE_USER"] = credentials["alias"]
    env["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] = credentials["password"]
    (ROOT / "build").mkdir(exist_ok=True)
    apk = ROOT / "build/JumpingAdventure.apk"
    aab = ROOT / "build/JumpingAdventure.aab"
    run(ENGINE, "--headless", "--path", ROOT, "--export-release", "Android", apk, env=env)
    run(ENGINE, "--headless", "--path", ROOT, "--export-release", "Android AAB", aab, env=env)
    versions = sorted((SDK / "build-tools").iterdir(), key=lambda p: tuple(int(n) for n in p.name.split(".") if n.isdigit()))
    run(versions[-1] / "apksigner", "verify", "--verbose", apk, env={**env, "JAVA_HOME": str(JDK)})
    run(JDK / "bin/jarsigner", "-verify", aab, env={**env, "JAVA_HOME": str(JDK)})
    print(f"APK ready: {apk} ({apk.stat().st_size / 1024**2:.1f} MiB)")
    print(f"AAB ready: {aab} ({aab.stat().st_size / 1024**2:.1f} MiB)")


if __name__ == "__main__":
    main()
