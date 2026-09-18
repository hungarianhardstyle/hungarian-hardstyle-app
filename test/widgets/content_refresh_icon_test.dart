import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/content_refresh_icon.dart';

Widget _host(Future<void> Function() onRefresh) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [ContentRefreshIcon(onRefresh: onRefresh)],
      ),
    ),
  );
}

void main() {
  testWidgets('a frissítés ikon pörgést mutat, és nem indít párhuzamos kérést', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;

    await tester.pumpWidget(_host(() {
      calls++;
      return pending.future;
    }));

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(calls, 1);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A futás közbeni második koppintás nem indít új kérést.
    await tester.tap(find.byType(CircularProgressIndicator));
    await tester.pump();
    expect(calls, 1);

    pending.complete();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hiba esetén is visszaáll a frissítés ikon', (tester) async {
    await tester.pumpWidget(
      _host(() => Future<void>.error(Exception('hálózati hiba'))),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
