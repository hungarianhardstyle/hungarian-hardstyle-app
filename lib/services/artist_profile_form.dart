import '../models/artist.dart';

/// A DJ-adatlap **szerkesztő űrlapjának** szabálya — tiszta logika.
///
/// MIÉRT: a tulajdonos kérése (2026-09-22): *„Aki claimelte a dj adatlapját,
/// tudja szerkeszteni is."*
///
/// KÉT DOLGOT ITT DÖNTÜNK EL (mérhetően, hálózat nélkül):
///  1. **csak a megváltozott** mezők mennek ki — így egy elmentett űrlap nem
///     írja felül véletlenül azt, amihez a DJ hozzá sem nyúlt;
///  2. a kimenetben **soha** nincs tiltott kulcs (booking e-mail, privát cím,
///     láthatóság, kiemelés, mûfaj). A szerver is szűr (`artist-profile-plan.js`),
///     de a kliens ne is kérje — ez a réteg a +1 védelem.
///
/// A **hossz-korlátok** ugyanazok, mint a szerveren: a felület így azonnal szól,
/// a végső szót viszont a szerver mondja ki.

const int artistTitleMaxLength = 120;
const int artistShortFieldMaxLength = 80;
const int artistBiographyMaxLength = 6000;

/// A szerkeszthető szöveges mezők: űrlap-kulcs → felirat.
const Map<String, String> artistTextFieldLabels = {
  'title': 'Név',
  'realName': 'Valódi név',
  'city': 'Város',
  'country': 'Ország',
};

/// A közösségi linkek (ugyanaz a hét kulcs, mint a nyilvános adatlapon).
const List<String> artistSocialKeys = [
  'website',
  'facebook',
  'instagram',
  'tiktok',
  'spotify',
  'soundcloud',
  'youtube',
];

const Map<String, String> artistSocialLabels = {
  'website': 'Weboldal',
  'facebook': 'Facebook',
  'instagram': 'Instagram',
  'tiktok': 'TikTok',
  'spotify': 'Spotify',
  'soundcloud': 'SoundCloud',
  'youtube': 'YouTube',
};

/// Az űrlap kezdőértékei a **nyilvános adatlapból**.
Map<String, String> artistProfileFormInitial(Artist artist) => {
  'title': artist.title,
  'realName': artist.realName,
  'city': artist.city,
  'country': artist.country,
  'biography': artist.biography,
  for (final key in artistSocialKeys) key: artist.socialLinks[key] ?? '',
};

/// Ügyféloldali ellenőrzés — a szerver ugyanezt szigorúbban is megteszi.
/// Kimenet: mező → magyar hibaüzenet (üres, ha minden rendben).
Map<String, String> artistProfileFormErrors(Map<String, String> values) {
  final errors = <String, String>{};
  final title = (values['title'] ?? '').trim();
  if (title.isEmpty) {
    errors['title'] = 'A név nem maradhat üres.';
  } else if (title.length > artistTitleMaxLength) {
    errors['title'] = 'A név legfeljebb $artistTitleMaxLength karakter lehet.';
  }
  for (final key in ['realName', 'city', 'country']) {
    final value = (values[key] ?? '').trim();
    if (value.length > artistShortFieldMaxLength) {
      errors[key] =
          '${artistTextFieldLabels[key]} legfeljebb '
          '$artistShortFieldMaxLength karakter lehet.';
    }
  }
  if ((values['biography'] ?? '').length > artistBiographyMaxLength) {
    errors['biography'] =
        'A bemutatkozás legfeljebb $artistBiographyMaxLength karakter lehet.';
  }
  for (final key in artistSocialKeys) {
    final value = (values[key] ?? '').trim();
    if (value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !uri.host.contains('.')) {
      errors[key] = 'Teljes, http vagy https kezdetű cím kell.';
    }
  }
  return errors;
}

/// Tiltott kulcsok — ha valaha bekerülnének, ez a réteg kiszűri őket.
const Set<String> artistProfileForbiddenKeys = {
  'booking_email',
  'bookingEmail',
  'contact_email',
  'contactEmail',
  'visible',
  'featured',
  'booking_via_huhs',
  'genre',
  'genres',
  'slug',
  'categories',
};

/// A **mentendő** mezők: csak ami tényleg megváltozott.
///
/// [initial] a kezdőértékek (a betöltött adatlap), [values] a mostani űrlap,
/// az URL-ek pedig a kiválasztott új képek (ha van). Ami nem változott, az
/// **nincs** a kimenetben.
Map<String, dynamic> changedArtistProfileFields({
  required Map<String, String> initial,
  required Map<String, String> values,
  String? profileImageUrl,
  String? coverImageUrl,
}) {
  final fields = <String, dynamic>{};
  for (final key in [...artistTextFieldLabels.keys, ...artistSocialKeys]) {
    if (!values.containsKey(key)) continue;
    final next = (values[key] ?? '').trim();
    final before = (initial[key] ?? '').trim();
    if (key == 'title' && next.isEmpty) continue;
    if (next == before) continue;
    fields[key] = next;
  }

  // A közösségi linkek a szervernek `socialLinks` csomagban mennek.
  final socials = <String, String>{};
  for (final key in artistSocialKeys) {
    if (fields.containsKey(key)) socials[key] = fields.remove(key) as String;
  }
  if (socials.isNotEmpty) fields['socialLinks'] = socials;

  if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty) {
    fields['profileImageUrl'] = profileImageUrl.trim();
  }
  if (coverImageUrl != null && coverImageUrl.trim().isNotEmpty) {
    fields['coverImageUrl'] = coverImageUrl.trim();
  }

  fields.removeWhere((key, _) => artistProfileForbiddenKeys.contains(key));
  return fields;
}

/// Emberi összegzés a mentés után.
String artistProfileSavedLabel(int fieldCount) => fieldCount == 1
    ? 'Az adatlap mentve (1 mező).'
    : 'Az adatlap mentve ($fieldCount mező).';

/// Ha nem változott semmi, ne indítsunk fölösleges hívást.
String get artistProfileNothingToSave => 'Nem változtattál semmit.';
