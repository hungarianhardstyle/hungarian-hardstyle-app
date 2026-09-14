import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/core/firebase/firebase_callable.dart';

void main() {
  test('a Google-belépés Web OAuth klienst használ, nem Android klienst', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final selectedClient = RegExp(r"serverClientId:\s*'([^']+)'")
        .firstMatch(source)
        ?.group(1);
    expect(selectedClient, isNotNull);

    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final app = (config['client'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (client) =>
              (client['client_info']
                      as Map<String, dynamic>)['android_client_info']
                  is Map<String, dynamic> &&
              ((client['client_info']
                          as Map<String, dynamic>)['android_client_info']
                      as Map<String, dynamic>)['package_name'] ==
                  'hu.hungarianhardstyle.app',
        );
    final webClients = (app['oauth_client'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((client) => client['client_type'] == 3)
        .map((client) => client['client_id'])
        .whereType<String>()
        .toSet();
    expect(webClients, contains(selectedClient));
    expect(
      (app['oauth_client'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((client) => client['client_id'] == selectedClient)
          .every((client) => client['client_type'] == 3),
      isTrue,
    );
  });

  test('Auth hiba Auth hibaként osztályozódik', () {
    final error = FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'The auth token is expired.',
    );
    expect(
      classifyFirebaseCallableFailure(error),
      FirebaseCallableFailure.auth,
    );
  });

  test('ismeretlen unauthenticated hiba nem kap találomra retryt', () {
    final error = FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Unauthenticated',
    );
    expect(
      classifyFirebaseCallableFailure(error),
      FirebaseCallableFailure.unknown,
    );
  });

  test('szerver jogosultsági üzenete nem indít Auth retryt', () {
    final error = FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Jelentkezz be a játék használatához.',
    );
    expect(
      classifyFirebaseCallableFailure(error),
      FirebaseCallableFailure.unknown,
    );
  });

  test('diagnosztika nem adja vissza a hosszú token-szerű értéket', () {
    final secret = List.filled(80, 'A').join();
    final message = sanitizeFirebaseDiagnosticMessage('hiba: $secret');
    expect(message, isNot(contains(secret)));
    expect(message, contains('[redacted]'));
  });
}
