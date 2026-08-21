class VotingCandidate {
  final int id;
  final String name;
  final String artist;
  final String type;
  final String image;
  final String spotify;
  final String youtube;

  const VotingCandidate({
    required this.id,
    required this.name,
    required this.artist,
    required this.type,
    required this.image,
    required this.spotify,
    required this.youtube,
  });

  factory VotingCandidate.fromJson(Map<String, dynamic> json) =>
      VotingCandidate(
        id: int.tryParse('${json['id']}') ?? 0,
        name: '${json['name'] ?? ''}',
        artist: '${json['artist'] ?? ''}',
        type: '${json['type'] ?? ''}',
        image: '${json['image'] ?? ''}',
        spotify: '${json['spotify'] ?? ''}',
        youtube: '${json['youtube'] ?? ''}',
      );
}

class VotingCategory {
  final String key;
  final String label;
  final List<VotingCandidate> candidates;

  const VotingCategory({
    required this.key,
    required this.label,
    required this.candidates,
  });

  int get maxVotes => switch (key) {
    'hungarian_hardstyle_dj' => 5,
    'hungarian_hardcore_dj' => 3,
    'hungarian_track' => 2,
    'hungarian_organizer' => 1,
    'international_dj' => 3,
    _ => 1,
  };

  factory VotingCategory.fromJson(Map<String, dynamic> json) => VotingCategory(
    key: '${json['key'] ?? ''}',
    label: '${json['label'] ?? ''}',
    candidates: (json['candidates'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VotingCandidate.fromJson)
        .toList(growable: false),
  );
}

class VotingSeason {
  final bool active;
  final int seasonId;
  final int year;
  final String title;
  final List<VotingCategory> categories;

  const VotingSeason({
    required this.active,
    required this.seasonId,
    required this.year,
    required this.title,
    required this.categories,
  });

  const VotingSeason.inactive()
    : active = false,
      seasonId = 0,
      year = 0,
      title = '',
      categories = const [];

  factory VotingSeason.fromJson(Map<String, dynamic> json) => VotingSeason(
    active: json['active'] == true,
    seasonId: int.tryParse('${json['seasonId']}') ?? 0,
    year: int.tryParse('${json['year']}') ?? 0,
    title: '${json['title'] ?? ''}',
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VotingCategory.fromJson)
        .toList(growable: false),
  );
}
