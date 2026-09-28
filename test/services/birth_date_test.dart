import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/birth_date.dart';

/// **A születési dátum és a 16 éves korhatár** (a tulajdonos döntése,
/// 2026-09-27).
///
/// A tiszta szabályok **viselkedését** méri (nem a forrásszöveget), majd külön
/// forrás-linttel azt, hogy a kikényszerítés **tényleg be van kötve** mindkét
/// regisztrációs úton (e-mail/jelszó és Google), a profil-mentésnél, a Chat fül
/// felszólításánál és a nyilvános profilnál. Egy szabály önmagában nem ér semmit,
/// ha egyetlen hívó sincs.
void main() {
  // Fix „most” a determinisztikus méréshez: 2026-09-27.
  final now = DateTime(2026, 9, 27, 12);

  group('a dátum szabályai', () {
    test('a valódi naptári nap érvényes, a hibás alak nem', () {
      expect(BirthDate.normalize('1990-01-31'), '1990-01-31');
      expect(BirthDate.normalize(' 1990-01-31 '), '1990-01-31');
      expect(BirthDate.normalize('1990-1-1'), isNull);
      expect(BirthDate.normalize('1990/01/31'), isNull);
      expect(BirthDate.normalize('1990-13-01'), isNull);
      expect(BirthDate.normalize('1990-02-31'), isNull, reason: 'nincs ilyen nap');
      expect(BirthDate.normalize('1899-12-31'), isNull, reason: 'túl korai év');
      expect(BirthDate.normalize(''), isNull);
      expect(BirthDate.normalize(null), isNull);
    });

    test('a jövőbeli dátum nem születési dátum', () {
      final future = DateTime.now().add(const Duration(days: 2));
      expect(BirthDate.normalize(BirthDate.format(future)), isNull);
    });

    test('a hiányzó dátum a kötelező üzenetet dobja, a hibás a sajátját', () {
      expect(
        () => BirthDate.requireValue(''),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            BirthDate.missingMessage,
          ),
        ),
      );
      expect(
        () => BirthDate.requireValue('1990-02-31'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            BirthDate.invalidMessage,
          ),
        ),
      );
    });

    test('az életkor betöltött években számol', () {
      expect(BirthDate.ageInYears('2010-09-27', now: now), 16);
      expect(BirthDate.ageInYears('2010-09-28', now: now), 15);
      expect(BirthDate.ageInYears('2008-09-27', now: now), 18);
      expect(BirthDate.ageInYears('2008-09-28', now: now), 17);
      expect(BirthDate.ageInYears('', now: now), isNull);
    });

    test('a regisztrációs küszöb a 16. születésnap', () {
      expect(BirthDate.isAtLeast('2010-09-27', 16, now: now), isTrue);
      expect(BirthDate.isAtLeast('2010-09-28', 16, now: now), isFalse);
      expect(BirthDate.isAtLeast('', 16, now: now), isFalse);
      // A regisztráció a 16 év alattit **elutasítja** (a már regisztráltakat
      // semmi nem zárja ki — az a `requireValue`, lásd a szolgáltatást).
      //
      // ⚠️ MÉRT HIBA JAVÍTVA (2026-09-28): a `requireRegistrationValue()` a
      // **valódi** mai naphoz méri a kort (nincs `now` paramétere, ezért a fenti
      // `now` fixture nem érvényesül benne). A korábbi, beégetett `'2010-09-28'`
      // így **2026-09-28-tól magától elbukott** — a teszt időzített bomba volt,
      // nem a kód romlott el. A dátum most a valódi mai napból számol (15 évvel
      // ezelőtt), ezért a mérés bármelyik napon ugyanazt jelenti.
      final today = BirthDate.today();
      final underage = BirthDate.format(
        DateTime(today.year - 15, today.month, today.day),
      );
      expect(
        () => BirthDate.requireRegistrationValue(underage),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            BirthDate.underageMessage,
          ),
        ),
      );
      expect(BirthDate.requireRegistrationValue('1990-01-31'), '1990-01-31');
    });

    test('a dátumválasztó utolsó napja ma − 16 év (regisztrációnál)', () {
      final last = BirthDate.lastAllowedPick(now: now);
      expect(last, DateTime(2010, 9, 27));
      expect(BirthDate.format(last), '2010-09-27');
      // A **már regisztrált** tagnál a valódi dátum is beírható: ott a mai nap
      // a felső határ, és csak a jövőbeli dátum tiltott.
      expect(BirthDate.today(now: now), DateTime(2026, 9, 27));
      expect(BirthDate.format(BirthDate.today(now: now)), '2026-09-27');
    });

    test('a kiskorú/nagykorú sáv a 16–17 és a 18+ határon dől el', () {
      expect(BirthDate.isMinor('2008-09-28', now: now), isTrue, reason: '17 éves');
      expect(BirthDate.isMinor('2010-09-27', now: now), isTrue, reason: '16 éves');
      expect(BirthDate.isMinor('2010-09-28', now: now), isFalse, reason: '15 éves');
      expect(BirthDate.isMinor('2008-09-27', now: now), isFalse, reason: '18 éves');
      expect(BirthDate.isAdult('2008-09-27', now: now), isTrue);
      expect(BirthDate.isAdult('2008-09-28', now: now), isFalse);
    });

    test('a figyelmeztető sáv CSAK kiskorú ↔ nagykorú páron jelenik meg', () {
      expect(
        BirthDate.needsAdultPartnerWarning(
          viewerBirthDate: '2009-01-01',
          partnerIsAdult: true,
          now: now,
        ),
        isTrue,
      );
      // Felnőtt néző: nem az ő figyelmeztetése.
      expect(
        BirthDate.needsAdultPartnerWarning(
          viewerBirthDate: '1990-01-01',
          partnerIsAdult: true,
          now: now,
        ),
        isFalse,
      );
      // Két kiskorú: nem ez az eset.
      expect(
        BirthDate.needsAdultPartnerWarning(
          viewerBirthDate: '2009-01-01',
          partnerIsAdult: false,
          now: now,
        ),
        isFalse,
      );
      // Hiányzó saját dátum: **nem találgatunk**.
      expect(
        BirthDate.needsAdultPartnerWarning(
          viewerBirthDate: null,
          partnerIsAdult: true,
          now: now,
        ),
        isFalse,
      );
    });

    test('a partner kora a szerver jelzőjéből vagy a látható dátumból jön', () {
      expect(BirthDate.partnerReadsAsAdult({'adult': true}, now: now), isTrue);
      expect(
        BirthDate.partnerReadsAsAdult({'adult': true, 'birthDate': '2009-01-01'}, now: now),
        isTrue,
        reason: 'a szerver jelzője az elsődleges (a dátum lehet rejtett)',
      );
      expect(
        BirthDate.partnerReadsAsAdult({'birthDate': '1990-01-31'}, now: now),
        isTrue,
      );
      expect(
        BirthDate.partnerReadsAsAdult({'birthDate': '2009-01-01'}, now: now),
        isFalse,
      );
      // Semmi információ: nem tippelünk.
      expect(BirthDate.partnerReadsAsAdult(const {}, now: now), isFalse);
    });
  });

  group('a kikényszerítés be van kötve (forrás-lint)', () {
    final service = File('lib/services/community_service.dart').readAsStringSync();
    final screen = File(
      'lib/screens/community/community_screen.dart',
    ).readAsStringSync();
    final prompt = File('lib/screens/community/private_messages_screen.dart')
        .readAsStringSync();
    final publicProfile = File(
      'lib/screens/more/community_users_screen.dart',
    ).readAsStringSync();
    final fields = File(
      'lib/widgets/community_profile_form_fields.dart',
    ).readAsStringSync();
    final field = File('lib/widgets/birth_date_field.dart').readAsStringSync();

    test('az e-mailes regisztráció az ELSŐ lépésben ellenőrzi és elmenti', () {
      final start = service.indexOf('Future<void> register({');
      final end = service.indexOf('Future<void> signIn', start);
      final body = service.substring(start, end);
      expect(body, contains('BirthDate.requireRegistrationValue(birthDate)'));
      expect(
        body.indexOf('BirthDate.requireRegistrationValue(birthDate)'),
        lessThan(body.indexOf('createUserWithEmailAndPassword')),
        reason: 'a dátum nélkül ne jöjjön létre Auth fiók',
      );
      expect(body, contains("'birthDate': normalizedBirthDate,"));
      expect(body, contains("'birthDateVisible': false"));
      // A szerveroldali második kapu is megkapja a dátumot.
      expect(body, contains("'birthDate': normalizedBirthDate}"));
    });

    test('a Google-regisztráció is kéri a 16+ dátumot, a bejelentkezés nem', () {
      final start = service.indexOf('Future<bool> signInWithGoogle({');
      final end = service.indexOf('\n  }', service.indexOf('return true;', start));
      final body = service.substring(start, end);
      expect(body, contains('BirthDate.requireRegistrationValue('));
      expect(body, contains("'birthDate': requiredBirthDate"));
      // A meglévő profilt nem írjuk felül, és nem is kérjük újra.
      expect(body, contains("'birthDate': providedBirthDate"));
    });

    test('a profil mentése kötelezővé teszi a dátumot', () {
      expect(
        fields,
        contains('    BirthDate.requireValue(birthDate);'),
        reason: 'a közös profil-mentő útvonal ellenőriz',
      );
      expect(fields.indexOf('BirthDate.requireValue(birthDate)'), lessThan(
        fields.indexOf('await claimDisplayName(normalizedName)'),
      ));
      final start = screen.indexOf('Future<void> _saveProfile() async {');
      final body = screen.substring(start, start + 4000);
      expect(body, contains('requireBirthDate: true'));
      expect(body, contains("'birthDate': _birthDate"));
      expect(body, contains("'birthDateVisible': _birthDateVisible"));
    });

    test('a külön dátum-mentés egy mezőt ír, és csak a saját profilra', () {
      final start = service.indexOf('Future<void> saveBirthDate(');
      final body = service.substring(start, start + 1400);
      expect(body, contains("auth.currentUser?.uid != id"));
      expect(body, contains("'birthDate': normalized"));
      expect(body, contains('BirthDate.requireValue(birthDate)'));
      expect(
        body,
        isNot(contains('birthDateVisible')),
        reason: 'a gyors mentés nem nyúl a megjelenítés kapcsolójához',
      );
    });

    test('a regisztrációs űrlap és a szerkesztő is mutatja a mezőt', () {
      expect(
        screen,
        contains('CommunityProfileBirthDateField('),
        reason: 'a születési dátum mező bekötve',
      );
      expect(screen, contains('showVisibility: true'));
      expect(screen, contains('_birthDateError(_birthDate)'));
      expect(
        screen,
        contains('birthDate: _register ? _birthDate : null'),
        reason: 'a Google-ág regisztrációnál átadja, bejelentkezésnél nem',
      );
    });

    test('a dátumválasztó a 16 évnél fiatalabbat csak regisztrációnál zárja ki', () {
      expect(field, contains('  final last = registration'));
      expect(
        field,
        contains('      ? BirthDate.lastAllowedPick()'),
        reason: 'regisztrációnál ma − 16 év a felső határ',
      );
      expect(
        field,
        contains('      : BirthDate.today();'),
        reason: 'már regisztrált tagnál a valódi dátum is beírható',
      );
      expect(field, contains('lastDate: last'));
      expect(
        field,
        contains('if (initial.isAfter(last)) initial = last;'),
        reason: 'egy határon kívüli tárolt dátum ne borítsa fel a választót',
      );
      expect(
        field,
        contains('A közösségi funkciók 16 éves kortól használhatók.'),
        reason: 'a rövid magyarázat a felületen van',
      );
      expect(
        field,
        contains('!BirthDate.isAtLeast(value, BirthDate.minimumAge)'),
        reason: 'a már tárolt, 16 év alatti dátumot jelzi (nem zár ki senkit)',
      );
      expect(
        screen,
        contains('registration: true,'),
        reason: 'a regisztrációs űrlap kéri a 16 éves korlátot',
      );
    });

    test('a Chat fül felszólítása és a nyilvános megjelenítés be van kötve', () {
      expect(screen, contains('_birthDateMissing'));
      expect(screen, contains('_scheduleBirthDateDialog()'));
      expect(screen, contains('BirthDatePromptDialog()'));
      expect(screen, contains('_service.saveBirthDate(user.uid, picked)'));
      expect(
        screen,
        contains('A születési dátumod még nincs megadva.'),
        reason: 'a sáv szövege szótári kulcs',
      );
      // A nyilvános profil a szerver által vetített mezőt olvassa.
      expect(publicProfile, contains("data['birthDate'] as String?"));
      expect(publicProfile, contains("AppText('Születési dátum')"));
      // A privát chat figyelmeztető sávja a dátumokból számol.
      expect(prompt, contains('_evaluateAdultPartnerWarning()'));
      expect(
        prompt,
        contains('BirthDate.needsAdultPartnerWarning('),
        reason: 'a sáv feltétele egy helyen, tesztelhetően él',
      );
      expect(
        prompt,
        contains('if (_showAdultPartnerWarning) _adultPartnerWarning(),'),
        reason: 'a sáv a beszélgetés tetején, alapból látszik',
      );
    });

    test('a szótárban minden új üzenet angolul is megvan', () {
      final dictionary =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in const [
        BirthDate.missingMessage,
        BirthDate.invalidMessage,
        BirthDate.underageMessage,
        'Érvénytelen születési dátum.',
        'Születési dátum',
        'Dátum kiválasztása',
        'Nincs megadva',
        'Látható a nyilvános profilomon',
        'Alapból rejtve marad; csak te dönthetsz a megjelenítéséről.',
        'A közösségi funkciók 16 éves kortól használhatók.',
        'Figyelem: a megadott dátum szerint 16 évesnél fiatalabb vagy.',
        'A születési dátumod még nincs megadva.',
        'Megadom',
        'Hiányzik a születési dátum',
        'A közösségi funkciók használatához add meg a születési dátumodat. '
            'Ez nem jelenik meg nyilvánosan, amíg nem engedélyezed.',
        'A születési dátumod elmentve. A nyilvános megjelenítést a profil '
            'szerkesztésében kapcsolhatod be.',
        'A születési dátum mentéséhez bejelentkezés szükséges.',
        'Figyelem: a beszélgetőpartnered nagykorú. Ha kellemetlenül érzed '
            'magad, jelentsd a felhasználót és blokkold.',
      ]) {
        expect(
          dictionary[key],
          isNotNull,
          reason: 'hiányzó angol kulcs: $key',
        );
        expect('${dictionary[key]}'.trim(), isNotEmpty);
      }
    });
  });
}
