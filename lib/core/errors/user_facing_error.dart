String userFacingError(Object? error) {
  final raw = '${error ?? ''}'.toLowerCase();
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
  if (raw.contains('requires-recent-login')) {
    return 'A művelethez friss bejelentkezés szükséges.';
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
  if (raw.contains('failed-precondition')) {
    return 'A szolgáltatás beállítása hiányos. Próbáld újra később.';
  }
  if (raw.contains('unauthenticated')) {
    return 'A munkamenet lejárt. Jelentkezz be újra.';
  }
  if (raw.contains('not-found')) {
    return 'A keresett adat nem található.';
  }
  if (raw.contains('already-exists')) {
    return 'Ez az adat már létezik.';
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
  if (raw.contains('cloudinary') || raw.contains('upload')) {
    return 'A kép feltöltése nem sikerült. Ellenőrizd a fájlt és az internetkapcsolatot.';
  }
  if (raw.contains('firebase') ||
      raw.contains('cloud_firestore') ||
      raw.contains('cloud_functions') ||
      raw.contains('dioexception')) {
    return 'A szolgáltatás nem válaszolt megfelelően. Próbáld újra később.';
  }
  return 'A művelet nem sikerült. Próbáld újra később.';
}
