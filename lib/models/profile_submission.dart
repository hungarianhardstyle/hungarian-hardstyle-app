class SubmissionArtistCategory {
  final String name;
  final String slug;

  const SubmissionArtistCategory({required this.name, required this.slug});

  factory SubmissionArtistCategory.fromJson(Map<String, dynamic> json) {
    return SubmissionArtistCategory(
      name: json['name'] is String ? json['name'] as String : '',
      slug: json['slug'] is String ? json['slug'] as String : '',
    );
  }
}

class ProfileSubmissionOptions {
  final List<String> genres;
  final List<SubmissionArtistCategory> artistCategories;

  const ProfileSubmissionOptions({
    required this.genres,
    required this.artistCategories,
  });

  factory ProfileSubmissionOptions.fromJson(Map<String, dynamic> json) {
    final genres = json['genres'] as List<dynamic>? ?? const [];
    final categories = json['artist_categories'] as List<dynamic>? ?? const [];

    return ProfileSubmissionOptions(
      genres: genres
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
      artistCategories: categories
          .whereType<Map<String, dynamic>>()
          .map(SubmissionArtistCategory.fromJson)
          .where((value) => value.name.isNotEmpty && value.slug.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ArtistSubmission {
  final String name;
  final String realName;
  final List<String> categories;
  final List<String> genres;
  final String city;
  final String country;
  final String biography;
  final String contactEmail;
  final String bookingEmail;
  final bool bookingViaHuhs;
  final String profileImageUrl;
  final Map<String, String> socialLinks;

  const ArtistSubmission({
    required this.name,
    required this.realName,
    required this.categories,
    required this.genres,
    required this.city,
    required this.country,
    required this.biography,
    required this.contactEmail,
    required this.bookingEmail,
    required this.bookingViaHuhs,
    required this.profileImageUrl,
    required this.socialLinks,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'real_name': realName.trim(),
      'categories': categories,
      'genres': genres,
      'city': city.trim(),
      'country': country.trim(),
      'biography': biography.trim(),
      'contact_email': contactEmail.trim(),
      'booking_email': bookingEmail.trim(),
      'booking_via_huhs': bookingViaHuhs,
      'profile_image_url': profileImageUrl.trim(),
      for (final entry in socialLinks.entries) entry.key: entry.value.trim(),
      'website_check': '',
    };
  }
}

class OrganizerSubmission {
  final String name;
  final String city;
  final String country;
  final String description;
  final String contactEmail;
  final List<String> genres;
  final String logoUrl;
  final Map<String, String> socialLinks;

  const OrganizerSubmission({
    required this.name,
    required this.city,
    required this.country,
    required this.description,
    required this.contactEmail,
    required this.genres,
    required this.logoUrl,
    required this.socialLinks,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'city': city.trim(),
      'country': country.trim(),
      'description': description.trim(),
      'contact_email': contactEmail.trim(),
      'genres': genres,
      'logo_url': logoUrl.trim(),
      for (final entry in socialLinks.entries) entry.key: entry.value.trim(),
      'website_check': '',
    };
  }
}
