# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 3.0.2
### Changed
- Update dependencies

## 3.0.1
### Changed
- Update min dart SDK to 2.17.0, update dependencies

## 3.0.0
### Added
- `FlutterCompatTask`: Checks if a dart project can be added to a newly created flutter project. Useful to ensure that
no package versions are required that are then what flutter currently supports
- `TestImportTask`: Checks if any test files import library exports instead of sources
- `LibExportTask`: Checks if all src files that contain package public definitions are exported somewhere in lib
### Changed
- Use dart_test_tools for CI/CD, code analysis and testing
- Enable all checks by default
- Add support for a configuration part in the pubspec.yaml
  - For now, dependencies can be whitelisted for the outdated/pull-up tasks
- Updated dependencies
### Removed
- fix imports task
- library imports task
- nullsafety task

## 2.3.3
### Changed
- Dependency updates

## 2.3.2
### Fixed
- The `analyze` task was not working anymore, as the output format of
`dart analyze` has changed. The task was now adjusted to handle the new format
only

## 2.3.1
### Fixed
- The `library-imports` can now be properly ignored by adding
`// dart_pre_commit:ignore-library-import` before the line where the import
happens

## 2.3.0
### Added
- New Task `library-imports` (#12)
  - Scans the source files (files under `lib/src`) and test files
  - If any import in these files references a dart file that is a top level
  library, the task rejects
  - Top-Level libraries are dart files under `lib`, except those placed in
  `lib/src`
### Changed
- Change Mocking framework to mocktail

## 2.2.0
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
### Removed
- Hooks.create was removed, use the provider instead
- TaskException was removed in favor of normal exceptions
### Fixed
- pull-up-dependencies now works in subdirs (#8)
- pull-up-dependencies now correctly handles nullsafety releases
- fix-imports can now handle multiline imports correctly (#9)
  - this includes comments before, after or between the import and the
  semicolon, as well as `as/show/hide` statements, that fall into a new line

## 1.1.4
### Fixed
- Include pubspec.yaml into analysis step
- Skip `dart analyze`, if no files are to be analyzed

## 1.1.3
### Fixed
- fix-imports now works for imports with trailing comments (#2)

## 1.1.2
### Fixed
- Fixed problem with repositories where the dart project folder beeing scanned
is not the the git root folder

## 1.1.1
### Fixed
- Fixed bug that caused a crash in `--check-pull-up` if dependencies declared in
the `pubspec.yaml` are missing in `pubspec.lock` (#1)

## 1.1.0
### Added
- Support for check if the version of dart dependencies can be pulled up to a
higher version from the lockfile

## 1.0.2
### Fixed
- Fixed bug where the tool tried to format deleted files

## 1.0.1
### Fixed
- `dart analyze` now treats lint infos as errors
- Replace legacy dart tools in README
- Add missing await in program runner

## 1.0.0
### Added
- Automatic deployment

## 0.1.0
- Initial release

## Unreleased
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
