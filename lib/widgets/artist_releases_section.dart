import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/releases_provider.dart';
import '../screens/releases/releases_screen.dart';
import '../services/artist_releases_plan.dart';
import 'release_card.dart';

/// A DJ **megjelenései**: azok a kiadványok, amelyekben az adott DJ szerepel.
///
/// A tulajdonos kérése (2026-09-24): *„kéne olyan az appba, hogy a dj adatlapon
/// legyen ott a megjelenése is"*. A szűrés a szerveren történik
/// (`/releases?artist=<id>`, élőben mérve), a lista pedig a **mentett**
/// válaszból azonnal jön (`WordpressHeadCache`), ezért nincs külön cache-réteg.
///
/// ⚠️ A „villogás nélkül" szabály (a cache-kör óta projekt-szabály):
///  * **amíg nincs érték, nem rajzolunk semmit** — se fejlécet, se pörgőt,
///  * **hibánál sem** teszünk hibadobozt a DJ-adatlap közepére: a szakasz
///    ilyenkor egyszerűen nincs ott, a többi tartalom zavartalanul látszik.
///
/// A kiadvány-kártya a **közös** `ReleaseCard`, ugyanaz, amit a kiadvány-lista
/// használ — így a két felület nem tud széthúzni.
class ArtistReleasesSection extends ConsumerWidget {
  final int artistId;
  final String artistName;

  const ArtistReleasesSection({
    super.key,
    required this.artistId,
    this.artistName = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref
        .watch(releasesProvider((search: '', artistId: artistId)))
        .valueOrNull;
    if (releases == null) return const SizedBox.shrink();

    final all = artistReleasesFor(artistId, releases);
    if (all.isEmpty) return const SizedBox.shrink();

    final preview = artistReleasesPreview(artistId, releases);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artistReleasesLabel(all.length),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...preview.map(
            (release) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReleaseCard(release: release),
            ),
          ),
          if (hasMoreArtistReleases(all.length))
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReleasesScreen(
                    artistId: artistId,
                    artistName: artistName,
                  ),
                ),
              ),
              icon: const Icon(Icons.library_music_outlined),
              label: Text('Összes megjelenése (${all.length})'),
            ),
        ],
      ),
    );
  }
}
