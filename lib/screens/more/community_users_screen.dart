import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/community_provider.dart';

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
