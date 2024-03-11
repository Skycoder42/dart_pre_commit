#!/bin/bash
set -exo pipefail

echo "::group::Install OSV-Scanner"
osv_version=$(git ls-remote --tags https://github.com/google/osv-scanner.git | grep -v "-" | cut -d 'v' -f2 | tail -n1)
osv_dir=$RUNNER_TOOL_CACHE\\osv-scanner
mkdir -p "$osv_dir"
curl -Lo "$osv_dir\\osv-scanner.exe" "https://github.com/google/osv-scanner/releases/download/v$osv_version/osv-scanner_${osv_version}_windows_amd64.exe"
echo "$osv_dir" >> "$GITHUB_PATH"
echo "::endgroup::"

echo "::group::Install Flutter"
dart run tool/ci/ci_install_flutter.dart
echo "::endgroup::"
