import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/post.dart';

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
  }) async {
    try {
      final response = await _dio.get(
        '/posts',
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      final data = response.data;

      if (data is List<dynamic>) {
        final posts = data
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
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
      throw Exception(
        'Nem sikerult betolteni a hireket.\n\n${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Ismeretlen hiba tortent.\n\n$e',
      );
    }
  }

  Future<List<Post>> getLatestPosts() async {
    final page = await getPosts();
    return page.items;
  }

  Future<List<HuhsEvent>> getEvents() async {
    try {
      final response = await _dio.get('/events');
      final data = response.data;

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
      throw Exception(
        'Nem sikerult betolteni az esemenyeket.\n\n${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Ismeretlen hiba tortent.\n\n$e',
      );
    }
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
      throw Exception(
        'Nem sikerult betolteni a hireket.\n\n${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Ismeretlen hiba tortent.\n\n$e',
      );
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
