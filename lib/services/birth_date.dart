/// A **születési dátum** szabályai — tiszta, hálózat nélkül tesztelhető kód.
///
/// MIÉRT KÜLÖN FÁJL: a dátum a `community_profiles/{uid}.birthDate` mezőben
/// `'YYYY-MM-DD'` alakban él (a `birthDateVisible` logikai mező dönti el, hogy
/// megjelenik-e a nyilvános profilon). A regisztráció **kötelező** mezője, ezért
/// ugyanazt az ellenőrzést három hely is hívja (e-mailes regisztráció, Google-
/// regisztráció, profil-mentés) — egy helyen kell lennie, különben a szabályok
/// széttartanak.
///
/// A tulajdonos döntése (2026-09-27): **a közösségi funkciók 16 éves kortól**
/// használhatók, ezért a **regisztrációnál** a 16 év alatti dátum blokkol, a
/// dátumválasztó pedig a 16 évnél fiatalabb és a jövőbeli dátumot **nem is
/// kínálja fel**. A **már regisztrált** felhasználót semmi nem zárja ki
/// automatikusan: a nála tárolt fiatalabb dátumot legfeljebb **jelezzük**.
library;

/// `'YYYY-MM-DD'` — a Firestore-ban tárolt alak.
final RegExp _birthDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime _todayOf(DateTime? now) {
  final value = now ?? DateTime.now();
  return DateTime(value.year, value.month, value.day);
}

/// A születési dátum szabályai.
abstract final class BirthDate {
  /// A hiányzó dátum üzenete (a **szótár kulcsa** — a megjelenítés fordítja).
  static const String missingMessage = 'A születési dátum megadása kötelező.';

  /// A formailag hibás dátum üzenete (a **szótár kulcsa**).
  static const String invalidMessage =
      'Érvénytelen születési dátum. Adj meg valós dátumot (ÉÉÉÉ-HH-NN).';

  /// A regisztráció korhatára (a tulajdonos döntése).
  static const int minimumAge = 16;

  /// Ettől a kortól számít valaki nagykorúnak (a figyelmeztető sávhoz).
  static const int adultAge = 18;

  /// A 16 év alatti regisztráció üzenete (a **szótár kulcsa**).
  static const String underageMessage =
      'A regisztrációhoz legalább 16 évesnek kell lenned.';

  /// A legkorábbi elfogadott év (elgépelés ellen: `0202-01-01` nem dátum).
  static const int firstYear = 1900;

  /// A szöveg **normalizált** alakja, vagy `null`, ha nincs/érvénytelen.
  ///
  /// Érvényes: `YYYY-MM-DD`, valódi naptári nap (a `2024-02-31` nem az), nem a
  /// jövőben van, és az év legalább [firstYear].
  static String? normalize(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_birthDatePattern.hasMatch(text)) return null;
    final year = int.parse(text.substring(0, 4));
    final month = int.parse(text.substring(5, 7));
    final day = int.parse(text.substring(8, 10));
    if (year < firstYear) return null;
    final date = DateTime(year, month, day);
    // A `DateTime` normalizál (a február 31. március 2. lesz) — a visszaírás
    // mutatja meg, hogy valódi naptári napot kaptunk-e.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    if (date.isAfter(_todayOf(null))) return null;
    return text;
  }

  /// A kötelező dátum: hiányzó értékre [missingMessage], hibásra
  /// [invalidMessage] hibát dob, egyébként a normalizált alakot adja.
  static String requireValue(String? value) {
    final normalized = normalize(value);
    if (normalized != null) return normalized;
    final text = value?.trim() ?? '';
    throw StateError(text.isEmpty ? missingMessage : invalidMessage);
  }

  /// A regisztrációhoz kötelező dátum: hiányzó/hibás dátumra [missingMessage]
  /// vagy [invalidMessage], 16 év alatt [underageMessage] hibát dob.
  static String requireRegistrationValue(String? value) {
    final normalized = requireValue(value);
    if (!isAtLeast(normalized, minimumAge)) {
      throw StateError(underageMessage);
    }
    return normalized;
  }

  /// A megjelenítéshez: a tárolt szöveg `DateTime`-té alakítva (vagy `null`).
  static DateTime? parse(String? value) {
    final normalized = normalize(value);
    if (normalized == null) return null;
    return DateTime(
      int.parse(normalized.substring(0, 4)),
      int.parse(normalized.substring(5, 7)),
      int.parse(normalized.substring(8, 10)),
    );
  }

  /// `DateTime` → a tárolt `'YYYY-MM-DD'` alak (a dátumválasztó kimenete).
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Az életkor **egész évben**, vagy `null`, ha nincs érvényes dátum.
  ///
  /// ⚠️ Ez a **korhatár** és a **figyelmeztető sáv** feltétele. A dátumot
  /// önmagában nem tesszük közzé: a nyilvános vetítés csak egy `adult`
  /// jelzőt kap (lásd `functions/birth-date-plan.js`).
  static int? ageInYears(String? value, {DateTime? now}) {
    final date = parse(value);
    if (date == null) return null;
    final today = _todayOf(now);
    var age = today.year - date.year;
    final hadBirthday =
        today.month > date.month ||
        (today.month == date.month && today.day >= date.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? 0 : age;
  }

  /// Betöltötte-e már a megadott életkort (16 év alatt `false`).
  static bool isAtLeast(String? value, int years, {DateTime? now}) {
    final age = ageInYears(value, now: now);
    return age != null && age >= years;
  }

  /// 16–17 éves (a közösségi funkciókra jogosult **kiskorú**).
  static bool isMinor(String? value, {DateTime? now}) {
    final age = ageInYears(value, now: now);
    return age != null && age >= minimumAge && age < adultAge;
  }

  /// 18 éves vagy idősebb.
  static bool isAdult(String? value, {DateTime? now}) {
    final age = ageInYears(value, now: now);
    return age != null && age >= adultAge;
  }

  /// A dátumválasztó **utolsó** választható napja: ma − 16 év.
  ///
  /// A jövőbeli dátum és a 16 évnél fiatalabb dátum így **nem is választható**
  /// (a tulajdonos kérése), nem csak mentéskor derül ki. Ez a korlát
  /// **kizárólag a regisztrációnál** él (`pickBirthDate(registration: true)`).
  static DateTime lastAllowedPick({DateTime? now}) {
    final today = _todayOf(now);
    return DateTime(
      today.year - minimumAge,
      today.month,
      today.day,
    );
  }

  /// A **mai nap** (helyi idő, éjfél) — a nem-regisztrációs választó felső határa.
  ///
  /// MIÉRT: a **már regisztrált** tag a saját valódi dátumát írja be (Chat fül
  /// sávja, profil-szerkesztő), és a tulajdonos döntése szerint őt **semmi nem
  /// zárja ki** — ott csak a jövőbeli dátum tiltott.
  static DateTime today({DateTime? now}) => _todayOf(now);

  /// A partner profilja **nagykorúnak** olvasható-e.
  ///
  /// Először a szerveroldali `adult` jelzőt nézzük (ez akkor is megvan, ha a
  /// felhasználó a **dátumát** nem tette nyilvánossá), és csak ha az nincs, a
  /// látható dátumot. Ha **egyik sincs**, nem találgatunk: `false`.
  static bool partnerReadsAsAdult(
    Map<String, dynamic> profile, {
    DateTime? now,
  }) {
    if (profile['adult'] == true) return true;
    return isAdult(profile['birthDate'] as String?, now: now);
  }

  /// Kell-e a privát beszélgetésben a **nagykorú partner** figyelmeztető sáv?
  ///
  /// Feltétel: a mostani felhasználó **16–17 éves**, a partnere pedig
  /// **nagykorú**. Ha bármelyik dátum hiányzik (vagy a vetítésből nem derül ki
  /// a kor), a sáv **nem** jelenik meg — nem találgatunk.
  static bool needsAdultPartnerWarning({
    required String? viewerBirthDate,
    required bool partnerIsAdult,
    DateTime? now,
  }) => isMinor(viewerBirthDate, now: now) && partnerIsAdult;
}
