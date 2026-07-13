import 'event.dart';

class OrganizerProfile {
  final int id;
  final String title;
  final String slug;
  final String description;
  final String excerpt;
  final String city;
  final String country;
  final String logoUrl;
  final String featuredImageUrl;
  final bool featured;
  final bool visible;
  final String webUrl;
  final Map<String, String> socialLinks;
  final List<HuhsEvent> upcomingEvents;

  const OrganizerProfile({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.excerpt,
    required this.city,
    required this.country,
    required this.logoUrl,
    required this.featuredImageUrl,
    required this.featured,
    required this.visible,
    required this.webUrl,
    required this.socialLinks,
    required this.upcomingEvents,
  });

  factory OrganizerProfile.fromJson(Map<String, dynamic> json) {
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

    return OrganizerProfile(
      id: _readInt(json['id']),
      title: _readString(json['title']),
      slug: _readString(json['slug']),
      description: _readString(json['description']),
      excerpt: _readString(json['excerpt']),
      city: _readString(json['city']),
      country: _readString(json['country']),
      logoUrl: _readString(json['logo']),
      featuredImageUrl: _readString(
        json['featured_image'] ?? json['logo'],
      ),
      featured: _readBool(json['featured']),
      visible: _readBool(json['visible']),
      webUrl: _readString(json['link']),
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
}

class OrganizersPage {
  final List<OrganizerProfile> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  const OrganizersPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory OrganizersPage.fromJson(Map<String, dynamic> json) {
    final values = json['items'] as List<dynamic>? ?? const [];

    return OrganizersPage(
      items: values
          .whereType<Map<String, dynamic>>()
          .map(OrganizerProfile.fromJson)
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
