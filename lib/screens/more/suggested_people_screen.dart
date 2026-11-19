import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/tr.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import 'community_users_screen.dart';

/// „Kit ismerhetek?" — azok, akik ugyanazokra a közelgő bulikra mennek, mint te.
/// Koppintásra a nyilvános profiljuk nyílik (onnan jelölhetők ismerősnek).
class SuggestedPeopleScreen extends StatefulWidget {
  const SuggestedPeopleScreen({super.key, this.loader});

  /// Csak a tesztnek: a lista forrása.
  final Future<List<Map<String, dynamic>>> Function()? loader;

  @override
  State<SuggestedPeopleScreen> createState() => _SuggestedPeopleScreenState();
}

class _SuggestedPeopleScreenState extends State<SuggestedPeopleScreen> {
  late final Future<List<Map<String, dynamic>>> _people =
      (widget.loader ?? CommunityService().getSuggestedPeople)();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Kit ismerhetek?')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _people,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = snapshot.data ?? const [];
          if (snapshot.hasError || people.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    snapshot.hasError
                        ? 'Az ajánlások most nem tölthetők be.'
                        : 'Jelöld meg az eseményeken, hogy ott leszel, és megmutatjuk, kik mennek veled.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: people.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = people[i];
              final image = p['image'] as String? ?? '';
              final name = (p['name'] as String? ?? '').trim();
              return ListTile(
                key: ValueKey('suggested-${p['id']}'),
                leading: CircleAvatar(
                  backgroundImage:
                      image.isEmpty ? null : CachedNetworkImageProvider(image),
                  child: image.isEmpty
                      ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                      : null,
                ),
                title: Text(name.isEmpty ? tr(context, 'Felhasználó') : name),
                subtitle: Text(
                  trArgs(context, '{n} közös buli', {'n': '${p['shared']}'}),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityPublicProfileScreen(
                      userId: p['id'] as String? ?? '',
                    ),
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
