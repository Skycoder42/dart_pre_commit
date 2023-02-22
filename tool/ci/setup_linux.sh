#!/bin/bash

echo "::group::Install OSV-Scanner"
go --version
go install github.com/google/osv-scanner/cmd/osv-scanner@latest
echo "${GOPATH:-$HOME/go}/bin" >> "$GITHUB_PATH"
echo "::endgroup::"

echo "::group::Install Flutter"
dart run tool/ci/ci_install_flutter.dart
echo "::endgroup::"
