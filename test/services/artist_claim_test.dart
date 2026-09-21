import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist_claim_status.dart';

/// A DJ-adatlap **claim** javítása (a tulajdonos jelzése, 2026-09-21).
///
/// A tulajdonos szavai: *„egy dj beküldött egy dj-t… valamiért tudtam ÉN mint
/// admin claimelni - ami hiba"*, *„most a Denoiser accomon a Sunshite State dj
/// van claimelve - ami hiba - lekéne szedni rólam"*, majd a szabály:
/// *„Claimelni csak az tudja a feltett dj adatlapot, akinek egyezik az email
/// címe amivel regelt a dj adatlapon szereplő email címmel"* és *„a claim akkor
/// jelenjen CSAK meg ha valamelyik email cím egyezik (booking vagy privát)"*.
///
/// A **döntés a szerveré** (`functions/artist-claim-plan.js`), mert a privát
/// e-mail cím nem kerülhet a kliensre — itt azt mérjük, hogy a felület ehhez
/// igazodik-e, és hogy a modell biztonságos alapállapotból indul.
void main() {
  group('a claim-állapot modellje', () {
    test('a szerver válaszát olvassa', () {
      final status = ArtistClaimStatus.fromJson({
        'claimed': true,
        'mine': true,
        'canClaim': false,
        'reason': 'mine',
      });
      expect(status.claimed, isTrue);
      expect(status.mine, isTrue);
      expect(status.canClaim, isFalse);
      expect(status.reason, 'mine');
    });

    test('hiányzó mezők esetén semleges (nem engedélyez)', () {
      final status = ArtistClaimStatus.fromJson(const {});
      expect(status.claimed, isFalse);
      expect(status.mine, isFalse);
      expect(status.canClaim, isFalse);
    });

    test('hibás/hiányzó adatnál az „unknown" állapot sem engedélyez', () {
      expect(ArtistClaimStatus.fromJson(null).canClaim, isFalse);
      expect(ArtistClaimStatus.unknown.canClaim, isFalse);
      expect(ArtistClaimStatus.unknown.claimed, isFalse);
      expect(ArtistClaimStatus.unknown.mine, isFalse);
    });

    test('a modell NEM tartalmaz e-mail címet', () {
      final status = ArtistClaimStatus.fromJson({
        'claimed': false,
        'mine': false,
        'canClaim': true,
        'reason': 'ok',
        'email': 'titkos@gmail.com',
      });
      expect(status.canClaim, isTrue);
      // A mezőt szándékosan nem olvassuk ki: a cím a szerveren marad.
      expect(status.toString().contains('titkos@gmail.com'), isFalse);
    });
  });

  group('forrás-lint: a claim gomb a szerver döntéséhez igazodik', () {
    late String screen;
    late String service;
    late String provider;

    setUpAll(() {
      String read(String path) =>
          File(path).readAsStringSync().replaceAll('\r\n', '\n');
      screen = read('lib/screens/artists/artist_detail_screen.dart');
      service = read('lib/services/community_service.dart');
      provider = read('lib/providers/community_provider.dart');
    });

    test('a gomb CSAK akkor jelenik meg, ha a szerver engedélyezi', () {
      expect(
        screen,
        contains('else if (claim.canClaim)'),
        reason: 'claim.canClaim nélkül nem szabad claim gombot mutatni',
      );
      expect(
        screen,
        contains('ArtistClaimStatus.unknown'),
        reason: 'ismeretlen állapotban nem kínálunk claimet',
      );
      expect(
        screen,
        isNot(contains('emailVerified ==')),
        reason:
            'a puszta „van hitelesített e-mailje" nem elég a gombhoz — élesben '
            'pont ezért tudott a tulajdonos idegen adatlapot claimelni',
      );
    });

    test('a saját claim levétele is elérhető („lekéne szedni rólam")', () {
      expect(screen, contains('Claim visszavonása'));
      expect(screen, contains('_releaseArtistClaim('));
      expect(service, contains("'releaseArtistClaim'"));
    });

    test('a foglalt adatlapot megnevezzük (nincs néma gomb)', () {
      expect(screen, contains('már claimelte egy fiók'));
    });

    test('a beégetett hibaüzenet helyett a szerver üzenete jön', () {
      expect(
        screen,
        isNot(contains('nem egyezik a booking e-maillel')),
        reason: 'a valódi okot (nincs cím / nem egyezik) a szerver mondja meg',
      );
      expect(screen, contains('userFacingError(error)'));
    });

    test('a szolgáltatás a claim-állapotot kérdezi, nem találgat', () {
      expect(service, contains("'getArtistClaimStatus'"));
      expect(service, contains('Future<ArtistClaimStatus> artistClaimStatus('));
      expect(
        service,
        isNot(contains('isArtistClaimed')),
        reason: 'a bool-válasz nem mondta meg, hogy claimelhető-e',
      );
      expect(
        provider,
        contains('FutureProvider.family<ArtistClaimStatus, int>'),
      );
    });
  });

  group('forrás-lint: a claimelt DJ-adatlap a nyilvános profilon', () {
    late String profile;

    setUpAll(() {
      profile = File('lib/screens/more/community_users_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
    });

    test('van kattintható kártya a claimelt DJ-adatlapokhoz', () {
      // A tulajdonos kérése: *„ha valaki megnyitja egy user adatlapját és
      // claimelt egy DJ profilt, látszódjon az is ott, egy kattintható
      // kártyaként"*.
      expect(profile, contains('_ClaimedArtistsSection'));
      expect(profile, contains('_ClaimedArtistCard'));
      expect(
        profile,
        contains('claimedArtistsOfUser(widget.userId)'),
        reason: 'a lista a szerverről jön (a claimeket a szabályok védik)',
      );
      expect(
        profile,
        contains('ArtistDetailScreen(artistId: artistId, fallbackName: name)'),
        reason: 'a kártya koppintásra megnyitja az adatlapot',
      );
    });

    test('a szakasz a szerverről kéri a listát, nem közvetlen Firestore-ból', () {
      expect(profile, isNot(contains("collection('artist_claims')")));
      expect(
        File('lib/services/community_service.dart').readAsStringSync(),
        contains("'getClaimedArtistsForUser'"),
      );
    });
  });
}
