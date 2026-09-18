import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

/// The cache policy has two distinct paths:
///
/// * display (`forceRefresh: false`) serves whatever is stored, whatever its
///   age, and only revalidates in the background;
/// * refresh (`forceRefresh: true`) waits for WordPress.
///
/// These tests pin the display half of that contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const staleKey = 'huhs.wp.policy.stale';
  const freshKey = 'huhs.wp.policy.fresh';
  const brokenKey = 'huhs.wp.policy.broken';
  final now = DateTime.now();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      staleKey: jsonEncode([
        {'id': 3, 'name': 'Hírek'},
      ]),
      '$staleKey.savedAt': now
          .subtract(const Duration(hours: 6))
          .millisecondsSinceEpoch,
      freshKey: jsonEncode([
        {'id': 4, 'name': 'Cikkek'},
      ]),
      '$freshKey.savedAt': now.millisecondsSinceEpoch,
      brokenKey: '{broken',
      '$brokenKey.savedAt': now.millisecondsSinceEpoch,
    });
  });

  test('a hat órás mentett érték is megjelenik, nem vár hálózatra', () async {
    final service = WordpressService();

    final value = await service.readPersistentJsonForTesting(staleKey);

    expect(value, isA<List<dynamic>>());
    expect((value! as List<dynamic>).single, {'id': 3, 'name': 'Hírek'});
  });

  test('a lejárt érték csak háttérfrissítést jelez', () async {
    final service = WordpressService();

    expect(
      await service.persistentJsonNeedsRefreshForTesting(staleKey),
      isTrue,
    );
    expect(
      await service.persistentJsonNeedsRefreshForTesting(freshKey),
      isFalse,
    );
  });

  test('a friss érték is azonnal a cache-ből jön', () async {
    final service = WordpressService();

    final value = await service.readPersistentJsonForTesting(freshKey);

    expect((value! as List<dynamic>).single, {'id': 4, 'name': 'Cikkek'});
    expect(
      await service.persistentJsonNeedsRefreshForTesting(freshKey),
      isFalse,
    );
  });

  test('olvashatatlan mentett érték törlődik, nem blokkol', () async {
    final service = WordpressService();

    expect(await service.readPersistentJsonForTesting(brokenKey), isNull);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(brokenKey), isNull);
    expect(preferences.getInt('$brokenKey.savedAt'), isNull);
  });

  test('a sticky sor és a kategóriák is a megjelenítési úton cache-elnek', () {
    final source = File(
      'lib/services/wordpress_service.dart',
    ).readAsStringSync();

    final stickyStart = source.indexOf('Future<List<Post>> getStickyPosts(');
    final stickyEnd = source.indexOf('Future<List<FaqItem>> getFaq(', stickyStart);
    expect(stickyStart, greaterThanOrEqualTo(0));
    final sticky = source.substring(stickyStart, stickyEnd);
    expect(sticky, contains('bool forceRefresh = false'));
    expect(sticky, contains('forceRefresh: forceRefresh'));
    expect(
      sticky,
      isNot(contains('forceRefresh: true')),
      reason: 'a megjelenítési út nem erőltethet hálózati kérést',
    );

    final categoriesStart = source.indexOf(
      'Future<List<NewsCategory>> getCategories(',
    );
    final categoriesEnd = source.indexOf(
      'Future<Set<int>> getPostIdsForCategory(',
      categoriesStart,
    );
    final categories = source.substring(categoriesStart, categoriesEnd);
    expect(categories, contains('_persistentValueNeedsRefresh(key)'));
    expect(categories, contains('_schedulePersistentRefresh(key'));
  });
}
