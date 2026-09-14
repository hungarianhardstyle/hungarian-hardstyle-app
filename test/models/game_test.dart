import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/game.dart';

void main() {
  test('does not expose an answer field when parsing public game data', () {
    final game = HuhsGame.fromJson({
      'id': 7,
      'title': 'Napi kihívás',
      'questions': [
        {
          'prompt': 'Melyik kiadvány?',
          'options': ['A', 'B'],
          'correct': 1,
        },
      ],
    });

    expect(game.id, 7);
    expect(game.questions.single.options, ['A', 'B']);
  });

  test('parses timeline items without exposing their release month', () {
    final game = HuhsGame.fromJson({
      'id': 7,
      'timeline_items': [
        {'id': 'abc123', 'artist': 'Denoiser', 'track_title': 'Track A'},
      ],
      'reward_points': 15,
      'reward_bands': [
        {'min': 80, 'max': 100, 'points': 15},
      ],
    });

    expect(game.timelineItems.single.artist, 'Denoiser');
    expect(game.timelineItems.single.trackTitle, 'Track A');
    expect(game.rewardPoints, 15);
    expect(game.rewardBands.single.points, 15);
  });
}
