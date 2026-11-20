<h1>
  <img src="firebase/public/favicon.png" height="60" align="absmiddle">
  Vernet
</h1>

Vernet - Know your network

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/osociety/vernet/total?label=Downloads)
[![Flutter main pipeline](https://github.com/osociety/vernet/actions/workflows/flutter_pipeline.yml/badge.svg?branch=main)](https://github.com/osociety/vernet/actions/workflows/flutter_pipeline.yml)
![Liberapay receiving](https://img.shields.io/liberapay/receives/opensociety?label=Receives)
[![Codecov](https://img.shields.io/codecov/c/github/osociety/vernet?token=B25JBP4RCI&label=Codecov)](https://codecov.io/gh/osociety/vernet)
[![vernet](https://snapcraft.io/vernet/trending.svg?name=0)](https://snapcraft.io/vernet)

[![F-Droid](https://img.shields.io/f-droid/v/org.fsociety.vernet?label=F-Droid)](https://f-droid.org/packages/org.fsociety.vernet)
[![GitHub release](https://img.shields.io/github/v/release/osociety/vernet?label=Release)](https://github.com/osociety/vernet/releases/latest)
[![Google Play](https://img.shields.io/endpoint?url=https%3A%2F%2Fplay.cuzi.workers.dev%2Fplay%3Fid%3Dorg.fsociety.vernet.store%26hl%3Den%26gl%3DUS%26l%3D%24version&label=Google%20Play)](https://play.google.com/store/apps/details?id=org.fsociety.vernet.store)
[![vernet](https://snapcraft.io/vernet/badge.svg)](https://snapcraft.io/vernet)

## Download

| Android | iOS | macOS | Linux | Windows |
|-----------|-----|-------|-------|---------|
|<a href='https://f-droid.org/packages/org.fsociety.vernet'><img alt='Get it on F-Droid' src='https://fdroid.gitlab.io/artwork/badge/get-it-on.png'  width="100" /></a><a href='https://play.google.com/store/apps/details?id=org.fsociety.vernet.store'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png'  width="100" /></a>| Coming soon |<a href='https://github.com/osociety/vernet/releases/latest'><img alt='Get it on GitHub Releases' src='https://i.ibb.co/q0mdc4Z/get-it-on-github.png'  width="100" /></a>|<a href="https://snapcraft.io/vernet"><img alt="Get it from the Snap Store" src="https://snapcraft.io/en/dark/install.svg" width="100" height="40"></a>|<a href="https://get.microsoft.com/installer/download/9N1170N3PHMM?referrer=appbadge" target="_self"><img src="https://get.microsoft.com/images/en-us%20dark.svg" width="125"/></a>|

The Google Play build contains ads. The F-Droid and GitHub builds are ad-free.

## Features

1. See your Wi-Fi name, BSSID, local address, gateway, and subnet.
2. Find devices connected to your local network, including automatic scans when the app opens, with the vendor behind each MAC address.
3. Check whether a website or device responds with ping, even without internet access.
4. Scan popular ports, a custom range, or a single port for reachable services.
5. Look up website addresses and find device names with forward and reverse DNS.
6. Test your download and upload speed.
7. Score your network's health and see the factors and tips behind the rating.
8. Control internet access, location permission, scan ranges, ping count, and timeouts.

Vernet helps you spot possible connection and security concerns. It does not
replace a professional security audit, but it gives you useful findings to
review, such as devices and services that are reachable on your network.

## Screenshots

|Vernet|Home|Connected Devices|Security Findings|
|-|-|-|-|
|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" width = "200">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" width = "200">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" width = "200">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/6.png" width = "200">|
|Ping|DNS|Speed test|Settings|
|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/5.png" width = "200">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/7.png" width = "200">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/8.png" width = "225">|<img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/4.png" width = "200">|

## Documentation

| Guide | Covers |
|---|---|
| [Install on desktop](docs/INSTALL.md) | Snap, Microsoft Store, and manual downloads for Linux, Windows and macOS, with the `net-tools` and `libsqlite3.so` gotchas and the optional `avahi-observe` connection. |
| [Beta testing](docs/BETA_TESTING.md) | How to run pre-release builds on each platform and what to report. |
| [Android build flavors](docs/BUILD_FLAVORS.md) | Why `dev`, `fdroid` and `store` behave differently, and the `store_overlay/` rule. |
| [Community](docs/COMMUNITY.md) | Which GitHub Discussions category to post in. |
| [Contributing](CONTRIBUTING.md) | Setting up a development checkout and opening a pull request. |
| [Architecture](ARCHITECTURE.md) | How `lib/` is layered and where new code belongs. |

## Current Milestone

[![2026 Q4 progress](https://badgen.net/github/milestones/osociety/vernet/5?color=green)](https://github.com/osociety/vernet/milestone/5) [![Open](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fosociety%2Fvernet%2Fmilestones%3Fstate%3Dopen%26sort%3Ddue_date%26direction%3Dasc%26per_page%3D1&query=%24%5B0%5D.open_issues&label=Open&cacheSeconds=3600)](https://github.com/osociety/vernet/milestones) [![Closed](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fosociety%2Fvernet%2Fmilestones%3Fstate%3Dopen%26sort%3Ddue_date%26direction%3Dasc%26per_page%3D1&query=%24%5B0%5D.closed_issues&label=Closed&cacheSeconds=3600)](https://github.com/osociety/vernet/milestones) [![Due by](https://img.shields.io/badge/Due%20by-December%2031%2C%202026-484848)](https://github.com/osociety/vernet/milestone/5)

Counts include pull requests tagged to the milestone, not only its issues.

## How to Contribute

1. Found bug? Open an [issue](https://github.com/osociety/vernet/issues)
2. Do you know Flutter? Fix bugs and open a [Pull Request](https://github.com/osociety/vernet/pulls)
3. Don't write code? Run a [beta build](docs/BETA_TESTING.md) and report what breaks — that is the most useful contribution of all, and it needs one device you already own.

## Support and Donate

1. Support this project by becoming stargazer of this project.
2. Rate our app on [Google Play](https://play.google.com/store/apps/details?id=org.fsociety.vernet.store)

3. Buy me a coffee.

    [![Liberapay](https://liberapay.com/assets/widgets/donate.svg)](https://liberapay.com/OpenSociety/donate)

4. Support me on Ko-Fi

    [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/fs0c13ty)

*Vernet is an independent open-source project, licensed under Apache-2.0, and is not affiliated with or endorsed by any other organization or product with a similar name.*
