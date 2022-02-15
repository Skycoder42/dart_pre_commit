#!/bin/sh
OPEN_FLAG="$1"
shift

set -ex
dart test --coverage=coverage "$@" test/unit
dart run coverage:format_coverage \
  --lcov --check-ignore \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages=.packages --report-on=lib
lcov \
  --remove coverage/lcov.info \
  --output-file coverage/lcov_cleaned.info \
  $(cat analysis_options.yaml | yq e ".analyzer.exclude.[]")
genhtml --no-function-coverage -o coverage/html coverage/lcov_cleaned.info

set +x
if [ "$OPEN_FLAG" == "--xdg-open" ]; then
  set -x
  xdg-open coverage/html/index.html
elif [ "$OPEN_FLAG" == "--start" ]; then
  set -x
  start coverage/html/index.html
elif [ "$OPEN_FLAG" == "--open" ]; then
  set -x
  open coverage/html/index.html
fi
