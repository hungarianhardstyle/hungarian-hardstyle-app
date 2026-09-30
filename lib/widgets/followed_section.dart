import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../providers/favorites_provider.dart';
import '../screens/more/favorites_screen.dart';
import 'app_text.dart';

/// A főoldali **„Kedvenceid"** szekció.
///
/// **MIÉRT (mért ok, 2026-09-28):** a kedvencek (követett DJ-k/szervezők) eddig
/// **csak** a „Több" → „Kedvencek" képernyőn és a push-célzásban éltek: a
/// 46 profilból 89 kedvenc van a Firestore-ban, a főoldalon viszont **semmi**
/// nem látszott belőlük. Aki követ egy DJ-t, az a főoldalon **naponta** lássa,
/// kit követ — ez a visszajelzés tartja életben a követést (és ebből lesz a
/// személyes push is, lásd `favorite-follow-plan.js`).
///
/// **A HELYE (a tulajdonos jelzése, 2026-09-30):** az első változat a **Hero
/// (logó) kártya FÖLÉ** került — ez hiba volt. Mostantól a **hírek blokkja
/// után** áll (a „További hírek" kártya és az esetleges játékkártya alatt), a
/// „Közelgő események" szakasz előtt.
///
/// **MENNYIT MUTAT (szintén a tulajdonos kérése):** legfeljebb **3** kedvencet
/// emel ki — a többi az **„Összes"** gombbal érhető el (a Kedvencek képernyőn,
/// ahol a kedvelt események is ott vannak).
///
/// **Amit tartalmaz:** a **követés**-jellegű kedvenceket (DJ és szervező) — a
/// kedvelt **események** a „Kedvencek" képernyőn vannak, és a főoldalon külön
/// esemény-sáv is mutatja őket. A szekció **magától eltűnik**, ha nincs követett
/// tartalom (nem hagy üres helyet).
///
/// **A koppintás ugyanoda visz, mint a Kedvencek képernyőn** — ugyanaz a
/// `FavoritesScreen.openEntry` dönt (egy helyen él a célképernyő-térkép, ezért
/// a kettő nem tud széttartani).
class FollowedSection extends ConsumerWidget {
  const FollowedSection({super.key});

  /// A szekció a főoldali `ListView`-ban **ennyi** helyet foglal, ha van
  /// követett tartalom (a kártya magassága + a fejléc).
  static const double listHeight = 118;

  /// A kártya szélessége (a magasságot a [listHeight] adja).
  static const double cardWidth = 136;

  /// **Legfeljebb ennyi** kedvenc látszik a főoldalon (a többi az „Összes" mögött).
  static const int maxItems = 3;

  /// A szekció felső hézagja — a widget **magával hozza**, ezért a rejtett
  /// állapot (nincs kedvenc) nem hagy maga után üres helyet.
  static const double topGap = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref
        .watch(favoritesProvider)
        .entries
        .where(
          (entry) =>
              entry.kind == FavoriteKind.artist ||
              entry.kind == FavoriteKind.organizer,
        )
        .take(maxItems)
        .toList(growable: false);
    if (followed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: FollowedSectionBody(
        entries: followed,
        onOpen: (entry) => FavoritesScreen.openEntry(context, ref, entry),
        onOpenAll: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
        ),
      ),
    );
  }
}

/// A szekció **megjelenítése** — szándékosan provider nélkül, hogy a teszt
/// pontosan azt mérhesse, ami kirajzolódik, és hogy a koppintás célja
/// (`onOpen`) mérhető legyen (a `FavoritesScreen.openEntry` valódi hívása
/// nélkül, ami teljes képernyőt nyitna). A **darabszámot** a hívó szabja meg
/// (a főoldal legfeljebb `FollowedSection.maxItems`-et ad át).
class FollowedSectionBody extends StatelessWidget {
  const FollowedSectionBody({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onOpenAll,
  });

  final List<FavoriteEntry> entries;
  final ValueChanged<FavoriteEntry> onOpen;
  final VoidCallback onOpenAll;

  /// A követés típusa szövegesen — a szótár kulcsa a magyar szó (a megjelenítés
  /// fordítja, ezért angol felületen is helyes).
  static String kindLabel(BuildContext context, FavoriteKind kind) {
    switch (kind) {
      case FavoriteKind.artist:
        return tr(context, 'DJ');
      case FavoriteKind.organizer:
        return tr(context, 'Szervező');
      case FavoriteKind.news:
      case FavoriteKind.event:
        // Ezek nem követés-jellegű kedvencek, ezért ide nem kerülnek — a
        // szöveg mégis létezik, hogy a megjelenítés ne maradhasson üresen.
        return tr(context, 'Kedvenc');
    }
  }

  static IconData _icon(FavoriteKind kind) {
    switch (kind) {
      case FavoriteKind.organizer:
        return Icons.apartment_rounded;
      case FavoriteKind.artist:
        return Icons.mic_external_on_rounded;
      case FavoriteKind.news:
      case FavoriteKind.event:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: tr(context, 'Kedvenceid'),
      child: Column(
        key: const Key('followed-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Kedvenceid'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // A teljes lista (eseményekkel együtt) egy koppintásra elérhető —
              // a szekció szándékosan csak a követést mutatja.
              TextButton(
                onPressed: onOpenAll,
                child: const AppText('Összes'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: FollowedSection.listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _FollowedCard(
                  entry: entry,
                  label: kindLabel(context, entry.kind),
                  icon: _icon(entry.kind),
                  onTap: () => onOpen(entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Egy követett DJ/szervező kártyája.
///
/// A formátum a főoldali `HomeActionCard`-éval egyezik (sötét színátmenet,
/// keret, lekerekítés), csak keskenyebb és függőleges — így a szekció nem lóg
/// ki a főoldal megjelenéséből.
class _FollowedCard extends StatelessWidget {
  const _FollowedCard({
    required this.entry,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final FavoriteEntry entry;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: FollowedSection.cardWidth,
      child: Semantics(
        button: true,
        label: '${entry.title} · $label',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('followed-${entry.kind.name}-${entry.id}'),
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainer,
                    scheme.surfaceContainerHigh,
                  ],
                ),
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 16, color: scheme.primary),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
