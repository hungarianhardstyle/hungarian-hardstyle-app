import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/services/app_review_prompt.dart';
import 'package:hungarian_hardstyle_app/services/share_links.dart';
import 'package:hungarian_hardstyle_app/widgets/app_review_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = DateTime.utc(2026, 11, 3);

  Future<AppReviewPrompt> create({bool oldRequest = false}) async {
    SharedPreferences.setMockInitialValues({
      if (oldRequest) 'app_review_requested_v1': true,
    });
    return AppReviewPrompt(await SharedPreferences.getInstance());
  }

  Future<void> launches(AppReviewPrompt prompt, int count) async {
    for (var i = 0; i < count; i++) {
      await prompt.recordLaunch(first);
    }
  }

  test(
    'requires both seven days and five launches, including exact boundary',
    () async {
      final prompt = await create();
      expect(prompt.isDue(first.add(const Duration(days: 30))), isFalse);
      await launches(prompt, 4);
      expect(prompt.isDue(first.add(const Duration(days: 7))), isFalse);
      await prompt.recordLaunch(first);
      expect(
        prompt.isDue(
          first
              .add(const Duration(days: 7))
              .subtract(const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
      expect(prompt.isDue(first.add(const Duration(days: 7))), isTrue);
    },
  );

  test(
    'later or dismissal waits 30 days, survives a new service instance',
    () async {
      final prompt = await create();
      await launches(prompt, 5);
      final shown = first.add(const Duration(days: 7));
      for (final choice in [AppReviewChoice.later, null]) {
        await prompt.markShown(shown);
        await prompt.respond(choice);
        final restarted = AppReviewPrompt(prompt.preferences);
        expect(restarted.isDue(shown.add(const Duration(days: 29))), isFalse);
        expect(restarted.isDue(shown.add(const Duration(days: 30))), isTrue);
      }
    },
  );

  test('never persists and does not open the store', () async {
    final prompt = await create();
    await launches(prompt, 5);
    await prompt.respond(
      AppReviewChoice.never,
      openStore: (_) async {
        fail('Store must not open');
      },
    );
    expect(
      AppReviewPrompt(prompt.preferences)
          .isDue(first.add(const Duration(days: 365))),
      isFalse,
    );
  });

  test(
    'rate opens the real Play listing and disables future prompts',
    () async {
      final prompt = await create();
      await launches(prompt, 5);
      Uri? opened;
      expect(
        await prompt.respond(
          AppReviewChoice.rate,
          openStore: (uri) async {
            opened = uri;
            return true;
          },
        ),
        isTrue,
      );
      expect(opened.toString(), playStoreUrl);
      expect(opened!.host, 'play.google.com');
      expect(opened!.queryParameters['id'], 'hu.hungarianhardstyle.app');
      expect(prompt.isDue(first.add(const Duration(days: 365))), isFalse);
    },
  );

  test(
    'failed store opening keeps retry possible after the cooldown',
    () async {
      final prompt = await create();
      await launches(prompt, 5);
      final shown = first.add(const Duration(days: 7));
      await prompt.markShown(shown);
      expect(
        await prompt.respond(
          AppReviewChoice.rate,
          openStore: (_) async => false,
        ),
        isFalse,
      );
      expect(prompt.isDue(shown), isFalse);
      expect(prompt.isDue(shown.add(const Duration(days: 30))), isTrue);
    },
  );

  test(
    'previous native request receives a 30-day migration cooldown',
    () async {
      final prompt = await create(oldRequest: true);
      await launches(prompt, 5);
      expect(prompt.isDue(first.add(const Duration(days: 29))), isFalse);
      expect(prompt.isDue(first.add(const Duration(days: 30))), isTrue);
    },
  );

  test(
    'rebuilding main navigation cannot count another session launch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prompt = await AppReviewPrompt.forSession();
      expect(await AppReviewPrompt.forSession(), same(prompt));
      expect(prompt!.preferences.getInt(AppReviewPrompt.launchesKey), 1);
    },
  );

  test('platform exception leaves store opening retryable', () async {
    final prompt = await create();
    await launches(prompt, 5);
    expect(
      await prompt.respond(
        AppReviewChoice.rate,
        openStore: (_) async {
          throw StateError('No browser');
        },
      ),
      isFalse,
    );
    expect(prompt.preferences.getBool(AppReviewPrompt.disabledKey), isNull);
  });

  test('event rating does not open a second Android review prompt', () async {
    final prompt = await create();
    await AppReviewPrompt.requestAfterPositiveMoment(
      preferences: prompt.preferences,
      isAvailable: () async => true,
      requestReview: () async => fail('Android uses only the timed dialog'),
    );
    expect(prompt.preferences.getBool('app_review_requested_v1'), isNull);
  });

  test(
    'iOS native review stays once-only and catches platform errors',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final prompt = await create();
      var calls = 0;
      Future<void> request() async {
        calls++;
        throw StateError('Store unavailable');
      }

      for (var i = 0; i < 2; i++) {
        await AppReviewPrompt.requestAfterPositiveMoment(
          preferences: prompt.preferences,
          isAvailable: () async => true,
          requestReview: request,
        );
      }
      expect(calls, 1);
      expect(prompt.preferences.getBool('app_review_requested_v1'), isTrue);
    },
  );

  for (final entry in {
    'Értékelem': AppReviewChoice.rate,
    'Később': AppReviewChoice.later,
    'Ne kérdezd többet': AppReviewChoice.never,
  }.entries) {
    testWidgets('actual dialog returns ${entry.value.name}', (tester) async {
      AppReviewChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await showDialog<AppReviewChoice>(
                    context: context,
                    builder: (_) => const AppReviewDialog(),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AppReviewDialog), findsOneWidget);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(result, entry.value);
      expect(find.byType(AppReviewDialog), findsNothing);
    });
  }
}
