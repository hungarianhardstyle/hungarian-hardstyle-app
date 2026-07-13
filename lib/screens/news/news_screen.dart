import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/news_provider.dart';
import '../../widgets/brand_loading_indicator.dart';
import '../../widgets/news_card.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final shouldLoadMore = position.pixels >= position.maxScrollExtent - 260;

    if (shouldLoadMore) {
      ref.read(paginatedNewsProvider.notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(paginatedNewsProvider.notifier).updateSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedNewsProvider);
    final posts = state.visiblePosts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(paginatedNewsProvider.notifier).refresh(),
            child: state.isLoading && state.posts.isEmpty
                ? const Center(child: BrandLoadingIndicator(size: 220))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    itemCount: posts.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hírek',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Keresés hírek között...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchDebounce?.cancel();
                                          _searchController.clear();
                                          ref
                                              .read(
                                                paginatedNewsProvider.notifier,
                                              )
                                              .updateSearch('');
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFF181818),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            if (state.categories.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: state.categories.length + 1,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, categoryIndex) {
                                    final category = categoryIndex == 0
                                        ? null
                                        : state.categories[categoryIndex - 1];
                                    final categoryId = category?.id ?? 0;
                                    final label = category == null
                                        ? 'Összes'
                                        : category.name;
                                    final isSelected =
                                        state.selectedCategoryId == categoryId;

                                    return ChoiceChip(
                                      label: Text(label),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        if (categoryId > 0 &&
                                            _searchController.text.isNotEmpty) {
                                          _searchDebounce?.cancel();
                                          _searchController.clear();
                                          setState(() {});
                                        }
                                        ref
                                            .read(
                                              paginatedNewsProvider.notifier,
                                            )
                                            .updateCategory(categoryId);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            if (state.error != null && state.posts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  state.error.toString(),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }

                      if (index == posts.length + 1) {
                        if (state.error != null && state.posts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Text(
                                  state.error.toString(),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(paginatedNewsProvider.notifier)
                                        .refresh();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Újrapróbálás'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (posts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text(
                                'Nincs találat.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }

                        if (state.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        return const SizedBox(height: 24);
                      }

                      return NewsCard(post: posts[index - 1]);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
