class ReleaseArtist {
  final int id;
  final String name;

  const ReleaseArtist({required this.id, required this.name});

  factory ReleaseArtist.fromJson(Map<String, dynamic> json) => ReleaseArtist(
    id: _readInt(json['id']),
    name: _readString(json['name'] ?? json['title']),
  );
}

class ReleaseTrack {
  final String title;
  final String previewUrl;

  const ReleaseTrack({required this.title, required this.previewUrl});

  factory ReleaseTrack.fromJson(Map<String, dynamic> json) => ReleaseTrack(
    title: _readString(json['title'] ?? json['name']),
    previewUrl: _readString(json['preview_url'] ?? json['preview']),
  );
}

class ReleaseVersion {
  final String type;
  final bool available;

  const ReleaseVersion({required this.type, required this.available});

  factory ReleaseVersion.fromJson(Map<String, dynamic> json) => ReleaseVersion(
    type: _readString(json['type']),
    available: json['available'] == true,
  );
}

class HuhsRelease {
  final int id;
  final String title;
  final String coverUrl;
  final String genre;
  final List<ReleaseArtist> artists;
  final List<ReleaseTrack> tracks;
  final Map<String, String> links;
  final List<ReleaseProduct> products;
  final List<ReleaseVersion> versions;
  final String audioStatus;

  const HuhsRelease({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.genre,
    required this.artists,
    required this.tracks,
    required this.links,
    required this.products,
    required this.versions,
    required this.audioStatus,
  });

  factory HuhsRelease.fromJson(Map<String, dynamic> json) {
    final artistValues = json['artists'];
    final trackValues = json['tracks'];
    final linkValues = json['links'];
    final productValues = json['products'];
    final versionValues = json['versions'];
    final links = <String, String>{};
    if (linkValues is Map<String, dynamic>) {
      for (final entry in linkValues.entries) {
        final value = _readString(entry.value).trim();
        if (value.isNotEmpty) links[entry.key] = value;
      }
    }
    return HuhsRelease(
      id: _readInt(json['id']),
      title: _readString(json['title']),
      coverUrl: _readString(json['cover'] ?? json['cover_url']),
      genre: _readString(json['genre']),
      artists: artistValues is List
          ? artistValues
                .whereType<Map<String, dynamic>>()
                .map(ReleaseArtist.fromJson)
                .where((artist) => artist.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      tracks: trackValues is List
          ? trackValues
                .whereType<Map<String, dynamic>>()
                .map(ReleaseTrack.fromJson)
                .where((track) => track.title.isNotEmpty)
                .toList(growable: false)
          : const [],
      links: links,
      products: productValues is List
          ? productValues
                .whereType<Map<String, dynamic>>()
                .map(ReleaseProduct.fromJson)
                .where((product) => product.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      versions: versionValues is List
          ? versionValues
                .whereType<Map<String, dynamic>>()
                .map(ReleaseVersion.fromJson)
                .where(
                  (version) => version.type.isNotEmpty && version.available,
                )
                .toList(growable: false)
          : const [],
      audioStatus: _readString(json['audio_status']),
    );
  }
}

class ReleaseProduct {
  final String id;
  final String type;
  final String label;
  final String price;

  const ReleaseProduct({
    required this.id,
    required this.type,
    required this.label,
    required this.price,
  });

  factory ReleaseProduct.fromJson(Map<String, dynamic> json) => ReleaseProduct(
    id: _readString(json['id']),
    type: _readString(json['type']),
    label: _readString(json['label']),
    price: _readString(json['price']),
  );
}

int _readInt(Object? value) => value is int
    ? value
    : value is num
    ? value.toInt()
    : int.tryParse('$value') ?? 0;

String _readString(Object? value) =>
    value is String ? value : value?.toString() ?? '';
