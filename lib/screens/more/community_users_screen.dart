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

class CommunityPublicProfileScreen extends StatelessWidget {
  final String userId;

  const CommunityPublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: service.firestore
            .collection('community_profiles')
            .doc(userId)
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
                future: service.connectionStatus(userId),
                builder: (context, status) => status.data == 'accepted'
                    ? const Text('Ismerős')
                    : FilledButton.icon(
                        onPressed: status.data == 'pending'
                            ? null
                            : () => service.requestConnection(userId),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Ismerősnek jelölés'),
                      ),
              ),
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.watchConnections(userId),
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
