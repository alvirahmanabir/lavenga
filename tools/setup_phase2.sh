#!/usr/bin/env bash
# Run from the project root. Lets pub pick versions compatible with your SDK.
set -e
rm -f test/widget_test.dart
flutter pub add flutter_riverpod go_router shared_preferences cached_network_image
flutter pub get
flutter analyze
flutter test
