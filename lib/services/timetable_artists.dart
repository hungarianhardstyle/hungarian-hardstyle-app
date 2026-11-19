import '../models/event.dart';

const _from = 'áàâäãéèêëíìîïóòôöőõúùûüűçñ';
const _to = 'aaaaaeeeeiiiioooooouuuuucn';

/// Összehasonlításra: kisbetű, ékezet nélkül, csak betű-számjegy
/// (`Höfstatters` ≡ `Höfstätters`, `Dr. Skull` ≡ `Dr Skull`).
String _fold(String text) {
  final out = StringBuffer();
  for (final c in text.toLowerCase().split('')) {
    final i = _from.indexOf(c);
    final ch = i >= 0 ? _to[i] : c;
    if (RegExp(r'[a-z0-9]').hasMatch(ch)) out.write(ch);
  }
  return out.toString();
}

/// Az időbeosztás-sor DJ-jének azonosítója az esemény fellépői közül, vagy
/// `null`. shortcut: csak pontos névegyezés (b2b/„vs" sorokra nincs), ha több
/// ilyen sor lesz, a nevet szét kell bontani.
int? timetableArtistId(HuhsEvent event, String name) {
  final wanted = _fold(name);
  if (wanted.isEmpty) return null;
  for (final artist in event.artists) {
    if (artist.id > 0 && _fold(artist.name) == wanted) return artist.id;
  }
  return null;
}
