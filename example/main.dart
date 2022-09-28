import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:riverpod/riverpod.dart';

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // optional: create an IoC-Container for easier initialization of the hooks
  final container = ProviderContainer();

  // obtain the hooks instance from the IoC with your custom config
  final hook = container.read(
    HooksProvider.hookProvider(
      const HooksConfig(
        analyze: false,
      ),
    ),
  );

  // alternatively, you can instantiate Hooks directly:
  // final hook = Hooks(...);

  // run all hooks
  final result = await hook();

  // report the result
  exitCode = result.isSuccess ? 0 : 1;
}
