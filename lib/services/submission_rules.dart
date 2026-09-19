/// Ki mit küldhet be — **ugyanaz a szabály, mint a szerveren**
/// (`functions/index.js` → `submissionRoutes` + `submissionRoleAllows`).
///
/// **MIÉRT kell ez a kliensen is:** a tulajdonos szabálya szerint DJ-t csak
/// DJ-szerepkörrel, eseményt és szervezőt csak szervezői szerepkörrel lehet
/// beküldeni. Korábban az **esemény** szerepkör nélkül volt: a szerver
/// elfogadta bárkitől, és az app is **minden bejelentkezett felhasználónak**
/// felkínálta a gombot — vagyis a felhasználó csak a beküldés végén, egy
/// szerverhibából tudta meg, hogy nem küldhet. A gomb mostantól nem is
/// látszódik, és a tiltás szövege is ugyanezt mondja.
///
/// A szerver a hiteles kapu; ez a réteg csak a **felületet** igazítja hozzá
/// (a tiltott kérést a szerver is elutasítja).
class SubmissionRules {
  /// Beküldés típusa → a hozzá szükséges szerepkörök (lista, hogy később egy
  /// szóval lazítható legyen, pl. `['organizer', 'dj']`).
  static const requiredRoles = <String, List<String>>{
    'event': ['organizer'],
    'artist': ['dj'],
    'organizer': ['organizer'],
  };

  static bool canSubmit({
    required String kind,
    required bool registered,
    required String role,
    required bool isAdmin,
  }) {
    if (!registered) return false;
    final allowed = requiredRoles[kind];
    // Ismeretlen típusnál nem engedünk: a szerver sem ismerné fel (adminnak sem
    // kínáljuk fel, mert a beküldés útvonala nem létezik).
    if (allowed == null) return false;
    if (isAdmin) return true;
    return allowed.contains(role.trim());
  }

  /// Érthető magyarázat, ha valaki mégis a beküldő űrlapra jut.
  static String denialMessage(String kind) => switch (kind) {
    'event' => 'Az eseménybeküldés szervezői szerepkörhöz kötött.',
    'artist' => 'A DJ-beküldés DJ-szerepkörhöz kötött.',
    'organizer' => 'A szervezőbeküldés szervezői szerepkörhöz kötött.',
    _ => 'Ehhez a beküldéshez nincs jogosultságod.',
  };

  /// A „Több → Beküldés" szakasz tájékoztatója (ki mit küldhet be).
  static const notice = 'Beküldeni szerepkör szerint lehet: eseményt és '
      'szervezőt szervezői, DJ-t DJ-szerepkörrel. Admin mindet beküldheti.';
}
