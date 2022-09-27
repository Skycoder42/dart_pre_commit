import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:dart_test_tools/lint.dart';
import 'package:riverpod/riverpod.dart';

import 'logging/logging_wrapper.dart';

final analysisContextCollectionProvider = Provider.family(
  (ref, List<String> includedPaths) => AnalysisContextCollection(
    includedPaths: includedPaths,
  ),
);

final testImportLinterProvider = Provider(
  (ref) => TestImportLinter(ref.watch(loggingWrapperProvider)),
);

final libExportLinterProvider = Provider(
  (ref) => LibExportLinter(ref.watch(loggingWrapperProvider)),
);
