import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/release.dart';
import '../../core/errors/user_facing_error.dart';
import '../../providers/releases_provider.dart';
import 'release_detail_screen.dart';
import 'free_releases_screen.dart';

class ReleasesScreen extends ConsumerStatefulWidget {
  final int artistId;
  final String artistName;

  const ReleasesScreen({super.key, this.artistId = 0, this.artistName = ''});

  @override
  ConsumerState<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends ConsumerState<ReleasesScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  Timer? _timer;

  ReleaseQuery get _query => (search: _search, artistId: widget.artistId);

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(releasesProvider(_query));
    final title = widget.artistName.isEmpty
        ? const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hardstyle Revolution', style: TextStyle(fontSize: 18)),
              Text('Records', style: TextStyle(fontSize: 18)),
            ],
          )
        : Text('${widget.artistName} release-ei');
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: widget.artistId == 0
            ? [
                TextButton.icon(
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('Ingyenes kiadványok'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FreeReleasesScreen(),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(releasesProvider(_query).future),
        child: releases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    userFacingError(error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          data: (allItems) {
            final items = allItems.where((release) => !release.isFree).toList();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _timer?.cancel();
                        setState(() {});
                        _timer = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _search = value);
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Release keresése',
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Keresés törlése',
                                onPressed: () {
                                  _timer?.cancel();
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Nincs megjeleníthető release.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReleaseCard(release: items[index]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final HuhsRelease release;

  const _ReleaseCard({required this.release});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReleaseDetailScreen(release: release),
          ),
        ),
        child: SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 118,
                child: release.coverUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF242424),
                        child: Icon(
                          Icons.album,
                          size: 42,
                          color: Colors.redAccent,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: release.coverUrl,
                        fit: BoxFit.cover,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        release.artists
                            .map((artist) => artist.name)
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (release.releaseDate.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Megjelenés: ${release.releaseDate}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                      if (release.genre.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          release.genre,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
