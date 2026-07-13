import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../providers/artists_provider.dart';
import 'artist_detail_screen.dart';

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  String _category = '';
  String _search = '';
  Timer? _searchTimer;

  ArtistListQuery get _query => (category: _category, search: _search);

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _search = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final artists = ref.watch(artistsProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('DJ-k')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(artistsProvider(_query).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Magyar DJ-k',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Keresés DJ-k között…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFF171717),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryChip(
                                label: 'Összes',
                                selected: _category.isEmpty,
                                onSelected: () =>
                                    setState(() => _category = ''),
                              ),
                              _CategoryChip(
                                label: 'Hardstyle',
                                selected: _category == 'hardstyle',
                                onSelected: () =>
                                    setState(() => _category = 'hardstyle'),
                              ),
                              _CategoryChip(
                                label: 'Hardcore',
                                selected: _category == 'hardcore',
                                onSelected: () =>
                                    setState(() => _category = 'hardcore'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...artists.when(
                  loading: () => const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, stack) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ArtistError(
                        onRetry: () => ref.invalidate(artistsProvider(_query)),
                      ),
                    ),
                  ],
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nincs találat.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ];
                    }

                    return [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320,
                                mainAxisExtent: 390,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            return _ArtistCard(artist: page.items[index]);
                          }, childCount: page.items.length),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final subtitle = artist.genres.isNotEmpty
        ? artist.genres.take(3).join(' · ')
        : artist.location;

    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ArtistDetailScreen(
              artistId: artist.id,
              fallbackName: artist.title,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'artist_${artist.id}',
                child: artist.profileImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: artist.profileImageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.5),
                        )
                    : Container(
                        color: const Color(0xFF242424),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.graphic_eq,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          artist.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (artist.featured)
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle.isEmpty ? 'DJ adatlap' : subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ArtistError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nem sikerült betölteni a DJ-ket.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Újrapróbálás'),
            ),
          ],
        ),
      ),
    );
  }
}
