import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/main.dart';
import 'package:hungarian_hardstyle_app/providers/events_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/providers/ads_provider.dart';
import 'package:hungarian_hardstyle_app/providers/voting_provider.dart';
import 'package:hungarian_hardstyle_app/providers/games_provider.dart';
import 'package:hungarian_hardstyle_app/models/voting.dart';

void main() {
  testWidgets('starts the Hungarian Hardstyle app', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsProvider.overrideWith((ref) async => []),
          eventsProvider.overrideWith((ref) async => []),
          adsEnabledProvider.overrideWithValue(false),
          votingProvider.overrideWith((ref) async => const VotingSeason.inactive()),
          activeGameProvider.overrideWith((ref) async => null),
        ],
        child: const HungarianHardstyleApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(6));
  });
}
