/// **Helyszíni jelenlét (QR) — a döntés**, tiszta kóddal.
///
/// MIÉRT: a helyszíni QR akkor ér valamit, ha a jelenlét **igazolható** és nem
/// lehet vele visszaélni. A QR ezért egy egyszerű linket tartalmaz (a mért
/// permalink-alakot vagy a `?p={id}` rövidlinket) — a **telefon kamerája**
/// olvassa be, az app pedig a linkből már tudja, melyik eseményről van szó. Így
/// **nem kell külön beolvasó** (kamera-engedély, új csomag) az appba.
///
/// ⚠️ **A VISSZAÉLÉS ELLENI SZABÁLY** (ez a modul lényege): a jelenlét csak
///  * az esemény **időablakában** rögzíthető (alapból 4 órával előtte … 12 órával
///    utána), és
///  * **tagonként egyszer**.
///
/// A fotózott/továbított QR így sem használható hetekkel később, és nem
/// halmozható ponttá.
library;

/// Mi lett a döntés?
enum CheckInStatus {
  /// Rögzíthető a jelenlét.
  ok,

  /// Még nem kezdődött el az ablak (túl korai).
  tooEarly,

  /// Lejárt az ablak (túl késői — pl. lefotózott kód hetekkel később).
  tooLate,

  /// Ez a tag **már jelezte** a jelenlétét erre az eseményre.
  alreadyCheckedIn,
}

/// Az esemény kezdete a nyers mezőkből (`start_date`, `start_time`).
///
/// ⚠️ A nap a **helyi** értelmezés szerint (`2026-10-17` + `23:00`), ugyanúgy,
/// ahogy a felület is mutatja — a szerveroldali ütemezés a site időzónáját
/// használja, és a kettő a magyar felhasználóknál ugyanaz.
/// Hiányzó/hibás értékre `null` (ilyenkor **nincs** jelenlét-gomb).
DateTime? eventStartFrom({required String startDate, required String startTime}) {
  final day = DateTime.tryParse(startDate.trim());
  if (day == null) return null;
  final parts = startTime.trim().split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour.clamp(0, 23), minute.clamp(0, 59));
}

/// Az ablak az esemény kezdete előtt (a helyszínen mindig van csúszás).
const Duration checkInOpenBefore = Duration(hours: 4);

/// Az ablak az esemény kezdete után (hazafelé már ne lehessen „ott voltam”-ot nyomni).
const Duration checkInOpenAfter = Duration(hours: 12);

/// A döntés — **tiszta függvény**, ezért teszttel mérhető.
CheckInStatus checkInStatus({
  required DateTime eventStart,
  required DateTime now,
  required bool alreadyCheckedIn,
  Duration openBefore = checkInOpenBefore,
  Duration openAfter = checkInOpenAfter,
}) {
  if (alreadyCheckedIn) return CheckInStatus.alreadyCheckedIn;
  if (now.isBefore(eventStart.subtract(openBefore))) return CheckInStatus.tooEarly;
  if (now.isAfter(eventStart.add(openAfter))) return CheckInStatus.tooLate;
  return CheckInStatus.ok;
}

/// Nyitva van-e az ablak (a felület ehhez köti a gomb megjelenítését)?
bool checkInWindowOpen({
  required DateTime eventStart,
  required DateTime now,
  Duration openBefore = checkInOpenBefore,
  Duration openAfter = checkInOpenAfter,
}) =>
    !now.isBefore(eventStart.subtract(openBefore)) &&
    !now.isAfter(eventStart.add(openAfter));

/// Emberi magyarázat a döntéshez — **a szótár kulcsa** (ezért fordul).
String checkInMessageKey(CheckInStatus status) {
  switch (status) {
    case CheckInStatus.ok:
      return 'Jelenlét rögzítése';
    case CheckInStatus.tooEarly:
      return 'Ez a kód a helyszínre szól — az esemény előtt néhány órával válik érvényessé.';
    case CheckInStatus.tooLate:
      return 'Ez a jelenlét-kód már lejárt.';
    case CheckInStatus.alreadyCheckedIn:
      return 'A jelenlétedet már rögzítettük erre az eseményre.';
  }
}
