import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/main.dart';
import 'package:hungarian_hardstyle_app/models/voting.dart';
import 'package:hungarian_hardstyle_app/providers/ads_provider.dart';
import 'package:hungarian_hardstyle_app/providers/events_provider.dart';
import 'package:hungarian_hardstyle_app/providers/games_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/providers/voting_provider.dart';
import 'package:hungarian_hardstyle_app/services/app_review_prompt.dart';
import 'package:hungarian_hardstyle_app/widgets/app_review_dialog.dart';

void main() {
  testWidgets(
    'real app delays eligible review until home has no open route or keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('de.ffuf.in_app_update/methods'),
        (_) async => throw PlatformException(code: 'NO_UPDATE'),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      SharedPreferences.setMockInitialValues({
        'onboarding_completed_v1': true,
        AppReviewPrompt.firstLaunchKey: DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
        AppReviewPrompt.launchesKey: 4,
      });
      // Keep the initial request pending while the user is editing.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newsProvider.overrideWith((ref) async => []),
            eventsProvider.overrideWith((ref) async => []),
            adsEnabledProvider.overrideWithValue(false),
            votingProvider.overrideWith(
              (ref) async => const VotingSeason.inactive(),
            ),
            activeGameProvider.overrideWith((ref) async => null),
          ],
          child: const HungarianHardstyleApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.byType(AppReviewDialog), findsNothing);

      tester.view.resetViewInsets();
      final home = tester.element(find.byType(NavigationBar));
      final navigator = Navigator.of(home, rootNavigator: true);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('active game')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(AppReviewDialog), findsNothing);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      final pending = await AppReviewPrompt.forSession();
      expect(pending!.preferences.getInt(AppReviewPrompt.launchesKey), 5);
      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(find.byType(AppReviewDialog), findsOneWidget);
      await tester.tap(find.text('Később'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppReviewDialog), findsNothing);
      final prompt = await AppReviewPrompt.forSession();
      expect(prompt!.isDue(DateTime.now()), isFalse);
      expect(prompt.preferences.getInt(AppReviewPrompt.launchesKey), 5);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
