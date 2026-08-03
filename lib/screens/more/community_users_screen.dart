import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/community_provider.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../services/community_service.dart';

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
    final user = ref.watch(communityAuthProvider).valueOrNull;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'A felhasználók listája csak regisztráltaknak érhető el.',
          ),
        ),
      );
    }
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

  const _UserTile({required this.profile, required this.imageUrl});

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
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: profile.id),
          ),
        ),
        leading: CircleAvatar(
          backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
          child: imageUrl.isEmpty
              ? Text(safeName.characters.first.toUpperCase())
              : null,
        ),
        title: Text(safeName),
        subtitle: Text(access == null ? role : '$role · $access'),
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
      setState(() => _connectionStatus = Future.value('pending'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ismerősnek jelölés elküldve.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A jelölés sikertelen: $error')),
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
              if ((data['bio'] as String? ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(data['bio'] as String),
              ],
              const SizedBox(height: 18),
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
              const SizedBox(height: 18),
              FutureBuilder<String?>(
                future: _connectionStatus,
                builder: (context, status) => status.data == 'accepted'
                    ? const Text('Ismerős')
                    : FilledButton.icon(
                        onPressed: status.data == 'pending'
                            ? null
                            : _requestConnection,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Ismerősnek jelölés'),
                      ),
              ),
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchConnections(widget.userId),
                builder: (context, connections) =>
                    Text('Ismerősök: ${connections.data?.docs.length ?? 0}'),
              ),
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
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final reports = snapshot.data!.docs;
          if (reports.isEmpty) return const Center(child: Text('Nincs nyitott jelentés.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data();
              final postId = data['postId'] as String? ?? '';
              final reportedUserId = data['reportedUserId'] as String? ?? '';
              final reportedName = data['reportedUserName'] as String? ?? 'Felhasználó';
              return Card(
                child: ListTile(
                  title: Text('$reportedName · ${data['reason'] ?? 'egyéb'}'),
                  subtitle: Text(
                    (data['reportedText'] as String? ?? 'Üzenet nem érhető el.').trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      try {
                        if (action == 'delete' && postId.isNotEmpty) {
                          await service.deletePost(postId);
                        } else if (action == 'block' && reportedUserId.isNotEmpty) {
                          await service.adminBlockUser(reportedUserId);
                        }
                        await service.resolveReport(report.id);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'resolve', child: Text('Lezárás')),
                      PopupMenuItem(value: 'delete', child: Text('Üzenet törlése')),
                      PopupMenuItem(value: 'block', child: Text('Felhasználó tiltása')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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
      return const Scaffold(body: Center(child: Text('Regisztráció szükséges.')));
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
              if (requests.isEmpty)
                const Text('Nincs függőben lévő felkérés.'),
              for (final request in requests)
                _ConnectionRequestTile(request: request, service: service),
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

class _ConnectionRequestTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final CommunityService service;

  const _ConnectionRequestTile({required this.request, required this.service});

  @override
  Widget build(BuildContext context) {
    final data = request.data();
    final from = data['from'] as String? ?? '';
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: service.firestore.collection('community_profiles').doc(from).get(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (profile['displayName'] as String? ??
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
