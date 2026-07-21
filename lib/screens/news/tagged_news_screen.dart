import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../providers/news_provider.dart';
import '../../widgets/news_card.dart';

class TaggedNewsScreen extends ConsumerStatefulWidget {
  final String tag;

  const TaggedNewsScreen({super.key, required this.tag});

  @override
  ConsumerState<TaggedNewsScreen> createState() => _TaggedNewsScreenState();
}

class _TaggedNewsScreenState extends ConsumerState<TaggedNewsScreen> {
  final _scrollController = ScrollController();
  final _posts = <Post>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
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
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(wordpressServiceProvider)
          .getPosts(page: _page + 1, perPage: 20);
      if (!mounted) return;
      final matches = page.items.where(_hasTag);
      setState(() {
        _posts.addAll(matches);
        _page = page.page;
        _hasMore = page.hasMore;
        _loading = false;
      });
      if (matches.isEmpty && page.hasMore) {
        await _loadNextPage();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
        _error = error;
      });
    }
  }

  bool _hasTag(Post post) =>
      post.tags.any((value) => value.toLowerCase() == widget.tag.toLowerCase());

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _posts.isEmpty && _loading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty && _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'A címke hírei nem tölthetők be.\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : _posts.isEmpty && !_hasMore
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('Nincs cikk ehhez a címkéhez.')),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _posts.length + (_loading || _hasMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == _posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return NewsCard(post: _posts[index]);
                },
              ),
      ),
    );
  }
}
