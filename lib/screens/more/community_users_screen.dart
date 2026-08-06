import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/in_app_browser.dart';
import '../../models/event.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../services/wordpress_service.dart';
import '../events/event_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final viewer = service.auth.currentUser;
    final isRegistered = viewer != null && !viewer.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const Text('Felhasználók')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchRegisteredProfiles(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('A felhasználók nem tölthetők be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _search.text.trim().toLowerCase();
          final profiles =
              snapshot.data!.docs.where((doc) {
                final name = (doc.data()['displayName'] as String? ?? '')
                    .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList()..sort(
                (a, b) =>
                    ((a.data()['displayName'] as String? ?? '').toLowerCase())
                        .compareTo(
                          (b.data()['displayName'] as String? ?? '')
                              .toLowerCase(),
                        ),
              );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Felhasználó keresése',
                  hintText: 'Már egy betűre is keres',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              if (profiles.isEmpty) const Center(child: Text('Nincs találat.')),
              for (final profile in profiles)
                _UserTile(
                  profile: profile,
                  imageUrl: service.resolveProfileImage(profile.data()),
                  service: service,
                  showAccessRole: isRegistered,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> profile;
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
    final data = profile.data();
    final name = (data['displayName'] as String? ?? 'HUHS user').trim();
    final safeName = name.isEmpty ? 'HUHS user' : name;
    final role = switch (data['role'] as String?) {
      'dj' => 'DJ',
      'organizer' => 'Szervező',
      _ => 'Bulizó',
    };
    final access = switch (data['accessRole'] as String?) {
      'admin' => 'Admin',
      'moderator' => 'Moderátor',
      _ => null,
    };
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchConnections(profile.id),
      builder: (context, connections) {
        final friendCount = connections.data?.docs.length ?? 0;
        final subtitle = access != null && showAccessRole
            ? '$role · $access · $friendCount ismerős'
            : '$role · $friendCount ismerős';
        return Card(
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CommunityPublicProfileScreen(userId: profile.id),
              ),
            ),
            leading: CircleAvatar(
              backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
              child: imageUrl.isEmpty
                  ? Text(safeName.characters.first.toUpperCase())
                  : null,
            ),
            title: Text(safeName),
            subtitle: Text(subtitle),
          ),
        );
      },
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

  @override
  void initState() {
    super.initState();
    service = CommunityService();
    _connectionStatus = service.connectionStatus(widget.userId);
  }

  Future<void> _requestConnection() async {
    try {
      await service.requestConnection(widget.userId);
      if (!mounted) return;
      setState(() {
        _connectionStatus = Future.value('pending');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ismerősnek jelölés elküldve.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Az ismerősnek jelölés nem sikerült.')),
      );
    }
  }

  Future<void> _removeConnection() async {
    try {
      await service.removeConnection(widget.userId);
      if (!mounted) return;
      setState(() {
        _connectionStatus = Future.value(null);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ismerős törölve.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Az ismerős törlése nem sikerült.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: service.firestore
            .collection('community_profiles')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? const <String, dynamic>{};
          final viewer = service.auth.currentUser;
          final isRegistered = viewer != null && !viewer.isAnonymous;
          final isOwnProfile = viewer?.uid == widget.userId;
          final name = (data['displayName'] as String? ?? 'HUHS user').trim();
          final image = service.resolveProfileImage(data);
          final links = Map<String, dynamic>.from(
            data['socialLinks'] as Map? ?? const {},
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: image.isEmpty ? null : NetworkImage(image),
                  child: image.isEmpty
                      ? Text(
                          name.isEmpty
                              ? 'H'
                              : name.characters.first.toUpperCase(),
                        )
                      : null,
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
                FutureBuilder<String?>(
                  future: _connectionStatus,
                  builder: (context, status) {
                    final value = status.data;
                    if (value == 'accepted') {
                      return OutlinedButton.icon(
                        onPressed: _removeConnection,
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Ismerős törlése'),
                      );
                    }
                    if (value == 'pending') {
                      return const Text('Ismerősjelölés elküldve.');
                    }
                    if (value?.startsWith('incoming:') == true) {
                      return Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              await service.respondConnection(
                                widget.userId,
                                true,
                              );
                              if (mounted) {
                                setState(() {
                                  _connectionStatus = Future.value('accepted');
                                });
                              }
                            },
                            child: const Text('Elfogadás'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await service.respondConnection(
                                widget.userId,
                                false,
                              );
                              if (mounted) {
                                setState(() {
                                  _connectionStatus = Future.value(null);
                                });
                              }
                            },
                            child: const Text('Elutasítás'),
                          ),
                        ],
                      );
                    }
                    return FilledButton.icon(
                      onPressed: _requestConnection,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Ismerősnek jelölés'),
                    );
                  },
                ),
              ],
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchConnections(widget.userId),
                builder: (context, connections) {
                  final friends = connections.data?.docs ?? const [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ismerősök: ${friends.length}'),
                      if (isRegistered) ...[
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
                          label: const Text('Ismerősök megnyitása'),
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (isRegistered) ...[
                const SizedBox(height: 18),
                const Text(
                  'Tervezett események',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.watchPlannedEventsFor(widget.userId),
                  builder: (context, planned) {
                    final items = planned.data?.docs ?? const [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Nincs megjelölt esemény.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_outlined),
                            title: Text(
                              item.data()['title'] as String? ?? 'Esemény',
                            ),
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
              ],
            ],
          );
        },
      ),
    );
  }

  static String _role(String? role) => switch (role) {
    'dj' => 'DJ',
    'organizer' => 'Szervező',
    _ => 'Bulizó',
  };
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
        body: Center(child: Text('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ismerősök')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchConnections(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Az ismerőslista nem tölthető be.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final friends = snapshot.data?.docs ?? const [];
          if (friends.isEmpty) {
            return const Center(child: Text('Nincs ismerős.'));
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
        body: Center(child: Text('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ismerősök')),
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
              if (requests.isEmpty) const Text('Nincs függőben lévő felkérés.'),
              for (final request in requests)
                ListTile(
                  title: Text(
                    request.data()['from'] as String? ?? 'Felhasználó',
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

class CommunityBlockedUsersScreen extends StatelessWidget {
  const CommunityBlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    return Scaffold(
      appBar: AppBar(title: const Text('Blokkolt felhasználók')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchBlockedUsers(),
        builder: (context, snapshot) {
          final users = snapshot.data?.docs ?? const [];
          if (users.isEmpty) {
            return const Center(child: Text('Nincs blokkolt felhasználó.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userId = users[index].id;
              return ListTile(
                title: Text(userId),
                trailing: TextButton(
                  onPressed: () => service.unblockUser(userId),
                  child: const Text('Feloldás'),
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
      appBar: AppBar(title: const Text('Jelentések kezelése')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!.docs
              .where((report) => report.data()['status'] != 'resolved')
              .toList();
          if (reports.isEmpty) {
            return const Center(child: Text('Nincs nyitott jelentés.'));
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
                  data['reportedUserName'] as String? ?? 'Felhasználó';
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
          const SnackBar(content: Text('A jelentés kezelése nem sikerült.')),
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
              child: Text('A jelentés adatai nem tölthetők be.'),
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
        ], 'Felhasználó');
        final text = storedText.isNotEmpty
            ? storedText
            : (live?['text'] as String? ?? 'Üzenet nem érhető el.');
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
                      child: Text(
                        'Üzenet jelentése',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) => _action(context, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'resolve', child: Text('Lezárás')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Üzenet törlése'),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text('Felhasználó tiltása'),
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
        body: Center(child: Text('Regisztráció szükséges.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ismerősök')),
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
              if (requests.isEmpty) const Text('Nincs függőben lévő felkérés.'),
              for (final request in requests)
                _ConnectionRequestTile(request: request, service: service),
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
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: service.firestore
          .collection('community_profiles')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            (profile['displayName'] as String? ??
                    connectionData?['displayName'] as String? ??
                    'HUHS user')
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
            backgroundImage: image.isEmpty ? null : NetworkImage(image),
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

class _ConnectionRequestTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final CommunityService service;

  const _ConnectionRequestTile({required this.request, required this.service});

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final from = data['from'] as String? ?? '';
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: service.firestore
          .collection('community_profiles')
          .doc(from)
          .get(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            (profile['displayName'] as String? ??
                    data['fromName'] as String? ??
                    'Felhasználó')
                .trim();
        final image = service.resolveProfileImage(
          profile,
          data['fromImageUrl'] as String? ?? '',
        );
        return ListTile(
          onTap: from.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityPublicProfileScreen(userId: from),
                  ),
                ),
          leading: CircleAvatar(
            backgroundImage: image.isEmpty ? null : NetworkImage(image),
            child: image.isEmpty
                ? Text(name.isEmpty ? 'F' : name.characters.first.toUpperCase())
                : null,
          ),
          title: Text(name.isEmpty ? 'Felhasználó' : name),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: () => service.respondConnection(from, true),
                icon: const Icon(Icons.check),
              ),
              IconButton(
                onPressed: () => service.respondConnection(from, false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        );
      },
    );
  }
}
