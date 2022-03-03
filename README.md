# dart_pre_commit
[![Continuos Integration](https://github.com/Skycoder42/dart_pre_commit/actions/workflows/ci.yaml/badge.svg)](https://github.com/Skycoder42/dart_pre_commit/actions/workflows/ci.yaml)
[![Pub Version](https://img.shields.io/pub/v/dart_pre_commit)](https://pub.dev/packages/dart_pre_commit)

A small collection of pre commit hooks to format and lint dart code

## Features
- Provides multiple built in hooks to run on staged files
  - Run `dart format`
  - Check for invalid imports in test files
  - Run `dart analyze`
  - Ensure all src files that are publicly visible are exported somewhere
  - Checks if a dart package is compatible with the current flutter version
  - Checks if any packages are outdated (configurable)
  - Checks if any packages have newer versions in the lock file
- Only processes staged files
  - Automatically stages modified files again
  - Fails if partially staged files had to be modified
- Can be used as binary or as library
- Integrates well with most git hook solutions

## Installation
Simply add `dart_pre_commit` to your `pubspec.yaml` (preferably as
devDependency) and run `dart pub get` (or `flutter pub get`).

```h
dart pub add --dev dart_pre_commit
```

## Usage
To make use of the hooks, you have to activate them first. This package only
comes with the hook-code itself, **not** with a way to integrate it with git as
actual hook. Here are a few examples on how to do so:

### Using git_hooks
The first example uses the [git_hooks](https://pub.dev/packages/git_hooks)
package to activate the hook. Take the following steps to activate the hook:

1. Add `git_hooks` as dev_dependency to your project
2. Run `dart pub run git_hooks create` to initialize and activate git hooks for your
project
3. Modify `git_hooks.dart` to look like the following:
```dart
import "dart:io";

import "package:dart_pre_commit/dart_pre_commit.dart";
import "package:git_hooks/git_hooks.dart";

void main(List<String> arguments) {
  final params = {
    Git.preCommit: _preCommit
  };
  change(arguments, params);
}

Future<bool> _preCommit() async {
  hooks = await Hooks.create();  // adjust behaviour if neccessary
  final result = await hooks();  // run activated hooks on staged files
  return result.isSuccess;  // report the result
}
```

### Using hanzo
The second example uses the [hanzo](https://pub.dev/packages/hanzo) package to
activate the hook. Take the following steps to activate the hook:

1. Add `hanzo` as dev_dependency to your project
2. Run `dart pub run hanzo install` to initialize and activate git hooks for your
project
3. Create a file named `./tool/pre_commit.dart` as follows:
```dart
import "package:dart_pre_commit/dart_pre_commit.dart";

void main() {
  hooks = await Hooks.create();  // adjust behaviour if neccessary
  final result = await hooks();  // run activated hooks on staged files
  exitCode = result.isSuccess ? 0 : 1;  // report the result
}
```
4. Run `dart pub run hanzo -i pre_commit`

### Without any 3rd party tools
The package also provides a script to run the hooks. You can check it out via
`dart pub run dart_pre_commit --help`. To use it as git hook, without any other tool,
you have to create a script called `pre-commit` in `.git/hooks` as follows:
```dart
#!/bin/bash

exec dart pub run dart_pre_commit  # Add extra options as needed
```

## Documentation
The documentation is available at
https://pub.dev/documentation/dart_pre_commit/latest/. A full example can be
found at https://pub.dev/packages/dart_pre_commit/example.
