import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';
import '../../widgets/resized_network_image.dart';
import 'community_users_screen.dart';

class AchievementLeaderboardScreen extends ConsumerStatefulWidget {
  const AchievementLeaderboardScreen({super.key});

  @override
  ConsumerState<AchievementLeaderboardScreen> createState() =>
      _AchievementLeaderboardScreenState();
}

class _AchievementLeaderboardScreenState
    extends ConsumerState<AchievementLeaderboardScreen> {
  final _items = <Map<String, dynamic>>[];
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int? _cursorPoints;
  String? _cursorUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restoreCacheAndRefresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(communityServiceProvider)
          .getAchievementLeaderboardPage(
            cursorPoints: _cursorPoints,
            cursorUserId: _cursorUserId,
            offset: _items.length,
          );
      final items = (page['items'] as List? ?? const []).whereType<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      );
      final cursor = page['nextCursor'] is Map
          ? Map<String, dynamic>.from(page['nextCursor'] as Map)
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _hasMore = page['hasMore'] == true;
        _cursorPoints = (cursor['points'] as num?)?.toInt();
        _cursorUserId = cursor['userId'] as String?;
      });
      await _saveCache();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreCacheAndRefresh() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final payload = preferences.getString('huhs.achievement.leaderboard');
      if (payload != null) {
        final decoded = jsonDecode(payload);
        if (decoded is Map && decoded['items'] is List && mounted) {
          setState(() {
            _items
              ..clear()
              ..addAll(
                (decoded['items'] as List).whereType<Map>().map(
                  (item) => Map<String, dynamic>.from(item),
                ),
              );
            _hasMore = decoded['hasMore'] == true;
            _cursorPoints = (decoded['cursorPoints'] as num?)?.toInt();
            _cursorUserId = decoded['cursorUserId'] as String?;
          });
        }
      }
    } catch (_) {}
    if (mounted) await _loadMore();
  }

  Future<void> _saveCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'huhs.achievement.leaderboard',
        jsonEncode({
          'items': _items,
          'hasMore': _hasMore,
          'cursorPoints': _cursorPoints,
          'cursorUserId': _cursorUserId,
        }),
      );
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _cursorPoints = null;
      _cursorUserId = null;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('huhs.achievement.leaderboard');
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('HUHS Legenda toplista'),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: Builder(
      builder: (context) {
        if (_items.isEmpty && _loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_items.isEmpty && _error != null) {
          return Center(
            child: FilledButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.refresh),
              label: const AppText('Újrapróbálás'),
            ),
          );
        }
        if (_items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppText('Még nincs megjeleníthető toplista.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            itemCount: _items.length + (_loading || _error != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index < _items.length) {
                return _LeaderboardTile(item: _items[index], index: index);
              }
              if (_error != null) {
                return TextButton(
                  onPressed: _loadMore,
                  child: const AppText('Betöltési hiba – újrapróbálás'),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );
      },
    ),
  );
}

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;

  const _LeaderboardTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final rank = (item['rank'] as num?)?.toInt() ?? index + 1;
    final points = (item['points'] as num?)?.toInt() ?? 0;
    final userId = (item['userId'] as String?)?.trim() ?? '';
    final name = (item['displayName'] as String?)?.trim();
    final badge = (item['badgeName'] as String?)?.trim();
    final imageUrl = (item['badgeImageUrl'] as String?)?.trim() ?? '';
    final badgeCacheWidth = (28 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(56, 112);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: userId.isEmpty
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityPublicProfileScreen(userId: userId),
                ),
              ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE53935),
          child: Text('$rank', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name?.isNotEmpty == true ? name! : 'HUHS tag'),
        subtitle: Text(badge?.isNotEmpty == true ? badge! : 'Achievement rang'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl.isNotEmpty)
              ResizedNetworkImage(
                url: imageUrl,
                physicalWidth: badgeCacheWidth,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            Text('$points pont'),
          ],
        ),
      ),
    );
  }
}
