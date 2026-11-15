# Beta testing Vernet

Back to [Vernet](../README.md).

Vernet is maintained by one person and tested on a handful of devices, so
pre-release builds reach real networks mostly through volunteers. If you are
willing to run a build that might break, you are exactly who this project
needs.

The app's **Settings → Updates & beta** page switches the update check between
the stable and pre-release listings, and spells out how to join the beta track
and how automatic updates work on your platform.

## Android

Pick either route:

| Route | What you get |
|---|---|
| [Google Play beta](https://play.google.com/apps/testing/org.fsociety.vernet.store) | Tap the link, press **Join the beta**, and update Vernet as usual. This switches your existing Play install to the beta channel, so you get new builds before anyone else. |
| [GitHub pre-release APKs](https://github.com/osociety/vernet/releases) | Download the `*-app-arm64-v8a-dev-release.apk` for a modern phone, `armeabi-v7a` for older 32-bit devices, or `x86_64` for emulators. These are the `dev` build, so they install alongside the Play version instead of replacing it. |

## Windows

Windows has the fewest testers of any platform, and the most room for things to
go quietly wrong — Wi-Fi adapter drivers, firewall prompts, and SmartScreen all
behave differently from one machine to the next.

1. Grab `Vernet-<version>-windows-x64.zip` (or `-windows-arm64.zip`, or the
   `.msixbundle`) from [releases](https://github.com/osociety/vernet/releases).
2. Extract it and run `vernet.exe`. If SmartScreen interrupts it, choose
   **More info**, then **Run anyway**.
3. Try a device scan, a ping, a port scan, and a speed test, and note anything
   that hangs, errors, or looks wrong compared to the phone app.
4. Tell us what happened in
   [Discussions](https://github.com/osociety/vernet/discussions/categories/q-a)
   or file an [issue](https://github.com/osociety/vernet/issues).

## Linux and macOS

Linux and macOS testers use the same pre-release page, and Snap users can get
updates early with `sudo snap install vernet --beta`.

## Why reports matter

Beta testing has already turned up real bugs: release builds printing debug
logs, an empty What's New screen, an invisible Android notification icon, and
update checks offering pre-releases to stable installs. Reports like "the scan
finds nothing on my laptop" or "speed test is way off on my machine" are the
ones that get fixed.
