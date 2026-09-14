import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/core/firebase/firebase_callable.dart';

void main() {
  test('a callable Firebase runtime eseményt naplóz', () {
    expect(firebaseRuntimeDiagnostics, isEmpty);
    recordFirebaseRequestStarted('test');
    expect(firebaseRuntimeDiagnostics.single, contains('request:test:'));
  });
}
