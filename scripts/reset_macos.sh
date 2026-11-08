#!/usr/bin/env bash
set -e

BUNDLE_ID="org.fsociety.vernet.vernet"
CONTAINER="$HOME/Library/Containers/$BUNDLE_ID"
DB="$CONTAINER/Data/Library/Application Support/$BUNDLE_ID/vernet.sqlite"
PLIST="$CONTAINER/Data/Library/Preferences/$BUNDLE_ID.plist"

echo "Killing Vernet if running..."
pkill -x vernet 2>/dev/null || true
sleep 1

removed=0

if [ -f "$DB" ]; then
  rm -f "$DB"
  echo "Removed database: $DB"
  removed=1
fi

if [ -f "$PLIST" ]; then
  rm -f "$PLIST"
  echo "Removed preferences: $PLIST"
  removed=1
fi

if [ "$removed" -eq 0 ]; then
  echo "No app data found — already clean."
else
  echo "Done. Next launch will start as a first-time user."
fi
