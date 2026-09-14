class HuhsGame {
  const HuhsGame({
    required this.id,
    required this.title,
    required this.type,
    required this.typeLabel,
    required this.summary,
    required this.artwork,
    required this.startAt,
    required this.endAt,
    required this.resultsUntil,
    required this.status,
    required this.questions,
    required this.timelineItems,
    required this.rewardPoints,
    required this.rewardBands,
    required this.clueMode,
    required this.clueImageUrl,
    required this.audioReady,
  });

  final int id;
  final String title;
  final String type;
  final String typeLabel;
  final String summary;
  final String artwork;
  final String startAt;
  final String endAt;
  final String resultsUntil;
  final String status;
  final List<HuhsGameQuestion> questions;
  final List<HuhsTimelineItem> timelineItems;
  final int rewardPoints;
  final List<HuhsRewardBand> rewardBands;
  final String clueMode;
  final String clueImageUrl;
  final bool audioReady;

  factory HuhsGame.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final rawTimelineItems = json['timeline_items'];
    final rawRewardBands = json['reward_bands'];
    return HuhsGame(
      id: _gameInt(json['id']),
      title: _gameString(json['title']),
      type: _gameString(json['type']),
      typeLabel: _gameString(json['type_label']),
      summary: _gameString(json['summary']),
      artwork: _gameString(json['artwork']),
      startAt: _gameString(json['start_at']),
      endAt: _gameString(json['end_at']),
      resultsUntil: _gameString(json['results_until']),
      status: _gameString(json['status']),
      questions: rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map(
                  (question) => HuhsGameQuestion.fromJson(
                    Map<String, dynamic>.from(question),
                  ),
                )
                .toList(growable: false)
          : const [],
      timelineItems: rawTimelineItems is List
          ? rawTimelineItems
                .whereType<Map>()
                .map(
                  (item) => HuhsTimelineItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      rewardPoints: _gameInt(json['reward_points']),
      rewardBands: rawRewardBands is List
          ? rawRewardBands
                .whereType<Map>()
                .map(
                  (band) =>
                      HuhsRewardBand.fromJson(Map<String, dynamic>.from(band)),
                )
                .toList(growable: false)
          : const [],
      clueMode: _gameString(json['clue_mode']),
      clueImageUrl: _gameString(json['clue_image_url']),
      audioReady: json['audio_ready'] == true,
    );
  }
}

class HuhsGameQuestion {
  const HuhsGameQuestion({required this.prompt, required this.options});

  final String prompt;
  final List<String> options;

  factory HuhsGameQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return HuhsGameQuestion(
      prompt: _gameString(json['prompt']),
      options: rawOptions is List
          ? rawOptions.map(_gameString).toList(growable: false)
          : const [],
    );
  }
}

class HuhsTimelineItem {
  const HuhsTimelineItem({
    required this.id,
    required this.artist,
    required this.trackTitle,
  });

  final String id;
  final String artist;
  final String trackTitle;

  factory HuhsTimelineItem.fromJson(Map<String, dynamic> json) {
    return HuhsTimelineItem(
      id: _gameString(json['id']),
      artist: _gameString(json['artist']),
      trackTitle: _gameString(json['track_title']),
    );
  }
}

class HuhsRewardBand {
  const HuhsRewardBand({
    required this.minPercent,
    required this.maxPercent,
    required this.points,
  });

  final int minPercent;
  final int maxPercent;
  final int points;

  factory HuhsRewardBand.fromJson(Map<String, dynamic> json) {
    return HuhsRewardBand(
      minPercent: _gameInt(json['min']),
      maxPercent: _gameInt(json['max']),
      points: _gameInt(json['points']),
    );
  }
}

String _gameString(Object? value) => value is String ? value : '';

int _gameInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
