#!/bin/bash

echo "::group::Install OSV-Scanner"
brew install osv-scanner
echo "::endgroup::"

echo "::group::Install Flutter"
dart run tool/ci/ci_install_flutter.dart
echo "::endgroup::"
