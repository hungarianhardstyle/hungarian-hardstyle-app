import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';

String userFacingError(Object? error) {
  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty && message != 'null') return message;
  }
  final raw = '${error ?? ''}'.toLowerCase();
  final isCloudinaryRequest =
      error is DioException &&
      error.requestOptions.uri.host.toLowerCase().contains('cloudinary.com');

  if (isCloudinaryRequest || raw.contains('cloudinary')) {
    return 'A kép feltöltése nem sikerült. Ellenőrizd a fájlt és az internetkapcsolatot.';
  }
  if (raw.contains('network-request-failed') ||
      raw.contains('socketexception') ||
      raw.contains('connection refused') ||
      raw.contains('timed out')) {
    return 'Nem sikerült kapcsolódni. Ellenőrizd az internetkapcsolatot.';
  }
  if (raw.contains('permission-denied') || raw.contains('permission denied')) {
    return 'Ehhez a művelethez nincs megfelelő jogosultság.';
  }
  if (raw.contains('admin-restricted-operation')) {
    return 'Ehhez a művelethez regisztrált fiók szükséges.';
  }
  if (raw.contains('user-not-found')) {
    return 'A felhasználó nem található.';
  }
  if (raw.contains('too-many-requests')) {
    return 'Túl sok próbálkozás történt. Próbáld újra később.';
  }
  if (raw.contains('already-exists') || raw.contains('already exists')) {
    if (raw.contains('display-name-already-in-use') ||
        raw.contains('név már foglalt')) {
      return 'Ez a név már foglalt.';
    }
    if (raw.contains('eseményt már értékelted')) {
      return 'Ezt az eseményt már értékelted.';
    }
    return 'Ez az adat már létezik.';
  }
  if (raw.contains('csak a részvételüket jelző felhasználók értékelhetik') ||
      raw.contains('korábban az ott leszek lehetőséget választottad')) {
    return 'Ezt az eseményt csak akkor értékelheted, ha korábban az Ott leszek lehetőséget választottad.';
  }
  if (raw.contains('requires-recent-login')) {
    return 'A művelethez friss bejelentkezés szükséges.';
  }
  if (raw.contains('felhasználónevet évente') ||
      raw.contains('névváltoztatási lehetőség')) {
    return 'A felhasználónevet évente egyszer lehet módosítani.';
  }
  if (raw.contains('invalid-argument')) {
    return 'Érvénytelen adatot adtál meg.';
  }
  if (raw.contains('already in use') || raw.contains('email-already-in-use')) {
    return 'Ez az adat már létezik.';
  }
  if (raw.contains('invalid-email')) return 'Érvénytelen e-mail-cím.';
  if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
    return 'A megadott e-mail-cím vagy jelszó hibás.';
  }
  if (raw.contains('app check') ||
      raw.contains('appcheck') ||
      raw.contains('attestation') ||
      raw.contains('play integrity') ||
      raw.contains('integrity token')) {
    return 'A biztonsági ellenőrzés átmenetileg nem érhető el. Próbáld újra később.';
  }
  if (raw.contains('failed-precondition')) {
    return 'A szolgáltatás beállítása hiányos. Próbáld újra később.';
  }
  if (raw.contains('unauthenticated')) {
    return 'A munkamenet lejárt vagy a művelethez bejelentkezés szükséges. Jelentkezz be újra.';
  }
  if (raw.contains('not-found')) {
    return 'A keresett adat nem található.';
  }
  if (raw.contains('resource-exhausted')) {
    return 'A szolgáltatás jelenleg túlterhelt. Próbáld újra később.';
  }
  if (raw.contains('deadline-exceeded')) {
    return 'A kérés túl sokáig tartott. Próbáld újra később.';
  }
  if (raw.contains('cancelled')) {
    return 'A művelet megszakadt.';
  }
  if (raw.contains('aborted')) {
    return 'A művelet ütközés miatt nem fejeződött be. Próbáld újra.';
  }
  if (raw.contains('out-of-range')) {
    return 'Érvénytelen tartományt adtál meg.';
  }
  if (raw.contains('data-loss') || raw.contains('internal')) {
    return 'Belső szolgáltatási hiba történt. Próbáld újra később.';
  }
  if (raw.contains('unavailable')) {
    return 'A szolgáltatás átmenetileg nem érhető el. Próbáld újra később.';
  }
  if (raw.contains('upload') || raw.contains('upload preset')) {
    return 'A kép feltöltése nem sikerült. Ellenőrizd a fájlt és az internetkapcsolatot.';
  }
  if (error is FirebaseException) {
    return 'A szolgáltatás jelenleg nem érhető el. Próbáld újra később.';
  }
  if (raw.contains('firebase') ||
      raw.contains('cloud_firestore') ||
      raw.contains('cloud_functions') ||
      raw.contains('dioexception')) {
    return 'A szolgáltatás nem válaszolt megfelelően. Próbáld újra később.';
  }
  return 'A művelet nem sikerült. Próbáld újra később.';
}
