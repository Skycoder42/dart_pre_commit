# Documentation of the dart_pre_commit binary
You can run this script via `dart pub run dart_pre_commit [options]`. It
will create an instance of [Hooks] and invoke it to perform the pre commit
hooks. Check the documentation of the [Hooks] class for more details on what
the sepecific hooks do.

In order to be able to configure how the hooks should be run, you can
specify command line arguments to the script. The following tables list all
available options, organized into the same groups as shown when running
`dart pub run dart_pre_commit --help`.

## Task selection
 Option                             | Default    | Description
------------------------------------|------------|-------------
`-f`, `--[no-]format`               | on         | Format staged files with dart format.
`-t`, `--[no-]test-imports`         | on         | Runs dart_test_tools TestImportLinter on all staged files.
`-a`, `--[no-]analyze`              | on         | Run dart analyze to find issue for the staged files.
`-u`, `--[no-]flutter-compat`       | on         | Check if the package can be added to a flutter project without breaking the flutter dependency constraints. This task is run by default only if the current package is not a flutter package.
`-o`, `--outdated=<level>`          | `any`      | Enables the outdated packages check. You can choose one of the levels described below to require certain package updates. If they are not met, the hook will fail. No matter what level, as long as it is not disabled - which will completly disable the hook - it will still print available package updates without failing. Can be any of [OutdatedLevel].
`-p`, `--[no-]check-pull-up`        | on         | Check if direct dependencies in the pubspec.lock have higher versions then specified in pubspec.yaml and warn if that's the case.
`-c`, `--[no-]continue-on-rejected` | off        | Continue checks even if a task rejects a certain file. The whole hook will still exit with rejected, but only after all files have been processed.

## Other
 Option                           | Default             | Description
----------------------------------|---------------------|-------------
`-d`, `--directory=<dir>`         | `Directory.current` | Set the directory to run this command in. By default, it will run in the current working directory.
`-e`, `--[no-]detailed-exit-code` | off                 | Instead of simply 0/1 as exit code for 'commit ok' or 'commit needs user intervention', output exit codes according to the full hook result (See [HookResult]).
`-l`, `--log-level=<level>`       | `info`              | Specify the logging level for task logs. This only affects log details of tasks, not the status update message. Can be any of [LogLevel].
`--[no-]ansi`                     | auto-detected       | When enabled, a rich, ANSI-backed output is used. If disabled, a simple logger is used, which is optimized for logging to files. The mode is auto-detected, but might not detect all terminals correctly. In this case, you can use this option to set it exlicitly.
`-v`, `--version`                 | -                   | Show the version of the dart_pre_commit package.
`-h`, `--help`                    | -                   | Show this help.
