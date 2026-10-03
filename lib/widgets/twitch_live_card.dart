import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../providers/twitch_live_provider.dart';
import '../screens/twitch/twitch_screen.dart';
import '../services/adaptive_card_layout.dart';
import '../services/twitch_live.dart';
import 'app_text.dart';

/// **Twitch-kártya a főoldalon** — élő adásnál mindig, azon kívül csak kérésre.
///
/// A tulajdonos kérése (2026-10-01): *„főoldalon jelenjen meg ha megy a stream +
/// legyen hozza cserelhető kép, képes kártya jelenjen meg a fooldalon”*.
///
/// ⚠️ A kép a Twitch **mozgó** előnézete (`previews-ttv/live_user_…`), ezért a
/// kártya 30 másodpercenként újratölti (gyorsítótár-kerülő paraméterrel) — így a
/// főoldal is „él”. Ha a tulajdonos saját képet állít be
/// (`app_settings/twitch.imageUrl`), az kerül a kártyára, és **nem** töltődik
/// újra (az egy pillanatkép).
///
/// ⚠️ **ÉLŐ ADÁS NÉLKÜL** (2026-10-02): a láthatóság döntése **egy helyen**,
/// tisztán van (`twitchCardVisible`) — a tulajdonos a
/// `"showWhenOffline": true` + saját kép beállításával a következő adást
/// **előre behirdetheti** anélkül, hogy új build kellene.
class TwitchLiveCard extends ConsumerStatefulWidget {
  const TwitchLiveCard({super.key});

  @override
  ConsumerState<TwitchLiveCard> createState() => _TwitchLiveCardState();
}

class _TwitchLiveCardState extends ConsumerState<TwitchLiveCard> {
  Timer? _imageTimer;
  int _imageTick = 0;

  @override
  void initState() {
    super.initState();
    _imageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _imageTick++);
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(twitchLiveProvider).valueOrNull;
    final override = ref.watch(twitchCardOverrideProvider).valueOrNull;
    // ⚠️ A BEHIRDETETT KÁRTYA AZONNAL MEGJELENIK (2026-10-02, a tulajdonos
    // jelzése: *„meg ez a twitch kártya a főoldalon 100 év mire betölt”*).
    //
    // A mért gyökér: a kártya a **Twitch-állapotra várt** (`live != null`), és
    // csak utána döntött — a Twitch GraphQL-válaszától függött tehát a
    // megjelenés, pedig a behirdetett kártyához **nem is kell** az állapot. Most
    // a beállításból azonnal döntünk, az „ÉLŐ” jelvény és a nézőszám pedig
    // akkor kerül fel, amikor az állapot megérkezik.
    final announcement = (override?.enabled ?? false) &&
        (override?.showWhenOffline ?? false) &&
        (override?.hasImage ?? false);
    final visible = announcement ||
        (live != null &&
            twitchCardVisible(
              isLive: live.isLive,
              enabled: override?.enabled ?? true,
              showWhenOffline: override?.showWhenOffline ?? false,
              hasImage: override?.hasImage ?? false,
            ));
    if (!visible) {
      // Nem látszik: a kártya **nem hagy üres helyet**.
      return const SizedBox.shrink();
    }

    final isLive = live?.isLive ?? false;
    final scheme = Theme.of(context).colorScheme;
    // A kép: **élő adásnál a stream mozgó előnézete** (a tulajdonos kérése:
    // *„ha elindul egy twitch stream, akkor a beharangozó kép helyett mehetne a
    // stream mozgóképe a főoldalon”*), adás nélkül a beállított beharangozó kép.
    final imageUrl = twitchCardImageUrl(
      isLive: isLive,
      liveThumbnailUrl: live?.thumbnailUrl ?? '',
      overrideImageUrl: override?.displayImageUrl ?? '',
      tick: _imageTick,
    );
    final header = (override?.headerText.isNotEmpty ?? false)
        ? override!.headerText
        : tr(context, 'Élőben a Twitch-csatornán');

    // ⚠️ SZÉLESSÉG-KORLÁT (2026-10-03, a tulajdonos jelzése): *„fekvő módban és
    // tableten fekvő módban a friss hírek kártya és a twitch beharangozó túl
    // nagy. Álló módban jó!”* — a 16:9-es kép a teljes szélességhez igazodott,
    // ezért széles nézetben óriási lett. A korlát a **közös** szabályból jön
    // (`services/adaptive_card_layout.dart`), ugyanaz, mint a hírkártyáknál.
    final maxWidth = cardMaxWidthFor(MediaQuery.sizeOf(context));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('twitch-live-card'),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TwitchScreen()),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ⚠️ GYORSÍTÁS (2026-10-02): a képet a `cached_network_image`
                        // tölti le **lemezes gyorsítótárral**, és legfeljebb 900 px
                        // szélességben dekódolja — a tulajdonos képe eredetileg
                        // 1672×941 (1,2 MB) volt, amit a telefon minden indulásnál
                        // újratöltött és teljes méretben dekódolt.
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 900,
                          maxWidthDiskCache: 900,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, _) =>
                              ColoredBox(color: scheme.surfaceContainerHighest),
                          errorWidget: (_, _, _) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.live_tv, size: 42)),
                          ),
                        ),
                        // ⚠️ Az „ÉLŐ" jelvény csak akkor igaz, ha tényleg megy az
                        // adás: a tulajdonos által előre kitett (offline) kártyán
                        // **nem** hazudunk élő adást.
                        if (isLive) const Positioned(top: 10, left: 10, child: _LiveBadge()),
                        if ((live?.viewers ?? 0) > 0)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _Chip(text: '${live!.viewers} ${tr(context, 'néző')}'),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        header,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((live?.title.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        AppText(
                          live!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const TwitchScreen()),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            // Offline (előre behirdetett) kártyán nem ígérünk élő
                            // adást — ilyenkor a gomb a csatorna oldalára visz.
                            label: AppText(isLive ? 'Nézd élőben' : 'Twitch-csatorna'),
                          ),
                        ],
                      ),
                    ],
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

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE91916),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const AppText(
        'ÉLŐ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: AppText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
