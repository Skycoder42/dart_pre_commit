import 'dart:io';

import 'package:dart_lint_hooks/src/fix_imports.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

class MockFile extends Mock implements File {}

void main() {
  final mockFile = MockFile();
  FixImports sut;

  setUp(() {
    reset(mockFile);

    when(mockFile.path).thenReturn(join("lib", "tst_mock.dart"));
    when(mockFile.parent).thenReturn(Directory("lib"));

    sut = FixImports(
      libDir: Directory("lib"),
      packageName: "mock",
    );
  });

  test("makes package imports in lib relative", () async {
    when(mockFile.readAsString())
        .thenAnswer((_) async => "import 'package:mock/src/details.dart';\n");

    final res = await sut(mockFile);
    expect(res, true);
    verify(mockFile.writeAsString("import 'src/details.dart';\n\n"));
  });
}
