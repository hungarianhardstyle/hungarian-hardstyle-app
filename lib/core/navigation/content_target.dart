import 'package:flutter/material.dart';

import '../../screens/artists/artist_detail_screen.dart';
import '../../screens/events/event_detail_screen.dart';
import '../../screens/more/community_users_screen.dart';
import '../../screens/news/news_detail_screen.dart';
import '../../screens/organizers/organizer_detail_screen.dart';
import '../../screens/releases/release_detail_screen.dart';
import '../../services/wordpress_service.dart';

/// A **közös** célpont-feloldás: hova visz egy hivatkozás vagy egy értesítés.
///
/// MIÉRT KELL EZ KÖZÖS (a projekt 351-es tanulsága): a szabály lehet helyes,
/// a **bekötés** hibás. Ha az értesítés-központ és a Chat-`@`hivatkozás külön
/// ágakat tart karban, a kettő **széthúzhat** — pontosan ez volt az éles hiba
/// a DJ- és a szervező-értesítésnél (a koppintás némán nem csinált semmit).
/// Ezért mostantól **egy** helyen dől el, mi történik egy célponttal, és
/// mindkét felület ezt hívja.
///
/// A [targetType] a **hivatkozás** típusa (`user`, `article`, `artist`,
/// `organizer`, `event`, `release` — lásd `chat_mention_plan.dart`) **vagy** az
/// **értesítés** típusa (`profile`, `news`, `article`, …). A személynél a kettő
/// szándékosan eltér (`user` a hivatkozásban, `profile` az értesítésben),
/// ezért **mindkettőt** ismeri — különben a koppintás az egyik oldalon néma
/// lenne.
///
/// Ami **szándékosan nem** itt van: a `chat`, a `chat_report`, a
/// `private_conversation` és az `achievement` ág — azok az
/// értesítés-központban maradnak (azok nem „tartalom-célpontok", hanem a
/// központ saját nézetei).
///
/// @returns `true`, ha történt navigáció; `false`, ha a célpont nem oldható fel
///          (ismeretlen típus, üres/hibás azonosító, vagy a betöltés hibázott).
///          A hiba **el van nyelve**: a koppintás soha nem omlaszthatja össze a
///          felületet — a hívó dönthet úgy, hogy jelez a felhasználónak.
Future<bool> openContentTarget(
  NavigatorState navigator, {
  required String targetType,
  required String targetId,
}) async {
  final type = targetType.trim().toLowerCase();
  final target = targetId.trim();
  if (type.isEmpty || target.isEmpty) return false;
  // A `@mindenki` **nem tartalom-célpont**: nincs hova navigálni (a szerver
  // küldi mindenkinek az értesítést). Szándékosan **némán** tér vissza, hogy a
  // koppintás ne dobjon hibát és ne is nyisson fölösleges képernyőt.
  if (type == 'everyone') return false;
  try {
    switch (type) {
      // A személy: a hivatkozás `user`, az értesítés `profile` — mindkettő
      // ugyanoda visz (a nyilvános profil).
      case 'user':
      case 'profile':
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicProfileScreen(userId: target),
          ),
        );
        return true;
      case 'news':
      case 'article':
        final id = int.tryParse(target);
        if (id == null) return false;
        final post = await WordpressService().getPost(id);
        if (!navigator.mounted) return true;
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => NewsDetailScreen(post: post)),
        );
        return true;
      case 'event':
        final id = int.tryParse(target);
        if (id == null) return false;
        final event = (await WordpressService().getEvents(includePast: true))
            .firstWhere(
              (item) => item.id == id,
              orElse: () => throw StateError('Event not found'),
            );
        if (!navigator.mounted) return true;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
        return true;
      case 'release':
        final id = int.tryParse(target);
        if (id == null) return false;
        final release = (await WordpressService().getReleases()).firstWhere(
          (item) => item.id == id,
          orElse: () => throw StateError('Release not found'),
        );
        if (!navigator.mounted) return true;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ReleaseDetailScreen(release: release),
          ),
        );
        return true;
      case 'artist':
        final id = int.tryParse(target);
        if (id == null) return false;
        if (!navigator.mounted) return false;
        // ⚠️ ÉLES HIBA VOLT: az „Új DJ került fel" értesítés egyik ágba sem
        // esett bele, ezért a koppintás semmit nem csinált. Az azonosító itt
        // már megvan, ezért elég megnyitni a DJ-adatlapot.
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ArtistDetailScreen(artistId: id),
          ),
        );
        return true;
      case 'organizer':
        final id = int.tryParse(target);
        if (id == null) return false;
        if (!navigator.mounted) return false;
        // Ugyanaz a hiba-osztály: az „Új szervező került fel" sem nyitott
        // semmit.
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => OrganizerDetailScreen(organizerId: id),
          ),
        );
        return true;
      default:
        return false;
    }
  } catch (_) {
    // Eltűnt/elérhetetlen célpont (törölt cikk, hálózati hiba): a felület
    // maradjon használható, ne omoljon össze a koppintás miatt.
    return false;
  }
}
