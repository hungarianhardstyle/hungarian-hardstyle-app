import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'share_links.dart';

enum AppReviewChoice { rate, later, never }

class AppReviewPrompt {
  AppReviewPrompt(this.preferences);

  final SharedPreferences preferences;
  static Future<AppReviewPrompt?>? _session;
  static bool _nativeInFlight = false;
  static const firstLaunchKey = 'app_review_first_launch_v2';
  static const launchesKey = 'app_review_launches_v2';
  static const lastPromptKey = 'app_review_last_prompt_v2';
  static const disabledKey = 'app_review_disabled_v2';

  // Count once per process, even when authentication rebuilds the main screen.
  static Future<AppReviewPrompt?> forSession() => _session ??= _load();

  // Keep the existing iOS native request; Android now uses the timed dialog.
  static Future<void> requestAfterPositiveMoment({
    SharedPreferences? preferences,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _nativeInFlight) {
      return;
    }
    _nativeInFlight = true;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      if (prefs.getBool('app_review_requested_v1') == true) return;
      if (!await prefs.setBool('app_review_requested_v1', true)) return;
      if (await (isAvailable ?? InAppReview.instance.isAvailable)()) {
        await (requestReview ?? InAppReview.instance.requestReview)();
      }
    } catch (_) {
      // An optional store prompt must not fail the event rating.
    } finally {
      _nativeInFlight = false;
    }
  }

  static Future<AppReviewPrompt?> _load() async {
    try {
      final prompt = AppReviewPrompt(await SharedPreferences.getInstance());
      await prompt.recordLaunch(DateTime.now());
      return prompt;
    } catch (_) {
      // Storage failure must not interrupt startup or cause repeated prompts.
      return null;
    }
  }

  Future<void> recordLaunch(DateTime now) async {
    if (!preferences.containsKey(firstLaunchKey)) {
      await _setInt(firstLaunchKey, now.millisecondsSinceEpoch);
      // Old native requests get a 30-day cooldown when migrating.
      if (preferences.getBool('app_review_requested_v1') == true) {
        await markShown(now);
      }
    }
    await _setInt(launchesKey, (preferences.getInt(launchesKey) ?? 0) + 1);
  }

  bool isDue(DateTime now) {
    if (preferences.getBool(disabledKey) == true) return false;
    final first = preferences.getInt(firstLaunchKey);
    if (first == null || (preferences.getInt(launchesKey) ?? 0) < 5) {
      return false;
    }
    if (now.difference(DateTime.fromMillisecondsSinceEpoch(first)) <
        const Duration(days: 7)) {
      return false;
    }
    final last = preferences.getInt(lastPromptKey);
    return last == null ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) >=
            const Duration(days: 30);
  }

  Future<void> markShown(DateTime now) =>
      _setInt(lastPromptKey, now.millisecondsSinceEpoch);

  Future<bool> respond(
    AppReviewChoice? choice, {
    Future<bool> Function(Uri)? openStore,
  }) async {
    if (choice == AppReviewChoice.never) {
      await disable();
    } else if (choice == AppReviewChoice.rate) {
      final uri = Uri.parse(playStoreUrl);
      final bool opened;
      try {
        opened = await (openStore != null
            ? openStore(uri)
            : launchUrl(uri, mode: LaunchMode.externalApplication));
      } catch (_) {
        return false;
      }
      if (!opened) return false;
      // Store opening cannot tell us whether a review was actually submitted.
      await disable();
    }
    return true;
  }

  Future<void> disable() async {
    if (!await preferences.setBool(disabledKey, true)) {
      throw StateError('Could not persist review preference');
    }
  }

  Future<void> _setInt(String key, int value) async {
    if (!await preferences.setInt(key, value)) {
      throw StateError('Could not persist review preference');
    }
  }
}
