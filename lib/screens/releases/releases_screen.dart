import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../providers/releases_provider.dart';
import '../../providers/news_provider.dart';
import '../../widgets/content_refresh_icon.dart';
import '../../widgets/release_card.dart';
import 'free_releases_screen.dart';

class ReleasesScreen extends ConsumerStatefulWidget {
  final int artistId;
  final String artistName;

  const ReleasesScreen({super.key, this.artistId = 0, this.artistName = ''});

  @override
  ConsumerState<ReleasesScreen> createState() => ReleasesScreenState();
}

class ReleasesScreenState extends ConsumerState<ReleasesScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _search = '';
  Timer? _timer;
  Timer? _releaseRefreshTimer;
  DateTime? _lastRefreshAt;

  ReleaseQuery get _query => (search: _search, artistId: widget.artistId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRefreshAt = DateTime.now();
    _releaseRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) unawaited(_refreshInBackground());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 30) {
      return;
    }
    _lastRefreshAt = DateTime.now();
    unawaited(_refreshInBackground());
  }

  Future<void> _refreshInBackground() async {
    try {
      await refreshNow();
    } catch (_) {
      // The existing list remains visible when a background refresh fails.
    }
  }

  Future<void> refreshNow() async {
    final service = ref.read(wordpressServiceProvider);
    await service.getReleases(
      search: _search,
      artistId: widget.artistId,
      forceRefresh: true,
    );
    ref.invalidate(releasesProvider(_query));
    await ref.read(releasesProvider(_query).future);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _releaseRefreshTimer?.cancel();
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
        actions: [
          if (widget.artistId == 0)
            TextButton.icon(
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Ingyenes kiadványok'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FreeReleasesScreen(),
                ),
              ),
            ),
          ContentRefreshIcon(onRefresh: refreshNow),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshNow,
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
                        child: ReleaseCard(release: items[index]),
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

// A kiadvány-kártya (`ReleaseCard`) közös: a `lib/widgets/release_card.dart`-ban
// él, mert a DJ-adatlap „Megjelenései" szakasza is ugyanezt rajzolja. Egy helyen
// tartva a két felület nem tud széthúzni (ez a 351-es tanulság: a szabály lehet
// helyes, a bekötés hibás).
