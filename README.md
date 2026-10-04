# Jumping Adventure

An offline 2D Android game with eight playable characters, three floating-island routes, and three difficulty levels. Drag and release to jump, collect stars, and use jetpacks to reach the final star and unlock the next route. Features original artwork, animation, music, and a Polish interface.

Choose a penguin, whale, capybara, kitten, puppy, panda, otter, or beaver. Swipe the character list, use the mouse wheel, or tap the arrows to see every friend.

Each jetpack pickup adds three jumps to your remaining supply. Collect both pickups on a route without using them to save up six jumps.

![A penguin uses a jetpack to jump between floating islands and collect stars](play_store/assets/feature-graphic-1024x500.jpg)

## Install

Requires **Android 9 or later** and an **ARM64** device.

1. Download the **APK** from [GitHub Releases](https://github.com/rzarajczyk/jumping-adventures/releases/latest).
2. Open it on your phone, allow installation from that source if prompted, and tap **Install**.
3. Launch **Jumping Adventure** and play in landscape orientation.

Use the APK for installation; the AAB is intended for Google Play uploads.

## Build

The build helpers support **macOS**. Install **Python 3.11+**, **Temurin JDK 21**, and the Android SDK with **Platform 36**, **Build Tools 36.1.0**, and **Platform Tools**; accept the SDK licences. Android Studio can install the SDK packages.

Run from the repository root:

```sh
python3 tools/bootstrap.py
python3 tools/test.py
python3 tools/build_android.py
```

Bootstrap downloads and verifies Godot **4.7.2 Standard** and its Android export templates (about 1.4 GB). The build produces signed `build/JumpingAdventure.apk` and `build/JumpingAdventure.aab` and verifies their signatures.

For custom SDK or JDK locations, set `PENGUIN_ANDROID_SDK` and `PENGUIN_JAVA`. Keep private backups of `.tools/jumping-penguin.keystore` and `.tools/signing.json` to preserve the signing key for future updates.

Every push to `master` runs the tests and publishes signed APK/AAB files to GitHub Releases. Google Play uploads are currently disabled in CI; the internal testing upload steps are commented out until the Play Console app and credentials are ready.

## Test

After bootstrap, run:

```sh
python3 tools/test.py
```

The suite imports assets, checks menus, saves, physics, characters, jetpacks, touch input, pause and restart, then completes all nine routes with 11/11 stars each. It fails on test failures or script errors. Logs are written to `build/test-import.txt` and `build/test-results.txt`.

For manual playtesting, import `project.godot` in Godot 4.7.2 Standard and run the project. Use the left mouse button to aim and jump; Escape pauses. See the [test report](docs/TEST_REPORT.md) for results and device-testing limitations.
