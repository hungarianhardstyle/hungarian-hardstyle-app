import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';

/// A HARD-küldés címzettjének kiválasztása a regisztrált felhasználók közül.
/// Visszaadja a kiválasztott felhasználó azonosítóját és nevét (vagy `null`).
///
/// A tárcát a szerver oldja fel: ha a kiválasztott felhasználónak nincs
/// összekötött tárcája, a küldésnél kapsz értesítést, ezért itt nem szűrünk.
class HardRecipientPickerScreen extends ConsumerStatefulWidget {
  const HardRecipientPickerScreen({super.key});

  @override
  ConsumerState<HardRecipientPickerScreen> createState() =>
      _HardRecipientPickerScreenState();
}

class _HardRecipientPickerScreenState
    extends ConsumerState<HardRecipientPickerScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final myUid = ref.watch(currentUidProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('Kinek küldesz?')),
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
                final uid = profile['userId'] as String? ?? '';
                if (uid.isEmpty || uid == myUid) return false;
                final name = (profile['displayName'] as String? ?? '')
                    .toLowerCase();
                return query.isEmpty || name.contains(query);
              }).toList()..sort(
                (a, b) => ((a['displayName'] as String? ?? '').toLowerCase())
                    .compareTo(
                      (b['displayName'] as String? ?? '').toLowerCase(),
                    ),
              );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: tr(context, 'Felhasználó keresése'),
                  hintText: tr(context, 'Már egy betűre is keres'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              const AppText(
                'Csak olyan felhasználónak küldhetsz, aki összekötötte a tárcáját.',
              ),
              const SizedBox(height: 12),
              if (profiles.isEmpty)
                const Center(child: AppText('Nincs találat.')),
              for (final profile in profiles)
                _PickerTile(
                  name: (profile['displayName'] as String? ?? '').trim(),
                  imageUrl: service.resolveProfileImage(profile),
                  onTap: () => Navigator.of(context).pop((
                    profile['userId'] as String,
                    (profile['displayName'] as String? ?? 'HUHS user').trim(),
                  )),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = name.isEmpty ? 'HUHS user' : name;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: imageUrl.isEmpty
              ? null
              : CachedNetworkImageProvider(imageUrl),
          child: imageUrl.isEmpty
              ? Text(label.characters.first.toUpperCase())
              : null,
        ),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
