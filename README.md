# dart_pre_commit
[![Continuos Integration](https://github.com/Skycoder42/dart_pre_commit/actions/workflows/ci.yaml/badge.svg)](https://github.com/Skycoder42/dart_pre_commit/actions/workflows/ci.yaml)
[![Pub Version](https://img.shields.io/pub/v/dart_pre_commit)](https://pub.dev/packages/dart_pre_commit)

A small collection of pre commit hooks to format and lint dart code

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Activation](#activation)
  * [Simple dart wrapper](#simple-dart-wrapper)
  * [Using git_hooks](#using-git-hooks)
    + [Handling the case where the git_hooks is setup in a child folder of the repository](#handling-the-case-where-the-git-hooks-is-setup-in-a-child-folder-of-the-repository)
- [Configuration](#configuration)
  * [Format task](#format-task)
    + [Options](#options)
  * [Test Imports Task](#test-imports-task)
  * [Analyze Task](#analyze-task)
    + [Options](#options-1)
  * [Custom Lint Task](#custom-lint-task)
  * [Library Exports Task](#library-exports-task)
  * [Flutter Compatibility Task](#flutter-compatibility-task)
  * [Outdated Task](#outdated-task)
    + [Options](#options-2)
  * [Pull Up Dependencies Task](#pull-up-dependencies-task)
    + [Options](#options-3)
  * [OSV-Scanner Task](#osv-scanner-task)
- [Documentation](#documentation)

<small><i><a href='https://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

## Features
- Provides multiple built in hooks to run on staged files
  - Run `dart format`
  - Check for invalid imports in test files
  - Run `dart analyze`
  - Ensure all src files that are publicly visible are exported somewhere
  - Checks if a dart package is compatible with the current stable flutter version
  - Checks if any packages are outdated
  - Checks if any packages have newer versions in the lock file
- Only processes staged files
  - Automatically stages modified files again
  - Fails if partially staged files had to be modified
- Can be used as binary or as library
- Integrates well with most git hook solutions

## Installation
Simply add `dart_pre_commit` to your `pubspec.yaml` (preferably as dev dependency) and run `dart pub get` (or
`flutter pub get`).

```sh
dart pub add --dev dart_pre_commit
```

## Activation
To make use of the hooks, you have to activate them first. This package only comes with the hook-code itself, **not**
with a way to integrate it with git as actual hook. Here are a few examples on how to do so:

### Simple dart wrapper
If this is the only hook you need and you don't really need anything more then "just run the thing", you can simply
create a file named `tool/setup_git_hooks.dart` as detailed below and run `dart run tool/setup_git_hooks.dart` to
initialize the hooks on each of your machines.

```dart
import 'dart:io';

Future<void> main() async {
  final preCommitHook = File('.git/hooks/pre-commit');
  await preCommitHook.parent.create();
  await preCommitHook.writeAsString(
    '''
#!/bin/sh
exec dart run dart_pre_commit # specify custom options here
''',
  );

  if (!Platform.isWindows) {
    final result = await Process.run('chmod', ['a+x', preCommitHook.path]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  }
}
```

### Using git_hooks
The second example uses the [git_hooks](https://pub.dev/packages/git_hooks) package to activate the hook. Take the
following steps to activate the hook:

1. Add `git_hooks` as dev dependency to your project
2. Follow the installation instructions here: https://pub.dev/packages/git_hooks#create-files-in-githooks
3. Modify `bin/git_hooks.dart` to look like the following:
```dart
import "package:dart_pre_commit/dart_pre_commit.dart";
import "package:git_hooks/git_hooks.dart";

void main(List<String> arguments) {
  final params = {
    Git.preCommit: _preCommit
  };
  GitHooks.call(arguments, params);
}

Future<bool> _preCommit() async {
  final result = await DartPreCommit.run();
  return result.isSuccess;
}
```

#### Handling the case where the git_hooks is setup in a child folder of the repository
In cases where your project is in a child folder of the repository ie. Repo/project, when you run `DartPreCommit.run()`,
it'll run from the root of your repository and hence will not be able to find `pubspec.yaml` file. To handle this case
we need to direct the DartPreCommit to run its command from a child folder. To do so, you need to add the following line
in the `_preCommit()` function before we invoke DartPreCommit:

```dart
Future<bool> _preCommit() async {
  Directory.current = '/project_sub_directory'; // <--- This line switches the scan directory to a subdirectory
  final result = await DartPreCommit.run();
  return result.isSuccess;
}
```

## Configuration
The tool follows the zero config principle - this means you can run it without having to configure anything. However,
there are a bunch of configuration options if you need to adjust the tool. For simplicity, you can just define them
in your `pubspec.yaml` below the `dart_pre_commit` key, but it is also possible to move it to a separate file.

The configuration uses the following pattern:
```yaml
dart_pre_commit:
  task_1: null
  task_2: false
  task_3: true
  task_4:
    option1: true
    option2: info
    option3:
      - a
      - b
    ...
  ...
```

Each task corresponds to the configuration of the task with that name. The values can be:
- `null` (or missing): The default configuration of the task is used
- `true` or `false`: Explicitly enable or disable the task. If enabled, still uses the default configuration.
- `<config-map>`: Explicitly enable the task and use the given configuration in addition to the default configuration.
This allows you to overwrite either some or all of the configuration options of a task.

The default tasks and their options, if they have any, are defined follows. However, you can always create your own,
custom tasks with customized configurations.

The tool also accepts some command line arguments. Run `dart_pre_commit --help` to get more information on them.

### Format task
**Task-ID:** `format`<br/>
**Configurable:** Yes<br/>
**Enabled**: Always<br/>

This tasks checks all staged files for their formatting and corrects the formatting, if necessary. Internally, it uses
the `dart format` command to accomplish this.

#### Options
 Option        | Type   | Default | Description
---------------|--------|---------|-------------
 `line-length` | `int?` | `null`  | The line length the formatter should use. If unset, the recommended default for dart (currently 80) is used.

### Test Imports Task
**Task-ID:** `test-imports`<br/>
**Configurable:** No<br/>
**Enabled**: Always<br/>

This task scans all `test` files to ensure they only import `src` libraries. For integration tests or in cases, where
sources are purposefully not placed below `src`, you can ignore those imports as follows:

```dart
import 'package:my_app/src/src.dart';  // OK
import 'package:my_app/my_app.dart';  // NOT OK
// ignore: test_library_import
import 'package:my_app/my_app.dart';  // OK
```

### Analyze Task
**Task-ID:** `analyze`<br/>
**Configurable:** Yes<br/>
**Enabled**: Always<br/>

This tasks checks all files for static analysis issues. Internally, this runs `dart analyze` to check for problems. It
can either scan the whole project or only staged files.

#### Options
 Option        | Type   | Default | Description
---------------|--------|---------|-------------
 `error-level` | `enum` | `info`  | The severity level that should cause the task to reject the commit. See possible values below.
 `scan-mode`   | `enum` | `all`   | The scan mode of the task which defines what files are scanned. See possible values below.

Values for `error-level`:
- `error`: Only fatal errors are reported
- `warning`: fatal errors and warnings are reported
- `info`: fatal errors, warnings and linter issues are reported

Values for `scan-mode`:
- `all` (default): All files are scanned for problems
- `staged`: Only staged files are scanned for problems

### Custom Lint Task
**Task-ID:** `custom-lint`<br/>
**Configurable:** No<br/>
**Enabled**: Only if `custom_lint` is installed as direct (dev) dependency<br/>

This tasks runs the [custom_lint](https://pub.dev/packages/custom_lint) tool on your project to run additional,
customized lints, if you have any. This can be very useful, especially for framework packages like riverpod, but also
simpler ones like equatable.

**Pro-Hint:** You can use this customized pub.dev search query to find linter plugins for your packages:
https://pub.dev/packages?q=dependency%3Acustom_lint_builder

### Library Exports Task
**Task-ID:** `lib-exports`<br/>
**Configurable:** No<br/>
**Enabled**: Only if `publish_to` is not set to `none`<br/>

Scans all staged `src` files and checks if all files, that define at least one public top level element (internal or
visibleFor* elements do not count), are exported publicly in at least one file directly below the `lib` directory.

### Flutter Compatibility Task
**Task-ID:** `flutter-compat`<br/>
**Configurable:** No<br/>
**Enabled**: Only for pure dart projects<br/>

If changes have been made to the `pubspec.yaml`, this task will try to add this project as dependency to an empty, newly
created flutter project to check if all version constraints of all dependencies are compatible with the latest flutter
version.

**Important:** This task requires you to have flutter installed the the `flutter` binary to be available in your path.
If this is not the case, you should explicitly disable the task.

### Outdated Task
**Task-ID:** `outdated`<br/>
**Configurable:** Yes<br/>
**Enabled**: Always<br/>

Checks if any packages have available updates. This task always runs, even if no changes to the dependencies have been
made. If any package has updates greater than the defined allowed level, the commit will fail.

#### Options
 Option    | Type           | Default | Description
-----------|----------------|---------|-------------
 `level`   | `enum`         | `any`   | The level of "outdated-ness" that is allowed. See possible values below.
 `allowed` | `List<String>` | `[]`    | A list of packages that are allowed to be outdated, even if the `level` would otherwise reject them. Sometimes needed if updates break your code.

Values for `level`:
- `major`: only check for major package updates
- `minor`: check for major and minor updates
- `patch`: check for major, minor and patch updates
- `any`: check for all updates, except pre-releases

### Pull Up Dependencies Task
**Task-ID:** `pull-up-dependencies`<br/>
**Configurable:** Yes<br/>
**Enabled**: Always<br/>

Checks if any dependencies in the `pubspec.yaml` have version constraints that allow lower versions than the ones
resolved in the lockfile. If thats the case, the task will reject the commit. If the lockfile is ignored, this task
always runs, otherwise it only runs if changes to the lockfile have been staged.

#### Options
 Option    | Type           | Default | Description
-----------|----------------|---------|-------------
 `allowed` | `List<String>` | `[]`    | A list of packages that are allowed to not be pulled up, even if their version constrains imply it. Can be useful to keep backwards compatibility.

### OSV-Scanner Task
**Task-ID:** `osv-scanner`<br/>
**Configurable:** No<br/>
**Enabled**: Only if the `osv-scanner` binary is found in your PATH<br/>

When enabled, the `pubspec.lock` file is analyzed by the [OSV-Scanner](https://github.com/google/osv-scanner) for known
vulnerabilities in dependent packages. The task will fail in case such dependencies are found.

## Documentation
The documentation is available at
https://pub.dev/documentation/dart_pre_commit/latest/. A full example can be
found at https://pub.dev/packages/dart_pre_commit/example.
