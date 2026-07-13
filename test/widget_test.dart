import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/main.dart';
import 'package:hungarian_hardstyle_app/providers/events_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/providers/ads_provider.dart';

void main() {
  testWidgets('starts the Hungarian Hardstyle app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsProvider.overrideWith((ref) async => []),
          eventsProvider.overrideWith((ref) async => []),
          adsEnabledProvider.overrideWithValue(false),
        ],
        child: const HungarianHardstyleApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });
}
