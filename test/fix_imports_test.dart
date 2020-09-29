import 'dart:io';

import 'package:dart_pre_commit/src/fix_imports.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

class MockFile extends Mock implements File {}

void main() {
  final mockFile = MockFile();
  FixImports sut;

  @isTest
  void _runTest(
    String message, {
    @required String inData,
    String outData,
    Function setUp,
  }) {
    test(message, () async {
      when(mockFile.readAsString()).thenAnswer((_) async => inData);
      if (setUp != null) {
        setUp();
      }

      final res = await sut(mockFile);
      if (outData != null) {
        expect(res, true);
        verify(mockFile.writeAsString(outData));
      } else {
        expect(res, false);
        verifyNever(mockFile.writeAsString(any));
      }
    });
  }

  setUp(() {
    reset(mockFile);

    when(mockFile.path).thenReturn(join("lib", "tst_mock.dart"));
    when(mockFile.parent).thenReturn(Directory("lib"));

    sut = FixImports(
      libDir: Directory("lib"),
      packageName: "mock",
    );
  });

  _runTest(
    "makes package imports in lib relative",
    inData: "import 'package:mock/src/details.dart';\n",
    outData: "import 'src/details.dart';\n\n",
  );

  _runTest(
    "does not modify imports outside lib",
    inData: "import 'package:mock/src/details.dart';\n",
    setUp: () {
      when(mockFile.path).thenReturn(join("bin", "tst_mock.dart"));
      when(mockFile.parent).thenReturn(Directory("bin"));
    },
  );

  _runTest(
    "does not modify other package imports",
    inData: "import 'package:mock2/src/details.dart';\n",
  );

  _runTest(
    "sorts imports as expected",
    inData: """
import "package:c/c.dart";
import "dart:io";
import "dart:async";
import "package:a/a.dart";
import "../../tree.dart";
import "package:b/b.dart";
import "package:mock/src/details.dart";
import "package:d/d.dart";
import "dart:path";
import "../car.dart";
import "../den.dart";
""",
    outData: """
import "dart:async";
import "dart:io";
import "dart:path";

import "package:a/a.dart";
import "package:b/b.dart";
import "package:c/c.dart";
import "package:d/d.dart";

import "../../tree.dart";
import "../car.dart";
import "../den.dart";
import "src/details.dart";

""",
  );

  _runTest(
    "keeps prefix and does not modify code",
    inData: """
// prefix
const i = 42;

// more comments
import "dart:io";
import "dart:async";
void main() {
  this is definitly valid dart code
}
""",
    outData: """
// prefix
const i = 42;

// more comments
import "dart:async";
import "dart:io";

void main() {
  this is definitly valid dart code
}
""",
  );

  _runTest(
    "fills correct newlines",
    inData: """
// prefix


import "../code.dart";


import "dart:io";


import "package:a/a.dart";


// some code


""",
    outData: """
// prefix


import "dart:io";

import "package:a/a.dart";

import "../code.dart";

// some code
""",
  );
}
