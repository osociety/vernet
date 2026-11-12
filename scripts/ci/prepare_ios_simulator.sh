#!/usr/bin/env bash
# Installs the requested iOS runtime when the runner image lacks it, boots an
# iPhone for it, and records the device UDID for the workflow's wait guard.
#
# Runs in the background of the iOS integration job so the ~15 minutes of
# simulator bring-up overlaps the Flutter bootstrap and CocoaPods steps, which
# need nothing from it. The step's own logs are discarded by Actions once the
# step exits, so progress goes to stdout of the launcher instead.
set -euo pipefail

ios_version="${1:?usage: prepare_ios_simulator.sh <ios_version|latest>}"
udid_file="${2:-/tmp/sim-udid}"

if [[ "$ios_version" != "latest" ]]; then
  if xcrun simctl list runtimes | grep -q "iOS $ios_version "; then
    echo "iOS $ios_version runtime is already installed."
  else
    xcodebuild -downloadPlatform iOS -buildVersion "$ios_version"
  fi
fi

runtime=""
udid=""

if [[ "$ios_version" == "latest" ]]; then
  # Runtimes can be listed more than once per version (device-family
  # variants), so take the newest one that actually has an iPhone.
  while IFS= read -r candidate; do
    candidate_udid="$(xcrun simctl list devices available --json | jq -r --arg runtime "$candidate" '
      [ (.devices[$runtime] // [])[]
        | select(.name | startswith("iPhone"))
      ][0].udid // empty')"
    if [[ -n "$candidate_udid" ]]; then
      runtime="$candidate"
      udid="$candidate_udid"
      break
    fi
  done < <(xcrun simctl list runtimes --json | jq -r '
    [ .runtimes[]
      | select(.platform == "iOS" and .isAvailable == true)
      | { id: .identifier, v: (.version | split(".") | map(tonumber)) }
    ] | sort_by(.v) | reverse | .[].id')
else
  runtime="com.apple.CoreSimulator.SimRuntime.iOS-$(echo "$ios_version" | tr . -)"
  udid="$(xcrun simctl list devices available --json | jq -r --arg runtime "$runtime" '
    [ (.devices[$runtime] // [])[]
      | select(.name | startswith("iPhone"))
    ][0].udid // empty')"

  if [[ -z "$udid" ]]; then
    echo "No iPhone device for $runtime; creating one."
    udid="$(xcrun simctl create "iPhone 16 ($ios_version)" \
      com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$runtime")"
  fi
fi

if [[ -z "$udid" ]]; then
  echo "::error::No iPhone simulator available on this runner."
  xcrun simctl list devices available
  exit 1
fi

echo "Booting $runtime ($udid)"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b

# Written last: the wait guard treats an absent file as a failed setup.
printf '%s' "$udid" > "$udid_file"
echo "Simulator ready: $udid"
