import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/widgets/session_watcher.dart';

void main() {
  for (final scenario in ['signout', 'deleted', 'verified', 'network']) {
    testWidgets('session listener + router: $scenario', (tester) async {
      final users = StreamController<String?>();
      final navigator = GlobalKey<NavigatorState>();
      var verified = 0;
      var checks = 0;
      final ended = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => SessionWatcher(
            users: users.stream,
            refresh: () async {
              checks++;
              if (scenario == 'network') throw StateError('offline');
              if (scenario == 'deleted') {
                users.add(null);
                await Future<void>.value();
                return {'active': false, 'deleted': true};
              }
              return {'active': true, 'emailVerifiedChanged': true};
            },
            onEnded: (deleted) {
              ended.add(deleted);
              navigator.currentState!.pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Home')),
                ),
                (_) => false,
              );
            },
            onVerified: () => verified++,
            child: child!,
          ),
          home: const Scaffold(body: Text('Startup')),
        ),
      );
      users.add('uid-a');
      await tester.pump();
      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private profile')),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario == 'signout') {
        users.add(null);
      } else {
        await tester.pump(const Duration(seconds: 60));
      }
      await tester.pumpAndSettle();
      if (scenario == 'signout' || scenario == 'deleted') {
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Private profile'), findsNothing);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(ended, [scenario == 'deleted']);
      } else {
        expect(find.text('Private profile'), findsOneWidget);
        expect(ended, isEmpty);
        expect(checks, 1);
        expect(verified, scenario == 'verified' ? 1 : 0);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(users.close());
      await tester.pump();
    });
  }
}
