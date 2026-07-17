import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

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
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      })
      .replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
        final codePoint = int.tryParse(match.group(1)!);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
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
      .replaceAllMapped(RegExp(r'\s+([.,!?;:])'), (match) => match.group(1)!)
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

class PostEmbed {
  final String type;
  final String url;

  const PostEmbed({required this.type, required this.url});

  factory PostEmbed.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const PostEmbed(type: '', url: '');
    }
    return PostEmbed(
      type: _readPlainText(value['type']).toLowerCase().trim(),
      url: _decodeHtmlText(value['url']).replaceAll(r'\u0026', '&').trim(),
    );
  }

  String get deduplicationKey {
    final uri = Uri.tryParse(url);
    if (uri == null) return '$type|$url';
    if (type == 'youtube') {
      final videoId = uri.host.contains('youtu.be')
          ? (uri.pathSegments.isEmpty ? '' : uri.pathSegments.first)
          : uri.queryParameters['v'] ??
                _segmentAfter(uri.pathSegments, 'shorts') ??
                _segmentAfter(uri.pathSegments, 'embed') ??
                _segmentAfter(uri.pathSegments, 'live') ??
                '';
      if (videoId.isNotEmpty) return '$type|$videoId';
    }
    return '$type|${uri.replace(query: '', fragment: '')}';
  }

  static String? _segmentAfter(List<String> segments, String marker) {
    final index = segments.indexOf(marker);
    return index >= 0 && index + 1 < segments.length
        ? segments[index + 1]
        : null;
  }
}

class PostShortcode {
  final String name;
  final String source;

  const PostShortcode({required this.name, required this.source});

  String get label => switch (name.toLowerCase()) {
    'ays_poll' => 'Interaktív szavazás',
    'irp' => 'Kapcsolódó cikk',
    'finaltilesgallery' => 'Képgaléria',
    _ => 'Interaktív tartalom',
  };
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
  final List<String> tags;

  final int galleryId;
  final List<GalleryImage> galleryImages;
  final List<PostEmbed> embeds;
  final List<Post> relatedPosts;

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
    required this.tags,
    required this.galleryId,
    required this.galleryImages,
    required this.embeds,
    required this.relatedPosts,
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
      tags: _readTags(json),
      galleryId: json['gallery_id'] ?? 0,
      galleryImages: gallery
          .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      embeds: _readEmbeds(json['embeds']),
      relatedPosts: _readRelatedPosts(json['related_posts']),
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
      tags: _readTags(json),
      galleryId: 0,
      galleryImages: const [],
      embeds: const [],
      relatedPosts: const [],
    );
  }

  static List<Post> _readRelatedPosts(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList(growable: false);
  }

  bool get hasGallery => galleryImages.isNotEmpty;

  static final RegExp _supportedShortcodePattern = RegExp(
    r'\[(ays_poll|irp|FinalTilesGallery)\b[^\]]*\]',
    caseSensitive: false,
  );

  List<PostShortcode> get shortcodes => _supportedShortcodePattern
      .allMatches(content)
      .map(
        (match) => PostShortcode(
          name: match.group(1) ?? '',
          source: match.group(0) ?? '',
        ),
      )
      .where(
        (shortcode) =>
            shortcode.name.toLowerCase() != 'finaltilesgallery' ||
            galleryImages.isEmpty,
      )
      .toList();

  String get contentForDisplay {
    final withoutShortcodes = content.replaceAll(
      _supportedShortcodePattern,
      '',
    );
    if (embeds.isEmpty) return withoutShortcodes;

    final fragment = html_parser.parseFragment(withoutShortcodes);
    final candidates = fragment
        .querySelectorAll('figure, blockquote, p, div')
        .toList();

    for (final element in candidates.reversed) {
      final text = _decodeHtmlText(
        element.text,
      ).replaceAll(r'\u0026', '&').trim();
      final candidateUrl = text.startsWith('http')
          ? text
          : element.classes.contains('instagram-media')
          ? element.attributes['data-instgrm-permalink'] ?? ''
          : element.classes.contains('tiktok-embed')
          ? element.attributes['cite'] ?? ''
          : '';
      if (!candidateUrl.startsWith('http')) continue;

      final candidateType = _embedTypeForUrl(candidateUrl);
      if (candidateType.isEmpty ||
          !embeds.any((embed) => embed.type == candidateType)) {
        continue;
      }

      final figure = _closestFigure(element);
      (figure ?? element).remove();
    }

    final serialized = fragment.nodes
        .map((node) => node is Element ? node.outerHtml : node.text)
        .join();

    return serialized.replaceAll(
      RegExp(
        r'<p[^>]*>\s*https?://(?:www\.)?(?:youtube\.com|youtu\.be|open\.spotify\.com|soundcloud\.com|instagram\.com|tiktok\.com)/[^<]*</p>',
        caseSensitive: false,
      ),
      '',
    );
  }

  static Element? _closestFigure(Element element) {
    Element? current = element;
    while (current != null) {
      if (current.localName == 'figure') return current;
      current = current.parent;
    }
    return null;
  }

  static String _embedTypeForUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('youtu')) return 'youtube';
    if (host.contains('spotify')) return 'spotify';
    if (host.contains('soundcloud')) return 'soundcloud';
    if (host.contains('instagram')) return 'instagram';
    if (host.contains('tiktok')) return 'tiktok';
    return '';
  }

  static List<PostEmbed> _readEmbeds(Object? value) {
    if (value is! List<dynamic>) return const [];
    final keys = <String>{};
    final embeds = <PostEmbed>[];
    for (final item in value) {
      final embed = PostEmbed.fromJson(item);
      final uri = Uri.tryParse(embed.url);
      if (embed.type.isEmpty ||
          uri == null ||
          !uri.isAbsolute ||
          !keys.add(embed.deduplicationKey)) {
        continue;
      }
      embeds.add(embed);
    }
    return embeds;
  }

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

  static List<String> _readTags(Map<String, dynamic> json) {
    final value = json['tags'] ?? json['tag_names'] ?? json['tag'];
    if (value is String) return _splitCategoryString(value);
    if (value is List<dynamic>) {
      final names = value
          .expand((item) {
            if (item is String) return _splitCategoryString(item);
            if (item is Map<String, dynamic>) {
              final name = item['name'] ?? item['slug'] ?? item['title'];
              return name is String ? _splitCategoryString(name) : <String>[];
            }
            return <String>[];
          })
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) return names;
    }

    // WordPress core returns tag IDs in `tags`; names are available in the
    // embedded post_tag terms. This keeps labels working without hardcoding
    // tags or adding a second content database in Flutter.
    final embedded = json['_embedded'];
    if (embedded is Map<String, dynamic>) {
      final terms = embedded['wp:term'];
      if (terms is List<dynamic>) {
        return terms
            .whereType<List<dynamic>>()
            .expand((group) => group)
            .whereType<Map<String, dynamic>>()
            .where((term) => term['taxonomy'] == 'post_tag')
            .map((term) => term['name'])
            .whereType<String>()
            .map(_readPlainText)
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList();
      }
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
