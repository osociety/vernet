#!/usr/bin/env bash
set -e

# Clean previous coverage
rm -rf coverage

echo "Running unit/widget tests with coverage..."
flutter test --coverage

# Preserve unit test coverage separately
mv coverage/lcov.info coverage/unit.lcov.info

echo "Running integration tests with coverage (macOS desktop)..."
# NOTE: Adjust the -d flag if you want to target
# a different device (e.g. linux, windows, chrome).
flutter test integration_test/app_test.dart --coverage -d macos -j 1

# Preserve integration coverage separately
mv coverage/lcov.info coverage/integration.lcov.info

echo "Combining unit and integration coverage..."
cat coverage/unit.lcov.info coverage/integration.lcov.info > coverage/lcov.info

echo "Excluding generated files from coverage (.g.dart, .freezed.dart, .mocks.dart)..."
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  -o coverage/lcov.info

echo "Generating HTML coverage report..."
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
