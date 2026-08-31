import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/news_reaction_service.dart';

void main() {
  test('one UID contributes at most one like', () {
    final likedBy = NewsReactionService.normalizeLikedBy({
      'user-a': true,
      'user-b': true,
      'user-a-duplicate': true,
      'ignored': false,
    });

    expect(likedBy.length, 3);
    expect(likedBy['user-a'], isTrue);
    expect(likedBy['ignored'], isNull);
  });

  test('legacy UID list is normalized without a like limit', () {
    final likedBy = NewsReactionService.normalizeLikedBy(
      List<String>.generate(8, (index) => 'user-$index'),
    );

    expect(likedBy.length, 8);
  });

  test('empty or stale count-only data has no likes', () {
    expect(NewsReactionService.normalizeLikedBy(null), isEmpty);
    expect(NewsReactionService.normalizeLikedBy({'count': 99}), isEmpty);
  });

  test('a user can remove its like while other users remain liked', () {
    final likedBy = NewsReactionService.normalizeLikedBy({
      'user-a': true,
      'user-b': true,
    });

    likedBy.remove('user-a');

    expect(likedBy, {'user-b': true});
  });
}
