# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security

## [2.0.0-nullsafety.0] - 2020-12-10
### Changed
- Migrated package to nullsafety

## [1.1.4] - 2020-12-10
### Fixed
- Include pubspec.yaml into analysis step
- Skip `dart analyze`, if no files are to be analyzed

## [1.1.3] - 2020-12-08
### Fixed
- fix-imports now works for imports with trailing comments (#2)

## [1.1.2] - 2020-12-04
### Fixed
- Fixed problem with repositories where the dart project folder beeing scanned 
is not the the git root folder

## [1.1.1] - 2020-10-22
### Fixed
- Fixed bug that caused a crash in `--check-pull-up` if dependencies declared in
the `pubspec.yaml` are missing in `pubspec.lock` (#1)

## [1.1.0] - 2020-10-19
### Added
- Support for check if the version of dart dependencies can be pulled up to a
higher version from the lockfile

## [1.0.2] - 2020-10-09
### Fixed
- Fixed bug where the tool tried to format deleted files

## [1.0.1] - 2020-10-07
### Fixed
- `dart analyze` now treats lint infos as errors
- Replace legacy dart tools in README
- Add missing await in program runner

## [1.0.0] - 2020-10-07
### Added
- Automatic deployment

## [0.1.0] - 2020-10-02
- Initial release
