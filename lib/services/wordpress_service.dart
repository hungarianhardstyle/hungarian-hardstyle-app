import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/artist.dart';
import '../models/event.dart';
import '../models/event_submission.dart';
import '../models/organizer.dart';
import '../models/post.dart';
import '../models/profile_submission.dart';
import '../models/submission_image.dart';

class NewsCategory {
  final int id;
  final String name;
  final String slug;
  final int count;

  const NewsCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      id: _readInt(json['id']),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: _readInt(json['count']),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}

class PostsPage {
  final List<Post> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  const PostsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });
}

class WordpressService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://hungarianhardstyle.hu/wp-json/huhs/v1',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );

  Future<PostsPage> getPosts({
    int page = 1,
    int perPage = 10,
    String search = '',
    int categoryId = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/posts',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (categoryId > 0) 'category': categoryId,
        },
      );

      final data = response.data;

      if (data is List<dynamic>) {
        final allPosts = data
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList();
        final query = search.trim().toLowerCase();
        final posts = query.isEmpty
            ? allPosts
            : allPosts
                  .where(
                    (post) =>
                        post.title.toLowerCase().contains(query) ||
                        post.excerpt.toLowerCase().contains(query) ||
                        post.content.toLowerCase().contains(query),
                  )
                  .toList();

        return PostsPage(
          items: posts,
          page: page,
          perPage: perPage,
          total: posts.length,
          totalPages: 1,
          hasMore: false,
        );
      }

      final json = data as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? [];
      final currentPage = _readInt(json['page'], fallback: page);
      final totalPages = _readInt(json['total_pages'], fallback: 1);
      final hasMore = _readBool(json['has_more']) || currentPage < totalPages;

      return PostsPage(
        items: items
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList(),
        page: currentPage,
        perPage: _readInt(json['per_page'], fallback: perPage),
        total: _readInt(json['total']),
        totalPages: totalPages,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw Exception('Nem sikerult betolteni a hireket.\n\n${e.message}');
    } catch (e) {
      throw Exception('Ismeretlen hiba tortent.\n\n$e');
    }
  }

  Future<List<Post>> getLatestPosts() async {
    final page = await getPosts();
    return page.items;
  }

  Future<List<HuhsEvent>> getEvents() async {
    try {
      final response = await _dio.get<String>(
        '/events',
        options: Options(responseType: ResponseType.plain),
      );
      final data = _decodePossiblyPrefixedJson(response.data ?? '');

      if (data is List<dynamic>) {
        return data
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>? ?? [];

        return items
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      throw Exception('Nem sikerult betolteni az esemenyeket.\n\n${e.message}');
    } catch (e) {
      throw Exception('Ismeretlen hiba tortent.\n\n$e');
    }
  }

  Future<ArtistsPage> getArtists({
    String search = '',
    String category = '',
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/artists',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (category.trim().isNotEmpty) 'category': category.trim(),
        },
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return ArtistsPage.fromJson(data);
      }

      throw const FormatException('Hibás DJ-lista válasz.');
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a DJ-ket.'));
    } catch (e) {
      throw Exception('Nem sikerült betölteni a DJ-ket.\n\n$e');
    }
  }

  Future<Artist> getArtist(int artistId) async {
    try {
      final response = await _dio.get('/artists/$artistId');
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return Artist.fromJson(data);
      }

      throw const FormatException('Hibás DJ-adatlap válasz.');
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a DJ-adatlapot.'));
    } catch (e) {
      throw Exception('Nem sikerült betölteni a DJ-adatlapot.\n\n$e');
    }
  }

  Future<OrganizersPage> getOrganizers({
    String search = '',
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/organizers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return OrganizersPage.fromJson(data);
      }

      throw const FormatException('Hibás szervezőlista-válasz.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a szervezőket.'),
      );
    } catch (e) {
      throw Exception('Nem sikerült betölteni a szervezőket.\n\n$e');
    }
  }

  Future<OrganizerProfile> getOrganizer(int organizerId) async {
    try {
      final response = await _dio.get('/organizers/$organizerId');
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return OrganizerProfile.fromJson(data);
      }

      throw const FormatException('Hibás szervezői adatlap válasz.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a szervezői adatlapot.'),
      );
    } catch (e) {
      throw Exception('Nem sikerült betölteni a szervezői adatlapot.\n\n$e');
    }
  }

  Future<ProfileSubmissionOptions> getProfileSubmissionOptions() async {
    try {
      final response = await _dio.get('/profile-submission-options');
      final data = response.data;

      if (data is Map<String, dynamic>) {
        return ProfileSubmissionOptions.fromJson(data);
      }

      throw const FormatException('Hibás beküldési beállítások.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a beküldési adatokat.'),
      );
    } catch (e) {
      throw Exception('Nem sikerült betölteni a beküldési adatokat.\n\n$e');
    }
  }

  Future<String> submitArtist(
    ArtistSubmission submission, {
    SubmissionImage? image,
  }) {
    return _submitProfile(
      '/artist-submissions',
      submission.toJson(),
      image: image,
    );
  }

  Future<String> submitOrganizer(
    OrganizerSubmission submission, {
    SubmissionImage? image,
  }) {
    return _submitProfile(
      '/organizer-submissions',
      submission.toJson(),
      image: image,
    );
  }

  Future<String> _submitProfile(
    String path,
    Map<String, dynamic> data, {
    SubmissionImage? image,
  }
  ) async {
    try {
      final response = await _dio.post(
        path,
        data: image == null ? data : _multipartSubmission(data, image),
      );
      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      return 'Köszönjük, a beküldést elküldtük ellenőrzésre.';
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'A beküldés nem sikerült.'));
    } catch (e) {
      throw Exception('A beküldés nem sikerült.\n\n$e');
    }
  }

  Future<List<String>> getEventSubmissionGenres() async {
    try {
      final response = await _dio.get('/event-submission-options');
      final data = response.data as Map<String, dynamic>;
      final genres = data['genres'] as List<dynamic>? ?? const [];

      return genres
          .whereType<String>()
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a műfajokat.'),
      );
    } catch (e) {
      throw Exception('Nem sikerült betölteni a műfajokat.\n\n$e');
    }
  }

  Future<String> submitEvent(
    EventSubmission submission, {
    SubmissionImage? image,
  }) async {
    try {
      final response = await _dio.post(
        '/event-submissions',
        data: image == null
            ? submission.toJson()
            : _multipartSubmission(submission.toJson(), image),
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }

      return 'Köszönjük, az eseményt elküldtük ellenőrzésre.';
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Az eseményt nem sikerült elküldeni.'),
      );
    } catch (e) {
      throw Exception('Az eseményt nem sikerült elküldeni.\n\n$e');
    }
  }

  FormData _multipartSubmission(
    Map<String, dynamic> payload,
    SubmissionImage image,
  ) {
    return FormData.fromMap({
      'payload': jsonEncode(payload),
      'image': MultipartFile.fromBytes(image.bytes, filename: image.name),
    });
  }

  String _readApiError(DioException exception, String fallback) {
    final data = exception.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      } catch (_) {
        // Keep the localized fallback for non-JSON server responses.
      }
    }

    return fallback;
  }

  Object? _decodePossiblyPrefixedJson(String value) {
    final arrayStart = value.indexOf('[');
    final objectStart = value.indexOf('{');
    final starts = [arrayStart, objectStart].where((index) => index >= 0);

    if (starts.isEmpty) return null;

    return jsonDecode(value.substring(starts.reduce((a, b) => a < b ? a : b)));
  }

  Future<List<NewsCategory>> getCategories() async {
    try {
      final response = await _dio.get(
        'https://hungarianhardstyle.hu/wp-json/wp/v2/categories',
        queryParameters: {
          'per_page': 100,
          'hide_empty': true,
          '_fields': 'id,name,slug,count',
        },
      );

      final data = response.data as List<dynamic>;

      return data
          .map((json) => NewsCategory.fromJson(json as Map<String, dynamic>))
          .where((category) => category.id > 0 && category.name.isNotEmpty)
          .toList();
    } on DioException catch (_) {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Set<int>> getPostIdsForCategory(int categoryId) async {
    if (categoryId <= 0) {
      return const {};
    }

    final postIds = <int>{};
    var page = 1;
    var totalPages = 1;

    try {
      do {
        final response = await _dio.get(
          'https://hungarianhardstyle.hu/wp-json/wp/v2/posts',
          queryParameters: {
            'categories': categoryId,
            'per_page': 100,
            'page': page,
            '_fields': 'id',
          },
        );

        final data = response.data as List<dynamic>;

        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = _readInt(item['id']);

            if (id > 0) {
              postIds.add(id);
            }
          }
        }

        totalPages = _readInt(
          response.headers.value('x-wp-totalpages'),
          fallback: totalPages,
        );
        page += 1;
      } while (page <= totalPages);
    } catch (_) {
      return postIds;
    }

    return postIds;
  }

  Future<PostsPage> getStandardPosts({
    int categoryId = 0,
    String search = '',
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await _dio.get(
        'https://hungarianhardstyle.hu/wp-json/wp/v2/posts',
        queryParameters: {
          if (categoryId > 0) 'categories': categoryId,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'per_page': perPage,
          '_embed': true,
        },
      );

      final data = response.data as List<dynamic>;
      final total = _readInt(response.headers.value('x-wp-total'));
      final totalPages = _readInt(
        response.headers.value('x-wp-totalpages'),
        fallback: 1,
      );

      return PostsPage(
        items: data
            .map((json) => Post.fromWordpressJson(json as Map<String, dynamic>))
            .toList(),
        page: page,
        perPage: perPage,
        total: total,
        totalPages: totalPages,
        hasMore: page < totalPages,
      );
    } on DioException catch (e) {
      throw Exception('Nem sikerult betolteni a hireket.\n\n${e.message}');
    } catch (e) {
      throw Exception('Ismeretlen hiba tortent.\n\n$e');
    }
  }

  int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return false;
  }
}
