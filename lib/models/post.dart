String _decodeHtmlText(Object? value) {
  if (value is! String) {
    return '';
  }

  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&hellip;', '...')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!, radix: 16);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  }).replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
}

String _readPlainText(Object? value) {
  return _stripHtmlText(_decodeHtmlText(value));
}

String _stripHtmlText(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class GalleryImage {
  final int id;
  final String url;
  final String title;
  final String alt;
  final String description;
  final int order;

  const GalleryImage({
    required this.id,
    required this.url,
    required this.title,
    required this.alt,
    required this.description,
    required this.order,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: json['id'] ?? 0,
      url: json['url'] ?? '',
      title: _readPlainText(json['title'] ?? ''),
      alt: _readPlainText(json['alt'] ?? ''),
      description: _readPlainText(json['description'] ?? ''),
      order: json['order'] ?? 0,
    );
  }
}

class Post {
  final int id;
  final String title;
  final String excerpt;
  final String content;
  final String imageUrl;
  final String date;
  final String link;
  final List<int> categoryIds;
  final List<String> categories;

  final int galleryId;
  final List<GalleryImage> galleryImages;

  const Post({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.imageUrl,
    required this.date,
    required this.link,
    required this.categoryIds,
    required this.categories,
    required this.galleryId,
    required this.galleryImages,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final List<dynamic> gallery = json['gallery_images'] ?? [];

    return Post(
      id: json['id'] ?? 0,
      title: _readPlainText(json['title']),
      excerpt: _readPlainText(json['excerpt']),
      content: json['content'] ?? '',
      imageUrl: json['featured_image'] ?? '',
      date: json['date'] ?? '',
      link: json['link'] ?? '',
      categoryIds: _readCategoryIds(json),
      categories: _readCategories(json),
      galleryId: json['gallery_id'] ?? 0,
      galleryImages: gallery
          .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory Post.fromWordpressJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      title: _readRenderedText(json['title']),
      excerpt: _readRenderedText(json['excerpt']),
      content: _readRenderedHtml(json['content']),
      imageUrl: _readFeaturedImage(json),
      date: json['date'] ?? '',
      link: json['link'] ?? '',
      categoryIds: _readCategoryIds(json),
      categories: const [],
      galleryId: 0,
      galleryImages: const [],
    );
  }

  bool get hasGallery => galleryImages.isNotEmpty;

  static List<String> _readCategories(Map<String, dynamic> json) {
    final value =
        json['categories'] ?? json['category_names'] ?? json['category'];

    if (value is String) {
      return _splitCategoryString(value);
    }

    if (value is List<dynamic>) {
      return value
          .expand((item) {
            if (item is String) {
              return _splitCategoryString(item);
            }

            if (item is Map<String, dynamic>) {
              final name = item['name'] ?? item['title'] ?? item['slug'];
              return name is String ? _splitCategoryString(name) : <String>[];
            }

            return <String>[];
          })
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList();
    }

    return const [];
  }

  static List<int> _readCategoryIds(Map<String, dynamic> json) {
    final value = json['category_ids'] ?? json['categories'];

    if (value is int) {
      return [value];
    }

    if (value is List<dynamic>) {
      return value
          .map((item) {
            if (item is int) {
              return item;
            }

            if (item is num) {
              return item.toInt();
            }

            if (item is String) {
              return int.tryParse(item);
            }

            if (item is Map<String, dynamic>) {
              final id = item['id'] ?? item['term_id'];

              if (id is int) {
                return id;
              }

              if (id is num) {
                return id.toInt();
              }

              if (id is String) {
                return int.tryParse(id);
              }
            }

            return null;
          })
          .whereType<int>()
          .toSet()
          .toList();
    }

    return const [];
  }

  static List<String> _splitCategoryString(String value) {
    return _readPlainText(value)
        .split(',')
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();
  }

  static String _readRenderedText(Object? value) {
    if (value is String) {
      return _readPlainText(value);
    }

    if (value is Map<String, dynamic>) {
      final rendered = value['rendered'];
      return _readPlainText(rendered);
    }

    return '';
  }

  static String _readRenderedHtml(Object? value) {
    if (value is String) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      final rendered = value['rendered'];
      return rendered is String ? rendered : '';
    }

    return '';
  }

  static String _readFeaturedImage(Map<String, dynamic> json) {
    final embedded = json['_embedded'];

    if (embedded is Map<String, dynamic>) {
      final media = embedded['wp:featuredmedia'];

      if (media is List<dynamic> && media.isNotEmpty) {
        final firstMedia = media.first;

        if (firstMedia is Map<String, dynamic>) {
          final sourceUrl = firstMedia['source_url'];

          if (sourceUrl is String) {
            return sourceUrl;
          }
        }
      }
    }

    return '';
  }
}