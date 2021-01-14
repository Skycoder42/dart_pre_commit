import 'dart:io';

import 'package:dart_pre_commit/dart_pre_commit.dart';
import 'package:riverpod/riverpod.dart'; // ignore: import_of_legacy_library_into_null_safe

Future<void> main(List<String> arguments) async {
  // assume first arg is the git directory to handle
  Directory.current = arguments.first;

  // optional: create an IoC-Container for easier initialization of the hooks
  final container = ProviderContainer();

  // obtain the hooks instance from the IoC with your custom config
  final hook =
      await container.read(HooksProvider.hookProvider(const HooksConfig(
    fixImports: true,
    // ignore: avoid_redundant_argument_values
    analyze: false,
  )).future);

  // alternatively, you can instanciate Hooks directly:
  // final hook = Hooks(...);

  // run all hooks
  final result = await hook();

  // report the result
  exitCode = result.isSuccess ? 0 : 1;
}
