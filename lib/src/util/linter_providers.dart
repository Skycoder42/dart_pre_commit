// coverage:ignore-file

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/lint.dart';
import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';

import 'logging/logging_wrapper.dart';

@internal
final analysisContextCollectionProvider = Provider.family(
  (ref, List<String> includedPaths) => AnalysisContextCollection(
    includedPaths: includedPaths,
  ),
);

@internal
final testImportLinterProvider = Provider(
  (ref) => TestImportLinter(ref.watch(loggingWrapperProvider)),
);

@internal
final libExportLinterProvider = Provider(
  (ref) => LibExportLinter(ref.watch(loggingWrapperProvider)),
);
