#!/bin/bash

echo "::group::Install OSV-Scanner"
go install github.com/google/osv-scanner/cmd/osv-scanner@v1
echo "::endgroup::"

echo "::group::Install Flutter"
dart run tool/ci/ci_install_flutter.dart
echo "::endgroup::"
