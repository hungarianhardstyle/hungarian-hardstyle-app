import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/detail_prefetch.dart';

Widget _host({
  required Future<void> Function() onPrefetch,
  Duration delay = const Duration(milliseconds: 700),
}) {
  return MaterialApp(
    home: DetailPrefetch(
      delay: delay,
      onPrefetch: onPrefetch,
      child: const Text('kártya'),
    ),
  );
}

void main() {
  testWidgets('a képernyőn maradó kártya adatait előtölti', (tester) async {
    var calls = 0;

    await tester.pumpWidget(_host(onPrefetch: () async => calls++));

    expect(calls, 0, reason: 'a késleltetés előtt nem indul kérés');
    await tester.pump(const Duration(milliseconds: 699));
    expect(calls, 0);

    await tester.pump(const Duration(milliseconds: 2));
    expect(calls, 1);
    expect(find.text('kártya'), findsOneWidget);
  });

  testWidgets('a gyorsan elgörgetett kártya nem indít kérést', (tester) async {
    var calls = 0;

    await tester.pumpWidget(_host(onPrefetch: () async => calls++));
    await tester.pump(const Duration(milliseconds: 300));

    // A lista eldobja a képernyőről kikerült kártyát.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 3));

    expect(calls, 0);
  });

  testWidgets('a hibázó előtöltés néma marad', (tester) async {
    await tester.pumpWidget(
      _host(
        delay: const Duration(milliseconds: 10),
        onPrefetch: () => Future<void>.error(Exception('nincs hálózat')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('kártya'), findsOneWidget);
  });
}
