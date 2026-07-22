import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../models/event.dart';
import '../../models/post.dart';
import '../../providers/news_provider.dart';
import '../../services/wordpress_service.dart';
import '../../widgets/event_card.dart';
import '../artists/artist_detail_screen.dart';
import '../news/news_detail_screen.dart';

bool _hasGenre(Iterable<String> genres, String genre) =>
    genres.any((item) => item.toLowerCase() == genre.toLowerCase());

class GenreDiscoveryScreen extends ConsumerStatefulWidget {
  final String genre;

  const GenreDiscoveryScreen({super.key, required this.genre});

  @override
  ConsumerState<GenreDiscoveryScreen> createState() =>
      _GenreDiscoveryScreenState();
}

class _GenreDiscoveryScreenState extends ConsumerState<GenreDiscoveryScreen> {
  final _scrollController = ScrollController();
  final _events = <HuhsEvent>[];
  final _artists = <Artist>[];
  final _posts = <Post>[];
  int _artistPage = 0;
  int _postPage = 0;
  bool _artistHasMore = true;
  bool _postHasMore = true;
  bool _loading = false;
  Object? _error;

  WordpressService get _service => ref.read(wordpressServiceProvider);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await _service.getEvents();
      if (!mounted) return;
      setState(
        () => _events
          ..clear()
          ..addAll(
            events.where((event) => _hasGenre(event.genres, widget.genre)),
          ),
      );
      await _loadMore();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading && (_artistPage > 0 || _postPage > 0)) return;
    if (!_artistHasMore && !_postHasMore) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final artistFuture = _artistHasMore
          ? _service.getArtists(page: _artistPage + 1, perPage: 20)
          : null;
      final postFuture = _postHasMore
          ? _service.getPosts(page: _postPage + 1, perPage: 20)
          : null;
      final artistPage = artistFuture == null ? null : await artistFuture;
      final postPage = postFuture == null ? null : await postFuture;
      if (!mounted) return;
      var foundMatch = false;
      setState(() {
        if (artistPage != null) {
          final matches = artistPage.items.where(
            (artist) => _hasGenre(artist.genres, widget.genre),
          );
          _artists.addAll(matches);
          foundMatch = foundMatch || matches.isNotEmpty;
          _artistPage = artistPage.page;
          _artistHasMore = artistPage.hasMore;
        }
        if (postPage != null) {
          final matches = postPage.items.where(_matchesPost);
          _posts.addAll(matches);
          foundMatch = foundMatch || matches.isNotEmpty;
          _postPage = postPage.page;
          _postHasMore = postPage.hasMore;
        }
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients || _loading) return;
        if (_scrollController.position.maxScrollExtent <= 0 &&
            (_artistHasMore || _postHasMore)) {
          _loadMore();
        }
      });
      if (!foundMatch && (_artistHasMore || _postHasMore)) {
        await _loadMore();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  bool _matchesPost(Post post) => [
    post.title,
    post.excerpt,
    post.content,
    ...post.categories,
    ...post.tags,
  ].join(' ').toLowerCase().contains(widget.genre.toLowerCase());

  Future<void> _refresh() async {
    _events.clear();
    _artists.clear();
    _posts.clear();
    _artistPage = 0;
    _postPage = 0;
    _artistHasMore = true;
    _postHasMore = true;
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.genre)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                '${widget.genre} – kapcsolódó tartalmak',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _Section(title: 'Események', child: _eventContent()),
              _Section(title: 'DJ-k', child: _artistContent()),
              _Section(title: 'Hírek', child: _postContent()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('A lista nem tölthető be.\n$_error'),
                ),
              if (_loading || _artistHasMore || _postHasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventContent() {
    if (_events.isEmpty) return const _Empty();
    return Column(
      children: _events
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EventCard(event: event),
            ),
          )
          .toList(),
    );
  }

  Widget _artistContent() {
    if (_artists.isEmpty) return const _Empty();
    return Column(
      children: _artists
          .map(
            (artist) => Card(
              child: ListTile(
                title: Text(artist.title),
                subtitle: Text(artist.genres.join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistDetailScreen(
                      artistId: artist.id,
                      fallbackName: artist.title,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _postContent() {
    if (_posts.isEmpty) return const _Empty();
    return Column(
      children: _posts
          .map(
            (post) => Card(
              child: ListTile(
                title: Text(post.title),
                subtitle: Text(post.excerpt),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NewsDetailScreen(post: post),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) =>
      const Text('Nincs találat.', style: TextStyle(color: Colors.white70));
}
