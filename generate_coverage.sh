#!/usr/bin/env bash
set -e

# Clean previous coverage
rm -rf coverage

echo "Running unit/widget tests with coverage..."
flutter test --coverage

# Preserve unit test coverage separately (only if produced)
if [ -f coverage/lcov.info ]; then
  mv coverage/lcov.info coverage/unit.lcov.info
else
  echo "Unit coverage not produced; aborting." && exit 1
fi

echo "Running integration tests with coverage (macOS desktop)..."
# NOTE: Adjust the -d flag if you want to target
# a different device (e.g. linux, windows, chrome).
# Run integration tests but do not exit on failure — capture exit code.
INTEG_EXIT=0
flutter test integration_test/app_test.dart --coverage -d macos || INTEG_EXIT=$?
if [ $INTEG_EXIT -ne 0 ]; then
  echo "Integration tests failed with exit code $INTEG_EXIT — will continue and generate coverage from available results."
fi

# Preserve integration coverage if produced
if [ -f coverage/lcov.info ]; then
  mv coverage/lcov.info coverage/integration.lcov.info
else
  echo "No integration coverage produced; skipping integration coverage step."
fi

echo "Combining unit and integration coverage..."
# Combine only existing coverage files
COMBINE_FILES=""
if [ -f coverage/unit.lcov.info ]; then
  COMBINE_FILES="$COMBINE_FILES coverage/unit.lcov.info"
fi
if [ -f coverage/integration.lcov.info ]; then
  COMBINE_FILES="$COMBINE_FILES coverage/integration.lcov.info"
fi
if [ -z "$COMBINE_FILES" ]; then
  echo "No coverage files to combine; aborting." && exit 1
fi
cat $COMBINE_FILES > coverage/lcov.info

echo "Excluding generated files from coverage (.g.dart)..."
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  'lib/models/drift/*' \
  -o coverage/lcov.info

echo "Generating HTML coverage report..."
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
