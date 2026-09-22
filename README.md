# Cosmotops

Cosmotops is a fast top-down arcade prototype starring Trixie. Choose one of
eight ships and ten paint colors, then fly through the Sun, eight planets,
Moon, Makemake, a black hole, and two asteroids before the meteor finale.

## Controls

- Keyboard: WASD or arrow keys; P pauses; R resets; Escape goes back
- Gamepad: left stick or D-pad; A confirms; Start pauses; B goes back
- Touch or mouse: drag on the left side of the playfield

Choose **Ready Ship**, then press any keyboard key, gamepad button, or tap to
start the animated `5` to `1` countdown. The in-game header also provides Back,
Reset, Pause/Resume, and Close buttons. Capturing a target speaks its English
name through the device's text-to-speech voice.

## Run locally

Open this folder in Godot 4.7.2 and run the project. The prototype uses Godot's
GL Compatibility renderer so it can later target Android with the same project.

Trixie's source artwork is stored in `assets/trixie.png`. Ship sprites and sound
effects are CC0 assets from Kenney; planets, the black hole, meteors, starfield,
and visual effects are drawn procedurally at runtime.

## Prototype builds

- Windows: `build/windows/Cosmotops.exe`
- Android: `build/android/Cosmotops.apk`

Install Godot's Android build template from
**Project > Install Android Build Template** before exporting Android. Cosmotops
uses the Gradle exporter so Android's themed launcher icon is packaged correctly.

The APK is a debug-signed ARM64 prototype intended for direct testing, not a
Play Store release.

Android updates must reuse the same persistent Godot debug keystore. A regular
Godot installation keeps it under `%APPDATA%/Godot/keystores`; a self-contained
editor must be configured with that same key before export. Losing or replacing
the private key requires uninstalling the existing Android package before a new
signature can be installed.
