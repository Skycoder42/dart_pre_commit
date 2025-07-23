# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.4.6] - 2025-07-23
### Changed
- Updated dependencies
- Updated min dart sdk to `3.8.0`

## [5.4.5] - 2025-04-18
### Fixed
- Fixed incompatibility with osv-scanner Version 2.0
  - To keep using v1, add `legacy: true` to the scanner config

## [5.4.4] - 2025-03-14
### Changed
- Updated dependencies

## [5.4.3] - 2025-02-17
### Changed
- Updated dependencies
- Updated min dart sdk to `3.7.0`

## [5.4.2] - 2024-12-30
### Fixed
- Make osv-scanner compatible with dart workspaces

## [5.4.1] - 2024-12-28
### Changed
- Updated dependencies
- Updated min dart sdk to `3.6.0`

### Fixed
- Make pull-up-dependencies compatible with dart workspaces

## [5.4.0] - 2024-09-13
### Added
- Added global configuration option `exclude` (#4)
  - Allows to exclude files from analysis using regular expressions
- Added `ignore-unstaged-files` to `analyze` and `custom-lint` tasks (#31)
  - Allows to specify whether unstaged files should cause the tool to fail
  - Can be combined with the global `exclude` to fully exclude files

### Changed
- Updated dependencies
- Updated min dart sdk to `3.5.0`

## [5.3.1] - 2024-08-19
### Changed
- Updated dependencies

## [5.3.0] - 2024-03-11
### Changed
- Updated dependencies
- Updated min dart sdk to `3.3.0`

### Fixed
- `analyze` task now honors `error-level` setting and will only fail if the analyzer fails as well (#30)
  - It will still log info/warning messages

### Removed
- Removed the `scan-mode` option of the `analyze` task (#30)
  - It will now always scan the whole repository for issues

## [5.2.1] - 2023-08-16
### Changed
- Update dependencies
  - Major update of `analyzer` to 6.\*
  - Major update of `mocktail` to 1.\*

## [5.2.0+1] - 2023-06-28
### Changed
- Updated dependencies

## [5.2.0] - 2023-06-14
### Added
- Make osv-scanner task configurable
  - Allows to specify a configuration file
  - Allows to scan the whole repository instead of just the lockfile

### Changed
- Update dependencies

### Fixed
- Added documentation for custom-lint and osv-scanner tasks
- Only run custom-lint task if installed as dev dependency

## [5.1.0+1] - 2023-05-17
### Changed
- Update dependencies

## [5.1.0] - 2023-05-11
### Changed
- Update minimal dart SDK to 3.0.0

## [5.0.0] - 2023-05-09
### Added
- Add support for running custom\_lint as pre commit hook via `custom-lint` task

### Removed
- Removed `TestImportTask` and `LibExportTask` - superseded by `custom-lint`

## [4.1.0] - 2023-02-22
### Added
- `osv-scanner` Task to automatically check for dependencies with security issues
  - Runs automatically, if the `osv-scanner` binary can be found
  - Scans the `pubspec.lock` to check if any of the dependencies has a know vulnerability

## [4.0.0] - 2022-10-21
### Selected Changes
- Improved configuration of all tasks
  - Task are now all configured via the pubspec.yaml
  - Remove most of the task-related command line arguments
  - Analysis level and scope can now be configured for the analyze task
  - line length can now be configured for the format task
  - Separate allow-lists for the outdated and pull up tasks
- Refactor lib export task to reliably handle staged files and to not run on projects not published to pub.dev
- Revamp public API
  - made task implementations private
  - split library into multiple parts
  - Provide `DartPreCommit.run` for a simple entrypoint to invoke the hooks from code
- Hooks do not run anymore if no files for the given directory have been staged

## [3.0.2] - 2022-07-19
### Changed
- Update dependencies

## [3.0.1] - 2022-05-20
### Changed
- Update min dart SDK to 2.17.0, update dependencies

## [3.0.0] - 2022-03-04
### Added
- `FlutterCompatTask`: Checks if a dart project can be added to a newly created flutter project. Useful to ensure that
no package versions are required that are then what flutter currently supports
- `TestImportTask`: Checks if any test files import library exports instead of sources
- `LibExportTask`: Checks if all src files that contain package public definitions are exported somewhere in lib

### Changed
- Use dart\_test\_tools for CI/CD, code analysis and testing
- Enable all checks by default
- Add support for a configuration part in the pubspec.yaml
  - For now, dependencies can be whitelisted for the outdated/pull-up tasks
- Updated dependencies

### Removed
- fix imports task
- library imports task
- nullsafety task

## [2.3.3] - 2021-12-06
### Changed
- Dependency updates

## [2.3.2] - 2021-07-01
### Fixed
- The `analyze` task was not working anymore, as the output format of
`dart analyze` has changed. The task was now adjusted to handle the new format
only

## [2.3.1] - 2021-05-07
### Fixed
- The `library-imports` can now be properly ignored by adding
`// dart_pre_commit:ignore-library-import` before the line where the import
happens

## [2.3.0] - 2021-04-30
### Added
- New Task `library-imports` (#12)
  - Scans the source files (files under `lib/src`) and test files
  - If any import in these files references a dart file that is a top level
  library, the task rejects
  - Top-Level libraries are dart files under `lib`, except those placed in
  `lib/src`

### Changed
- Change Mocking framework to mocktail

## [2.2.0] - 2021-04-29
### Added
- Basic Interface to create custom file and repository based tasks (#6)
- Made all tasks and helper classes public (#5)
- Added riverpod-based HooksProvider for easier use (replaces Hooks.create)
- Outdated task: Checks if any packages can be updated (#7)
- Nullsafe task: Checks if any packages can be updated to a nullsafe version (#7)
- `--[no-]ansi` CLI option to explicitly enable/disable rich logging (#10)

### Changed
- Migrated package to nullsafety
- Refactored Hooks API to allow custom hooks
- Generalized HookResult to be independent of specific tasks
  - error has been removed, instead a Exceptions are thrown in case of fatal
  errors
  - linter, pullUp have been replaced by the more generic rejected state
- refactor logger (#3)
  - there is a pretty and a simple logger now
  - the correct one is auto-detected based on the availability of a tty
  - provides a useful status message so other logs/exceptions can be easily
  associated with the task
  - debug-logging has been added to all tasks
  - log-levels can be configured to show certain log messages
- Ported package to use freezed dataclasses
- Improved status icons
- Added `refresh` parameter to logger interface
- Updated dependencies

### Fixed
- pull-up-dependencies now works in subdirs (#8)
- pull-up-dependencies now correctly handles nullsafety releases
- fix-imports can now handle multiline imports correctly (#9)
  - this includes comments before, after or between the import and the
  semicolon, as well as `as/show/hide` statements, that fall into a new line

### Removed
- Hooks.create was removed, use the provider instead
- TaskException was removed in favor of normal exceptions

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
- Initial release
- Automatic deployment

[5.4.6]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.5...v5.4.6
[5.4.5]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.4...v5.4.5
[5.4.4]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.3...v5.4.4
[5.4.3]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.2...v5.4.3
[5.4.2]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.1...v5.4.2
[5.4.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.4.0...v5.4.1
[5.4.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.3.1...v5.4.0
[5.3.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.2.1...v5.3.0
[5.2.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.2.0+1...v5.2.1
[5.2.0+1]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.2.0...v5.2.0+1
[5.2.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.1.0+1...v5.2.0
[5.1.0+1]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.1.0...v5.1.0+1
[5.1.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v4.1.0...v5.0.0
[4.1.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v3.0.2...v4.0.0
[3.0.2]: https://github.com/Skycoder42/dart_pre_commit/compare/v3.0.1...v3.0.2
[3.0.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v2.3.3...v3.0.0
[2.3.3]: https://github.com/Skycoder42/dart_pre_commit/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/Skycoder42/dart_pre_commit/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.1.4...v2.2.0
[1.1.4]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Skycoder42/dart_pre_commit/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Skycoder42/dart_pre_commit/releases/tag/v1.0.0
