# Cosmotops

Cosmotops is a fast top-down arcade prototype starring Trixie. Fly through every planet to repaint the system, stop the timer, and watch the meteor finale.

## Controls

- Keyboard: WASD or arrow keys
- Gamepad: left stick or D-pad; A/Start confirms
- Touch or mouse: drag on the left side of the playfield

## Run locally

Open this folder in Godot 4.7.2 and run the project. The prototype uses Godot's GL Compatibility renderer so it can later target Android with the same project.

Trixie's source artwork is stored in `assets/trixie.png`; the ship, planets, meteors, starfield, and effects are drawn procedurally at runtime.

## Prototype builds

- Windows: `build/windows/Cosmotops.exe`
- Android: `build/android/Cosmotops.apk`

Install Godot's Android build template from **Project > Install Android Build Template** before exporting Android. Cosmotops uses the Gradle exporter so Android's themed launcher icon is packaged correctly.

The APK is a debug-signed ARM64 prototype intended for direct testing, not a Play Store release.
