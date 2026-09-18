import 'dart:async';

import '../models/event.dart';
import '../models/post.dart';
import 'wordpress_service.dart';

typedef WarmLoader<T> = Future<T> Function();

/// Warms the public WordPress content the home screen needs first.
///
/// The request is started right after the first frame, so it runs **behind** the
/// startup gate instead of after it. By the time the home screen is built the
/// news and event lists are already in the layered cache, which means a first
/// install shows content as soon as the splash ends instead of waiting for the
/// network.
///
/// These are the same calls the home providers would make and the service shares
/// in-flight requests, so nothing extra is downloaded. Failures are swallowed on
/// purpose: a warm-up must never affect startup, and every screen retries on its
/// own.
class PublicContentWarmer {
  const PublicContentWarmer._();

  static Future<void> warm({
    WarmLoader<List<Post>>? loadNews,
    WarmLoader<List<HuhsEvent>>? loadEvents,
  }) {
    final news = loadNews ?? () => WordpressService().getLatestPosts();
    final events = loadEvents ?? () => WordpressService().getEvents();
    return Future.wait<void>([
      _ignoreFailure(news),
      _ignoreFailure(events),
    ]);
  }

  static Future<void> _ignoreFailure<T>(WarmLoader<T> load) async {
    try {
      await load();
    } catch (_) {
      // The home screen shows its own error state and retries; a failed warm-up
      // has no other consequence.
    }
  }
}
