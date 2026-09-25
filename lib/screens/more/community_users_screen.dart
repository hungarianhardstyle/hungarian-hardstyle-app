import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/layout/scroll_bottom_inset.dart';
import '../../models/event.dart';
import '../../models/achievement.dart';
import '../../providers/community_provider.dart';
import '../../providers/artists_provider.dart';
import '../../services/community_service.dart';
import '../../services/wordpress_service.dart';
import '../../widgets/app_text.dart';
import '../events/event_detail_screen.dart';
import '../artists/artist_detail_screen.dart';
import '../organizers/organizer_detail_screen.dart';
import 'favorites_screen.dart';
import 'newsletter_screen.dart';
import '../community/private_messages_screen.dart';
import '../../widgets/achievement_badge_card.dart';
import '../../widgets/profile_content_card.dart';

class CommunityUsersScreen extends ConsumerStatefulWidget {
  const CommunityUsersScreen({super.key});

  @override
  ConsumerState<CommunityUsersScreen> createState() =>
      _CommunityUsersScreenState();
}

class _CommunityUsersScreenState extends ConsumerState<CommunityUsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refreshProfiles() async {
    await ref
        .read(communityServiceProvider)
        .getRegisteredPublicProfiles(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final viewer = service.auth.currentUser;
    final isRegistered = viewer != null && !viewer.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const AppText('Felhasználók')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.watchRegisteredPublicProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: AppText('A felhasználók nem tölthetők be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _search.text.trim().toLowerCase();
          final profiles =
              snapshot.data!.where((profile) {
                final name = (profile['displayName'] as String? ?? '')
                    .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList()..sort(
                (a, b) => ((a['displayName'] as String? ?? '').toLowerCase())
                    .compareTo(
                      (b['displayName'] as String? ?? '').toLowerCase(),
                    ),
              );
          return RefreshIndicator(
            onRefresh: _refreshProfiles,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(context, 'Felhasználó keresése'),
                    hintText: tr(context, 'Már egy betűre is keres'),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                if (profiles.isEmpty)
                  const Center(child: AppText('Nincs találat.')),
                for (final profile in profiles)
                  _UserTile(
                    profile: profile,
                    imageUrl: service.resolveProfileImage(profile),
                    service: service,
                    showAccessRole: isRegistered,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String imageUrl;
  final CommunityService service;
  final bool showAccessRole;

  const _UserTile({
    required this.profile,
    required this.imageUrl,
    required this.service,
    required this.showAccessRole,
  });

  @override
  Widget build(BuildContext context) {
    final data = profile;
    final name = (data['displayName'] as String? ?? tr(context, 'HUHS user')).trim();
    final safeName = name.isEmpty ? 'HUHS user' : name;
    final role = switch (data['role'] as String?) {
      'dj' => 'DJ',
      'organizer' => tr(context, 'Szervező'),
      _ => tr(context, 'Bulizó'),
    };
    final access = switch (data['accessRole'] as String?) {
      'admin' => tr(context, 'Admin'),
      'moderator' => tr(context, 'Moderátor'),
      _ => null,
    };
    final subtitle = !showAccessRole
        ? role
        : access != null
        ? '$role · $access'
        : role;
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(
              userId: profile['userId'] as String? ?? '',
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundImage: imageUrl.isEmpty
              ? null
              : CachedNetworkImageProvider(imageUrl),
          child: imageUrl.isEmpty
              ? Text(safeName.characters.first.toUpperCase())
              : null,
        ),
        title: Text(safeName),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class CommunityPublicProfileScreen extends StatefulWidget {
  final String userId;

  const CommunityPublicProfileScreen({super.key, required this.userId});

  @override
  State<CommunityPublicProfileScreen> createState() =>
      _CommunityPublicProfileScreenState();
}

class _CommunityPublicProfileScreenState
    extends State<CommunityPublicProfileScreen> {
  late final CommunityService service;
  late Future<String?> _connectionStatus;
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<AchievementSummary> _achievementFuture;
  bool _blocking = false;

  /// Busy-kapu az ismerős-műveletekre (jelölés / elfogadás / elutasítás):
  /// amíg egy callable fut, nem indulhat másik, és a gombok le vannak tiltva.
  bool _connectionBusy = false;

  @override
  void initState() {
    super.initState();
    service = CommunityService();
    _connectionStatus = service.connectionStatus(widget.userId);
    // Paint cached public data immediately; the projection is refreshed by
    // Firebase whenever the profile or achievement state changes.
    _profileFuture = service.getPublicProfile(widget.userId).then((profile) {
      // Older public projections predate memberSince. Refresh only those
      // profiles through the callable; current projections remain cached.
      if (profile['memberSince'] is num) return profile;
      return service.getPublicProfile(widget.userId, forceRefresh: true);
    });
    // getPublicProfile already contains the public achievement projection, so
    // opening a profile normally costs a single callable request. Only a
    // projection whose badge has no artwork at all triggers the recalculation
    // callable: that state means the stored badge was written while the server
    // had no WordPress badge catalog, and the callable returns the real rank.
    _achievementFuture = _profileFuture.then((profile) {
      final projected = AchievementSummary.fromProfile(profile);
      if (projected.badgeImageUrl.isNotEmpty) return projected;
      return service.getPublicAchievement(widget.userId).then(
        (recalculated) => recalculated.badgeImageUrl.isEmpty
            ? projected
            : recalculated,
      );
    });
  }

  Future<void> _requestConnection() async {
    // Busy-kapu: egy koppintás egy callable (a dupla jelölés a szerveren
    // versenyhelyzetet okozna). A gomb eközben le is van tiltva.
    if (_connectionBusy) return;
    final previousStatus = _connectionStatus;
    // Optimista váltás még a szolgáltatás-hívás előtt: a „pending" állapot
    // azonnal látszik, nem a Cloud Function visszaérkezése (hideg indulásnál
    // 1–3 s) után.
    setState(() {
      _connectionBusy = true;
      _connectionStatus = Future.value('pending');
    });
    try {
      await service.requestConnection(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Ismerősnek jelölés elküldve.')),
      );
    } catch (error) {
      if (!mounted) return;
      // Hiba: visszaáll a koppintás előtti állapot, és szólunk is.
      setState(() {
        _connectionStatus = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Az ismerősnek jelölés nem sikerült.\n${userFacingError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  /// Az érkező felkérés megválaszolása (elfogadás / elutasítás).
  ///
  /// MIÉRT külön metódus: korábban a két gomb `onPressed`-ében volt a hívás,
  /// **try/catch nélkül** — egy hiba kezeletlen async hibaként tűnt el, nulla
  /// visszajelzéssel. Most optimista a váltás, van busy-kapu, visszaállás és
  /// SnackBar.
  Future<void> _respondConnection(bool accept) async {
    if (_connectionBusy) return;
    final previousStatus = _connectionStatus;
    setState(() {
      _connectionBusy = true;
      _connectionStatus = Future.value(accept ? 'accepted' : null);
    });
    try {
      await service.respondConnection(widget.userId, accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Ismerős-jelölés elfogadva.'
                : 'Ismerős-jelölés elutasítva.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Az elfogadás nem sikerült.\n${userFacingError(error)}'
                : 'Az elutasítás nem sikerült.\n${userFacingError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  Future<void> _removeConnection() async {
    try {
      await service.removeConnection(widget.userId);
      if (!mounted) return;
      setState(() {
        _connectionStatus = Future.value(null);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: AppText('Ismerős törölve.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Az ismerős törlése nem sikerült.')),
      );
    }
  }

  Future<void> _blockUser() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('Felhasználó blokkolása'),
            content: const AppText(
              'Nem tudtok majd egymásnak privát üzenetet küldeni. A blokkolás később a blokkolt felhasználók listájából visszavonható.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const AppText('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const AppText('Blokkolás'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _blocking = true);
    try {
      await service.blockUser(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Felhasználó blokkolva.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _blocking = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Profil')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final viewer = service.auth.currentUser;
          final isRegistered = viewer != null && !viewer.isAnonymous;
          final isOwnProfile = viewer?.uid == widget.userId;
          final avatarCacheWidth = (96 * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(192, 384);
          final name = (data['displayName'] as String? ?? tr(context, 'HUHS user')).trim();
          final image = service.resolveProfileImage(data);
          final links = Map<String, dynamic>.from(
            data['socialLinks'] as Map? ?? const {},
          );
          final achievement = AchievementSummary.fromProfile(data);
          final memberSinceMillis = (data['memberSince'] as num?)?.toInt();
          final memberSince = memberSinceMillis != null && memberSinceMillis > 0
              ? DateTime.fromMillisecondsSinceEpoch(memberSinceMillis).toLocal()
              : null;
          // ⚠️ A görgethető oldal ALJÁRA kell a rendszer alsó sávja + levegő,
          // különben az utolsó kártya takarásban marad és úgy tűnik, mintha nem
          // lehetne a végére görgetni. A tulajdonos jelzése (2026-09-22):
          // *„ha az achievement notifyra nyomok, megnyílik a saját adatlap,
          // viszont nem tudok legörgetni az aljára rendesen"*.
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 96,
                  child: ClipOval(
                    child: image.isEmpty
                        ? ColoredBox(
                            color: Theme.of(context).colorScheme.primary,
                            child: Center(
                              child: Text(
                                name.isEmpty
                                    ? 'H'
                                    : name.characters.first.toUpperCase(),
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: CommunityService.optimizedImageUrl(
                              image,
                              width: avatarCacheWidth,
                            ),
                            fit: BoxFit.cover,
                            memCacheWidth: avatarCacheWidth,
                            maxWidthDiskCache: avatarCacheWidth,
                            placeholder: (_, _) => ColoredBox(
                              color: Theme.of(context).colorScheme.primary,
                              child: const Center(
                                child: SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: Theme.of(context).colorScheme.primary,
                              child: Center(
                                child: Text(
                                  name.isEmpty
                                      ? 'H'
                                      : name.characters.first.toUpperCase(),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  name.isEmpty ? 'HUHS user' : name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (memberSince != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const AppText('A közösség tagja'),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(memberSince),
                  ),
                ),
              const SizedBox(height: 16),
              FutureBuilder<AchievementSummary>(
                future: _achievementFuture,
                initialData: achievement,
                builder: (context, achievementSnapshot) => AchievementBadgeCard(
                  achievement:
                      achievementSnapshot.data ?? AchievementSummary.empty,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _role(data['role'] as String?),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (isRegistered &&
                  (data['bio'] as String? ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(data['bio'] as String),
              ],
              const SizedBox(height: 18),
              if (isRegistered)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in links.entries)
                      if (entry.value.toString().trim().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => openSocialLink(
                            context,
                            entry.value.toString(),
                            title: entry.key,
                          ),
                          icon: const Icon(Icons.link),
                          label: Text(entry.key),
                        ),
                  ],
                ),
              if (isRegistered && !isOwnProfile) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PrivateConversationScreen(
                        otherUserId: widget.userId,
                        otherUserName: name.isEmpty ? 'HUHS user' : name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.mail_outline),
                  label: const AppText('Privát üzenet'),
                ),
                const SizedBox(height: 8),
                FutureBuilder<String?>(
                  future: _connectionStatus,
                  builder: (context, status) {
                    final value = status.data;
                    if (value == 'accepted') {
                      return OutlinedButton.icon(
                        onPressed: _removeConnection,
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const AppText('Ismerős törlése'),
                      );
                    }
                    if (value == 'pending') {
                      return const AppText('Ismerősjelölés elküldve.');
                    }
                    if (value?.startsWith('incoming:') == true) {
                      return Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _connectionBusy
                                ? null
                                : () => _respondConnection(true),
                            child: const AppText('Elfogadás'),
                          ),
                          OutlinedButton(
                            onPressed: _connectionBusy
                                ? null
                                : () => _respondConnection(false),
                            child: const AppText('Elutasítás'),
                          ),
                        ],
                      );
                    }
                    return FilledButton.icon(
                      onPressed: _connectionBusy ? null : _requestConnection,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const AppText('Ismerősnek jelölés'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _blocking ? null : _blockUser,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Blokkolás / letiltás'),
                ),
              ],
              const SizedBox(height: 18),
              if (isRegistered)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.watchConnections(widget.userId),
                  builder: (context, connections) {
                    final friends = connections.data?.docs ?? const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ismerősök: ${friends.length}'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CommunityPublicFriendsScreen(
                                userId: widget.userId,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.people_outline),
                          label: const AppText('Ismerősök megnyitása'),
                        ),
                      ],
                    );
                  },
                )
              else
                const AppText(
                  'Az ismerőslista regisztrált felhasználóknak érhető el.',
                ),
              if (isRegistered) ...[
                const SizedBox(height: 18),
                _ClaimedArtistsSection(
                  userId: widget.userId,
                ),
                const SizedBox(height: 18),
                const AppText(
                  'Események, ahol ott leszek',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                StreamBuilder<
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                >(
                  stream: service.watchActivePlannedEventsFor(widget.userId),
                  builder: (context, planned) {
                    final items = planned.data ?? const [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: AppText('Nincs megjelölt esemény.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          ProfileContentCard(
                            icon: Icons.event_outlined,
                            title:
                                item.data()['title'] as String? ?? tr(context, 'Esemény'),
                            subtitle: tr(context, 'Esemény, ahol ott lesz'),
                            onTap: () async {
                              final eventId = (item.data()['eventId'] as num?)
                                  ?.toInt();
                              if (eventId == null || !context.mounted) return;
                              final events = await WordpressService()
                                  .getEvents();
                              HuhsEvent? event;
                              for (final candidate in events) {
                                if (candidate.id == eventId) {
                                  event = candidate;
                                  break;
                                }
                              }
                              final selectedEvent = event;
                              if (selectedEvent != null && context.mounted) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        EventDetailScreen(event: selectedEvent),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _FavoriteProfilesSection(
                  userId: widget.userId,
                  service: service,
                ),
              ],
              // A rendszer alsó sávja + szándékos levegő (lásd a fenti
              // megjegyzést): enélkül az utolsó kártya takarásban marad.
              const ScrollBottomInset(),
            ],
          );
        },
      ),
    );
  }

  static String _role(String? role) => switch (role) {
    'dj' => 'DJ',
    'organizer' => AppStrings.tr('Szervező'),
    _ => AppStrings.tr('Bulizó'),
  };
}

class _FavoriteProfilesSection extends StatelessWidget {
  final String userId;
  final CommunityService service;

  const _FavoriteProfilesSection({required this.userId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.firestore
          .collection('community_profiles')
          .doc(userId)
          .collection('favorites')
          .snapshots(),
      builder: (context, snapshot) {
        final favorites =
            snapshot.data?.docs
                .map((doc) => doc.data())
                .where(
                  (item) =>
                      item['kind'] == 'artist' || item['kind'] == 'organizer',
                )
                .toList() ??
            const <Map<String, dynamic>>[];
        final artists = favorites
            .where((item) => item['kind'] == 'artist')
            .toList();
        final organizers = favorites
            .where((item) => item['kind'] == 'organizer')
            .toList();
        if (artists.isEmpty && organizers.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Kedvenc DJ-k és szervezők',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            for (final item in artists)
              _favoriteTile(
                context,
                item,
                icon: Icons.album_outlined,
                subtitle: tr(context, 'Kedvenc DJ'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArtistDetailScreen(
                      artistId: (item['id'] as num).toInt(),
                    ),
                  ),
                ),
              ),
            for (final item in organizers)
              _favoriteTile(
                context,
                item,
                icon: Icons.groups_outlined,
                subtitle: tr(context, 'Kedvenc szervező'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrganizerDetailScreen(
                      organizerId: (item['id'] as num).toInt(),
                      fallbackName: item['title'] as String? ?? '',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _favoriteTile(
    BuildContext context,
    Map<String, dynamic> item, {
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ProfileContentCard(
      icon: icon,
      title: item['title'] as String? ?? tr(context, 'Ismeretlen'),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class CommunityPublicFriendsScreen extends StatelessWidget {
  final String userId;

  const CommunityPublicFriendsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    final viewer = service.auth.currentUser;
    if (viewer == null || viewer.isAnonymous) {
      return const Scaffold(
        body: Center(child: AppText('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const AppText('Ismerősök')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchConnections(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: AppText('Az ismerőslista nem tölthető be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final friends = snapshot.data?.docs ?? const [];
          if (friends.isEmpty) {
            return const Center(child: AppText('Nincs ismerős.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) => _FriendTile(
              userId: friends[index].id,
              service: service,
              connectionData: friends[index].data(),
            ),
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _LegacyCommunityConnectionsScreen extends StatelessWidget {
  // ignore: unused_element_parameter
  const _LegacyCommunityConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    final user = service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(child: AppText('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const AppText('Ismerősök')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.firestore
            .collection('connection_requests')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          final requests = snapshot.data?.docs ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (requests.isEmpty) const AppText('Nincs függőben lévő felkérés.'),
              for (final request in requests)
                ListTile(
                  title: Text(
                    request.data()['from'] as String? ?? tr(context, 'Felhasználó'),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: () => service.respondConnection(
                          request.data()['from'] as String,
                          true,
                        ),
                        icon: const Icon(Icons.check),
                      ),
                      IconButton(
                        onPressed: () => service.respondConnection(
                          request.data()['from'] as String,
                          false,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchConnections(user.uid),
                builder: (context, connections) =>
                    Text('Ismerősök: ${connections.data?.docs.length ?? 0}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    final user = service.auth.currentUser;
    final registered = user != null && !user.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const AppText('Közösség')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hubTile(
            context,
            Icons.people_outline,
            tr(context, 'Ismerősök és felkérések'),
            tr(context, 'Ismerőslista, felkérések és státuszok'),
            registered ? const CommunityConnectionsScreen() : null,
          ),
          _hubTile(
            context,
            Icons.forum_outlined,
            tr(context, 'Privát üzenetek'),
            tr(context, 'A neked küldött és általad küldött privát beszélgetések'),
            registered ? const PrivateMessagesScreen() : null,
          ),
          _hubTile(
            context,
            Icons.favorite_outline,
            tr(context, 'Kedvencek'),
            tr(context, 'Kedvenc DJ-k és szervezők'),
            const FavoritesScreen(),
          ),
          _hubTile(
            context,
            Icons.mail_outline,
            tr(context, 'Hírlevél'),
            tr(context, 'Iratkozz fel a Hungarian Hardstyle hírlevelére'),
            const NewsletterScreen(),
          ),
          _hubTile(
            context,
            Icons.search,
            tr(context, 'Felhasználók keresése'),
            tr(context, 'Publikus profilok és ismerősnek jelölés'),
            registered ? const CommunityUsersScreen() : null,
          ),
          _hubTile(
            context,
            Icons.block_outlined,
            tr(context, 'Blokkolt felhasználók'),
            tr(context, 'Tiltások megtekintése és feloldása'),
            registered ? const CommunityBlockedUsersScreen() : null,
          ),
          if (!registered)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppText('A közösségi funkciókhoz regisztráció szükséges.'),
            ),
        ],
      ),
    );
  }

  Widget _hubTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget? screen,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: screen != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: screen == null
            ? null
            : () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => screen)),
      ),
    );
  }
}

class CommunityBlockedUsersScreen extends StatelessWidget {
  const CommunityBlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    return Scaffold(
      appBar: AppBar(title: const AppText('Blokkolt felhasználók')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchBlockedUsers(),
        builder: (context, snapshot) {
          final users = snapshot.data?.docs ?? const [];
          if (users.isEmpty) {
            return const Center(child: AppText('Nincs blokkolt felhasználó.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userId = users[index].id;
              return ListTile(
                title: FutureBuilder<Map<String, dynamic>>(
                  future: service.getPublicProfile(userId),
                  builder: (context, profile) {
                    final name = (profile.data?['displayName'] as String?)
                        ?.trim();
                    return Text(
                      name == null || name.isEmpty
                          ? tr(context, 'Ismeretlen felhasználó')
                          : name,
                    );
                  },
                ),
                trailing: TextButton(
                  onPressed: () => service.unblockUser(userId),
                  child: const AppText('Feloldás'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CommunityReportsScreen extends StatelessWidget {
  const CommunityReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    return Scaffold(
      appBar: AppBar(title: const AppText('Jelentések kezelése')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(userFacingError(snapshot.error)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!.docs
              .where((report) => report.data()['status'] != 'resolved')
              .toList();
          if (reports.isEmpty) {
            return const Center(child: AppText('Nincs nyitott jelentés.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data();
              final postId = data['postId'] as String? ?? '';
              final reportedUserId = data['reportedUserId'] as String? ?? '';
              final reportedName =
                  data['reportedUserName'] as String? ?? tr(context, 'Felhasználó');
              return _ReportCard(
                reportId: report.id,
                data: data,
                postId: postId,
                reportedUserId: reportedUserId,
                reportedName: reportedName,
                service: service,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;
  final String postId;
  final String reportedUserId;
  final String reportedName;
  final CommunityService service;

  const _ReportCard({
    required this.reportId,
    required this.data,
    required this.postId,
    required this.reportedUserId,
    required this.reportedName,
    required this.service,
  });

  Future<void> _action(BuildContext context, String action) async {
    try {
      if (action == 'delete' && postId.isNotEmpty) {
        await service.deletePost(postId);
      } else if (action == 'block' && reportedUserId.isNotEmpty) {
        await service.adminBlockUser(reportedUserId);
      }
      await service.resolveReport(reportId);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('A jelentés kezelése nem sikerült.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storedText = (data['reportedText'] as String? ?? '').trim();
    final reporterId = (data['reporterId'] as String? ?? '').trim();
    final reason = (data['reason'] as String? ?? 'other').trim();
    final futures = <Future<DocumentSnapshot<Map<String, dynamic>>>>[];
    int? postIndex;
    int? reporterIndex;
    int? reportedIndex;
    if (postId.isNotEmpty) {
      postIndex = futures.length;
      futures.add(
        service.firestore.collection('live_feed_posts').doc(postId).get(),
      );
    }
    if (reporterId.isNotEmpty) {
      reporterIndex = futures.length;
      futures.add(
        service.firestore
            .collection('community_profiles')
            .doc(reporterId)
            .get(),
      );
    }
    if (reportedUserId.isNotEmpty) {
      reportedIndex = futures.length;
      futures.add(
        service.firestore
            .collection('community_profiles')
            .doc(reportedUserId)
            .get(),
      );
    }
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait(futures),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AppText('A jelentés adatai nem tölthetők be.'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        final lookup = snapshot.data!;
        final live = postIndex == null ? null : lookup[postIndex].data();
        final reporterProfile = reporterIndex == null
            ? null
            : lookup[reporterIndex].data();
        final reportedProfile = reportedIndex == null
            ? null
            : lookup[reportedIndex].data();
        String firstValue(Iterable<String?> values, String fallback) {
          for (final value in values) {
            final trimmed = (value ?? '').trim();
            if (trimmed.isNotEmpty) return trimmed;
          }
          return fallback;
        }

        final reporter = firstValue([
          data['reporterName'] as String?,
          reporterProfile?['displayName'] as String?,
          reporterId,
        ], '—');
        final liveName = firstValue([
          data['reportedUserName'] as String?,
          reportedName,
          reportedProfile?['displayName'] as String?,
          live?['authorName'] as String?,
          reportedUserId,
        ], tr(context, 'Felhasználó'));
        final text = storedText.isNotEmpty
            ? storedText
            : (live?['text'] as String? ?? tr(context, 'Üzenet nem érhető el.'));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppText(
                        'Üzenet jelentése',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) => _action(context, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'resolve', child: AppText('Lezárás')),
                        PopupMenuItem(
                          value: 'delete',
                          child: AppText('Üzenet törlése'),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: AppText('Felhasználó tiltása'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Bejelentő: $reporter'),
                Text(
                  'Jelentett felhasználó: $liveName${reportedUserId.isEmpty ? '' : ' ($reportedUserId)'}',
                ),
                Text('Indok: $reason'),
                if (postId.isNotEmpty) Text('Bejegyzés: $postId'),
                const SizedBox(height: 6),
                Text(text, maxLines: 6, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CommunityConnectionsScreen extends StatelessWidget {
  const CommunityConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    final user = service.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(child: AppText('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const AppText('Ismerősök')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.firestore
            .collection('connection_requests')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          final requests = snapshot.data?.docs ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (requests.isEmpty) const AppText('Nincs függőben lévő felkérés.'),
              for (final request in requests)
                _ConnectionRequestTile(
                  key: ValueKey(request.id),
                  request: request,
                  service: service,
                ),
              const Divider(),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchConnections(user.uid),
                builder: (context, connections) {
                  final friends = connections.data?.docs ?? const [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ismerősök: ${friends.length}'),
                      for (final friend in friends)
                        _FriendTile(
                          userId: friend.id,
                          service: service,
                          connectionData: friend.data(),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String userId;
  final CommunityService service;
  final Map<String, dynamic>? connectionData;

  const _FriendTile({
    required this.userId,
    required this.service,
    this.connectionData,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: service.getPublicProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            service.pruneStaleConnections(service.auth.currentUser?.uid ?? '');
          });
          return const SizedBox.shrink();
        }
        final profile = snapshot.data ?? const <String, dynamic>{};
        final name =
            (profile['displayName'] as String? ??
                    connectionData?['displayName'] as String? ??
                    tr(context, 'HUHS user'))
                .trim();
        final image = service.resolveProfileImage(
          profile,
          connectionData?['imageUrl'] as String? ?? '',
        );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityPublicProfileScreen(userId: userId),
            ),
          ),
          leading: CircleAvatar(
            backgroundImage: image.isEmpty
                ? null
                : CachedNetworkImageProvider(image),
            child: image.isEmpty
                ? Text(name.isEmpty ? 'F' : name.characters.first.toUpperCase())
                : null,
          ),
          title: Text(name.isEmpty ? 'HUHS user' : name),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}

class _ConnectionRequestTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final CommunityService service;

  // Kulcs a dokumentum-azonosító: a lista a stream-ből él, és egy elfogadott
  // felkérés kikerül belőle — kulcs nélkül a Flutter a megmaradt `State`-et
  // (és vele az optimista `_handled` jelzőt) a KÖVETKEZŐ felkéréshez
  // párosíthatná, ami hamis „Elfogadva" jelzést okozna.
  const _ConnectionRequestTile({
    super.key,
    required this.request,
    required this.service,
  });

  @override
  State<_ConnectionRequestTile> createState() => _ConnectionRequestTileState();
}

class _ConnectionRequestTileState extends State<_ConnectionRequestTile> {
  /// Busy-kapu: ne induljon két `respondConnection` ugyanarra a felkérésre.
  bool _busy = false;

  /// Optimista döntés: `true` = elfogadva, `false` = elutasítva, `null` = még
  /// nincs döntés. A csempe a koppintásra **azonnal** vált (a hívás előtt),
  /// mert a callable hideg indulásnál 1–3 s is lehet.
  bool? _handled;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    final from = widget.request.data()['from'] as String? ?? '';
    final previousHandled = _handled;
    setState(() {
      _busy = true;
      _handled = accept;
    });
    try {
      // AWAIT: korábban itt nem vártuk meg a hívást, ezért a hiba
      // kezeletlen async hibaként tűnt el, visszajelzés nélkül.
      await widget.service.respondConnection(from, accept);
    } catch (error) {
      if (!mounted) return;
      // Hiba: visszaáll a gombos állapot (újra próbálható), és szólunk is.
      setState(() => _handled = previousHandled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Az elfogadás nem sikerült.\n${userFacingError(error)}'
                : 'Az elutasítás nem sikerült.\n${userFacingError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.request.data();
    final from = data['from'] as String? ?? '';
    return FutureBuilder<Map<String, dynamic>>(
      future: widget.service.getPublicProfile(from),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        final name =
            (profile['displayName'] as String? ??
                    data['fromName'] as String? ??
                    tr(context, 'Felhasználó'))
                .trim();
        final image = widget.service.resolveProfileImage(
          profile,
          data['fromImageUrl'] as String? ?? '',
        );
        return ListTile(
          onTap: _handled != null || from.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityPublicProfileScreen(userId: from),
                  ),
                ),
          leading: CircleAvatar(
            backgroundImage: image.isEmpty
                ? null
                : CachedNetworkImageProvider(image),
            child: image.isEmpty
                ? Text(name.isEmpty ? 'F' : name.characters.first.toUpperCase())
                : null,
          ),
          title: Text(name.isEmpty ? 'Felhasználó' : name),
          // Optimista: a koppintásra azonnal ez a jelzés jelenik meg, nem a
          // hívás visszaérkezése után.
          trailing: _handled == null
              ? Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: _busy ? null : () => _respond(true),
                      icon: const Icon(Icons.check),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => _respond(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _handled == true ? Icons.check : Icons.close,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(_handled == true ? 'Elfogadva' : tr(context, 'Elutasítva')),
                  ],
                ),
        );
      },
    );
  }
}

/// A felhasználó **claimelt DJ-adatlapjai** a nyilvános profilon.
///
/// A tulajdonos kérése: *„ha valaki megnyitja egy user adatlapját és claimelt egy
/// DJ profilt, látszódjon az is ott, egy kattintható kártyaként"*.
///
/// A lista a **szerverről** jön (`getClaimedArtistsForUser`), mert az
/// `artist_claims` gyűjteményt a biztonsági szabályok más felhasználóról **nem**
/// engedik olvasni (`firestore.rules`). Ha nincs claim — vagy a hívás hibázik —,
/// a szakasz **el sem jelenik**: a profil nem mutat üres fejlécet.
class _ClaimedArtistsSection extends ConsumerWidget {
  const _ClaimedArtistsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ Cache-first: a kártyák a **mentett** válaszból azonnal megjelennek, a
    // szerver a háttérben egyeztet (eddig minden profil-megnyitásnál új callable
    // körút futott, és a szekció csak utána jelent meg).
    final ids = ref.watch(claimedArtistsOfUserProvider(userId)).valueOrNull;
    if (ids == null || ids.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DJ-adatlap',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final id in ids) _ClaimedArtistCard(artistId: id),
      ],
    );
  }
}

/// Egy claimelt DJ-adatlap **kattintható kártyája** (borító + név).
class _ClaimedArtistCard extends ConsumerWidget {
  const _ClaimedArtistCard({required this.artistId});

  final int artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = ref.watch(artistDetailProvider(artistId));
    final value = artist.valueOrNull;
    final name = value?.title.trim() ?? '';
    final imageUrl = value == null
        ? ''
        : (value.profileImageUrl.isNotEmpty
              ? value.profileImageUrl
              : value.logoUrl);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ArtistDetailScreen(artistId: artistId, fallbackName: name),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.isEmpty
                      ? Container(
                          color: Colors.white10,
                          child: const Icon(Icons.person_outline),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'DJ-adatlap' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const AppText(
                      'Átvett DJ-adatlap',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
