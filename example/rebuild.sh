#!/bin/bash
# Exit on error
set -e

echo "=== Teardown started ==="

# 1. Delete generated subdirectories under example/lib/bloc
echo "Deleting generated subdirectories under lib/bloc/..."
rm -rf lib/bloc/demobloc lib/bloc/demo_parent lib/bloc/demostate lib/bloc/demoevent

# 2. Delete generated i18n files under example/lib/i18n
echo "Deleting generated translation files under lib/i18n/..."
rm -f lib/i18n/StringHelper.dart lib/i18n/TS.dart lib/i18n/English.dart lib/i18n/Chinese.dart lib/i18n/strings.i18n.dart

# 3. Clean the build runner cache
echo "Cleaning build cache..."
dart run build_runner clean

echo "=== Teardown complete ==="
echo "=== Rebuild started ==="

# 4. Run build runner to generate all files in a single pass
dart run build_runner build --delete-conflicting-outputs

echo "=== Rebuild complete ==="
