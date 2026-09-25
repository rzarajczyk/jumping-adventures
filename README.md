# Jumping Adventure

A 2D Android game about five friends, floating islands, and the ocean. Explore three hand-designed routes across three difficulty levels, with original kawaii artwork, animation, music, and sound effects. The game works completely offline.

## Install on Android

1. Copy `build/JumpingAdventure.apk` to a phone running Android 9 or later with an ARM64 processor.
2. Open the APK in the Files app. If prompted, allow that app to install apps from this source.
3. Tap **Install**, then launch **Jumping Adventure**. Play with the phone in landscape orientation.

The APK is signed with the project's local signing key. Updates signed with the same key can be installed over an existing version while preserving progress. Do not uninstall the game before updating if you want to keep your stars. Version 1.1 updates the original Jumping Penguin app and retains its package ID and signing key. Existing unlocks, audio settings, and scores are migrated: the old fish count becomes the small-star count, and each completed level also receives a point for its finish star. On desktop, the game keeps using the previous Godot data directory, `Godot/app_userdata/Jumping Penguin`.

With USB debugging enabled on a connected phone, install and launch the game with:

```sh
adb install -r build/JumpingAdventure.apk
adb shell am start -n pl.rafal.jumpingpenguin/com.godot.game.GodotAppLauncher
```

## How to play

- Choose a character: penguin, whale, capybara, kitten, or puppy. Your choice is saved. All characters use the same physics and have three animation frames.
- Choose a difficulty and an unlocked level.
- Drag in the direction you want to jump, usually up and to the right. A longer drag applies more force. Release to jump.
- Start a drag anywhere outside the buttons. Moving your finger back to the starting point or dragging downward cancels the jump.
- The arrow and meter show the direction and strength. There is no trajectory preview or in-air control.
- Islands keep moving while you aim. Falling into the water restarts the current level. Attempts are unlimited.
- Each route has 10 small stars. Touch the large star on the final island to collect the eleventh star and finish the level. Landing on the final island alone is not enough.
- The finish shows animated fireworks, confetti, and a victory screen with your character and star count. Levels unlock separately for each difficulty.
- The pause menu stops the level and lets you change audio, restart the level, or choose another level.

Easy is designed for ages 6–8; medium and hard are for ages 9 and up. Each route has 20 jumps across 21 islands. A successful run is designed to take 90–150 seconds, including aiming time, with no time limit. This is a design target to validate with children, not a measured result.

## Open and run the project

Install **Godot 4.7.2 Standard** (not .NET) for your operating system. In the Godot Project Manager, import this project by selecting `project.godot`, then run it. On desktop, aim with the left mouse button; press Escape to pause.

If Godot is available on your command line, you can also run:

```sh
godot --path .
```

The helper `python3 tools/bootstrap.py` downloads the official macOS Godot editor 4.7.2 and Android export templates, verifies their SHA512 checksums, and extracts the files needed for Android. The download is about 1.4 GB. This bootstrap helper currently supports macOS; on other operating systems, install the matching Godot editor and export templates for your platform. Do not add `.tools` to the repository or source archive.

## Build an Android APK

To export Android, install JDK 21 (the templates use Java 17), Android SDK Platform 36, Build Tools 36.1.0, Platform Tools, and accept the SDK licences. Android Studio can install these packages. Install the export templates matching Godot 4.7.2 and configure the Android SDK and Java SDK paths in Godot's Editor Settings. Godot uses the included libraries; the engine is not compiled from C++.

For a manual export on any operating system, open **Project > Export**, select the Android preset, and export the project. This preset points to custom Godot templates under `.tools/templates/`; install the matching Android templates there or update the preset's custom template paths for your machine. The APK is written to `build/JumpingAdventure.apk`.

The repeatable command-line build helper is currently configured for macOS and uses Gradle 8.11.1:

```sh
python3 tools/test.py
python3 tools/build_android.py
```

The build helper imports project assets, prepares the Gradle project, exports a release APK, and verifies its signature. Its executable, SDK, and JDK paths can be overridden with `PENGUIN_GODOT`, `PENGUIN_ANDROID_SDK`, and `PENGUIN_JAVA`. The Godot executable used by the helper must use a local `_sc_` data directory under `.tools`.

The signing key `.tools/jumping-penguin.keystore` and its password file `.tools/signing.json` are created once. **Keep private backups of both files** so future APKs can update existing installations. They are not included in the APK, source archive, or repository. App ID: `pl.rafal.jumpingpenguin`; version: `1.1.0` (version code 2); minimum SDK: 28; target SDK: 36; ABI: `arm64-v8a`.

## Automated GitHub releases

Once the repository secrets below are configured, every push to `master` builds a signed APK on a macOS runner and publishes a GitHub Release. Releases are tagged `v1.1.N`, where `N` is the workflow run number; each APK gets a monotonically increasing Android version code and a SHA-256 checksum file.

Add these under **Settings > Secrets and variables > Actions** to sign the APK with the existing project key: `ANDROID_KEYSTORE_BASE64` (the keystore encoded as one-line Base64), `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_ALIAS`. Keep these values in GitHub Actions secrets; never commit the keystore or its password file.

## Project structure and tuning

- `scripts/gesture.gd`: 16-unit dead zone, full force at a 240-unit drag, maximum speed 850. Coordinates account for Godot viewport scaling.
- `scripts/penguin.gd`: `CharacterBody2D`, gravity 1200, physics at 60 Hz, and no carry-over of island velocity when jumping.
- `scripts/world.gd`: level flow, sinusoidal island motion, stars, resets, camera, and finish goal.
- `resources/levels`: three route definitions. `resources/difficulties`: island widths, gaps, and movement for easy, medium, and hard. Adjust the balance without editing the UI.
- `scripts/main.gd`: Polish-language UI, pause handling, safe margins, and app background handling.
- `scripts/characters.gd`: character catalog. `scripts/fireworks.gd`: animated fireworks and confetti.
- `scripts/progress.gd`: local save at `user://progress.cfg`, separate progress for each difficulty, written through a temporary file.
- `assets/art`: original PNG artwork, including three penguin frames. `docs/ART_ADVENTURE.md` contains the prompts used with the built-in image generator.
- `tools/generate_audio.py`: reproducible generator for the original 40-second music loop and six sound effects; it uses only the Python standard library.

When replacing an original PNG, update its `AtlasTexture` regions in `scripts/art.gd`. The bright rim marks each island's physical landing surface. The game uses the Compatibility renderer.

## Verification

`python3 tools/test.py` runs tests in the Godot engine. It checks the process exit code, number of checks, and script errors, then writes a report to `build/test-results.txt`. The automated run plays through all nine routes and collects all 11 stars on each. It does not measure how comfortable the controls feel or whether the difficulty is balanced for children.

To capture UI screenshots, run:

```sh
godot --path . --script tests/capture.gd
```

See `docs/TEST_REPORT.md` for detailed results, tested devices, and limitations.

## Assets and licences

The artwork was created with the built-in image generator. The original music and sound effects were created with the project's audio generator. Nunito is licensed under the SIL Open Font License (`assets/fonts/OFL.txt`). Godot and third-party licence notices are in `assets/licenses` and are included in the APK. The project has no network services, analytics, ads, or in-app purchases.
