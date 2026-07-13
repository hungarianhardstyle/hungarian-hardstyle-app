import 'event.dart';

class ArtistCategory {
  final int id;
  final String name;
  final String slug;

  const ArtistCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ArtistCategory.fromJson(Map<String, dynamic> json) {
    return ArtistCategory(
      id: _readInt(json['id']),
      name: _readString(json['name']),
      slug: _readString(json['slug']),
    );
  }
}

class Artist {
  final int id;
  final String title;
  final String slug;
  final String biography;
  final String excerpt;
  final String realName;
  final String country;
  final String city;
  final List<String> genres;
  final List<ArtistCategory> categories;
  final String logoUrl;
  final String profileImageUrl;
  final bool featured;
  final bool visible;
  final String webUrl;
  final String bookingEmail;
  final bool bookingViaHuhs;
  final Map<String, String> socialLinks;
  final List<HuhsEvent> upcomingEvents;

  const Artist({
    required this.id,
    required this.title,
    required this.slug,
    required this.biography,
    required this.excerpt,
    required this.realName,
    required this.country,
    required this.city,
    required this.genres,
    required this.categories,
    required this.logoUrl,
    required this.profileImageUrl,
    required this.featured,
    required this.visible,
    required this.webUrl,
    required this.bookingEmail,
    required this.bookingViaHuhs,
    required this.socialLinks,
    required this.upcomingEvents,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    final categoryValues = json['categories'];
    final genreValues = json['genres'];
    final socialValues = json['social_links'];
    final eventValues = json['upcoming_events'];

    final socialLinks = <String, String>{};
    if (socialValues is Map<String, dynamic>) {
      for (final entry in socialValues.entries) {
        final url = _readString(entry.value).trim();
        if (url.isNotEmpty) {
          socialLinks[entry.key] = url;
        }
      }
    }

    return Artist(
      id: _readInt(json['id']),
      title: _readString(json['title']),
      slug: _readString(json['slug']),
      biography: _readString(json['biography']),
      excerpt: _readString(json['excerpt']),
      realName: _readString(json['real_name']),
      country: _readString(json['country']),
      city: _readString(json['city']),
      genres: genreValues is List<dynamic>
          ? genreValues
                .map(_readString)
                .where((genre) => genre.isNotEmpty)
                .toList(growable: false)
          : const [],
      categories: categoryValues is List<dynamic>
          ? categoryValues
                .whereType<Map<String, dynamic>>()
                .map(ArtistCategory.fromJson)
                .where((category) => category.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      logoUrl: _readString(json['logo']),
      profileImageUrl: _readString(
        json['profile_image'] ??
            json['hero_image'] ??
            json['featured_image'],
      ),
      featured: _readBool(json['featured']),
      visible: _readBool(json['visible']),
      webUrl: _readString(json['link']),
      bookingEmail: _readString(json['booking_email']),
      bookingViaHuhs: _readBool(json['booking_via_huhs']),
      socialLinks: socialLinks,
      upcomingEvents: eventValues is List<dynamic>
          ? eventValues
                .whereType<Map<String, dynamic>>()
                .map(HuhsEvent.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  String get location {
    return [
      city,
      country,
    ].where((value) => value.trim().isNotEmpty).join(', ');
  }

  String get effectiveBookingEmail => bookingViaHuhs
      ? 'info@hungarianhardstyle.hu'
      : bookingEmail.trim();
}

class ArtistsPage {
  final List<Artist> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  const ArtistsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory ArtistsPage.fromJson(Map<String, dynamic> json) {
    final values = json['items'] as List<dynamic>? ?? const [];

    return ArtistsPage(
      items: values
          .whereType<Map<String, dynamic>>()
          .map(Artist.fromJson)
          .toList(growable: false),
      page: _readInt(json['page']),
      perPage: _readInt(json['per_page']),
      total: _readInt(json['total']),
      totalPages: _readInt(json['total_pages']),
      hasMore: _readBool(json['has_more']),
    );
  }
}

String _readString(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return '';
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
