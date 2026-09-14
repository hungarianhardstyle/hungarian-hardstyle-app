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
    'international_dj' => 5,
    _ => 1,
  };

  int get minVotes => maxVotes;

  factory VotingCategory.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final candidateItems = rawCandidates is List
        ? rawCandidates
        : rawCandidates is Map
        ? rawCandidates.values.toList(growable: false)
        : const <dynamic>[];
    return VotingCategory(
      key: '${json['key'] ?? json['slug'] ?? ''}',
      label: '${json['label'] ?? json['name'] ?? ''}',
      candidates: candidateItems
          .whereType<Map>()
          .map(
            (item) => VotingCandidate.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class VotingSeason {
  final bool active;
  final int seasonId;
  final int year;
  final String title;
  final List<VotingCategory> categories;
  final String resultsUrl;
  final bool resultsApproved;

  const VotingSeason({
    required this.active,
    required this.seasonId,
    required this.year,
    required this.title,
    required this.categories,
    this.resultsUrl = '',
    this.resultsApproved = false,
  });

  const VotingSeason.inactive()
    : active = false,
      seasonId = 0,
      year = 0,
      title = '',
      categories = const [],
      resultsUrl = '',
      resultsApproved = false;

  bool get isClosed => !active && seasonId > 0;

  bool get hasPublishedResults =>
      resultsApproved && resultsUrl.trim().isNotEmpty;

  factory VotingSeason.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categoryItems = rawCategories is List
        ? rawCategories
        : rawCategories is Map
        ? rawCategories.entries
              .map((entry) {
                final value = entry.value;
                if (value is Map) {
                  return <String, dynamic>{
                    ...Map<String, dynamic>.from(value),
                    'key': value['key'] ?? entry.key,
                  };
                }
                return <String, dynamic>{'key': entry.key, 'label': entry.key};
              })
              .toList(growable: false)
        : const <dynamic>[];
    return VotingSeason(
      active: json['active'] == true,
      seasonId: int.tryParse('${json['seasonId'] ?? json['id']}') ?? 0,
      year: int.tryParse('${json['year']}') ?? 0,
      title: '${json['title'] ?? json['name'] ?? ''}',
      categories: categoryItems
          .whereType<Map>()
          .map(
            (item) => VotingCategory.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((category) => category.key.isNotEmpty)
          .toList(growable: false),
      resultsUrl:
          '${json['results_url'] ?? json['resultsUrl'] ?? json['summary_url'] ?? json['summaryUrl'] ?? ''}',
      resultsApproved:
          json['results_approved'] == true || json['resultsApproved'] == true,
    );
  }
}
