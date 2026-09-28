/// **Megosztható tartalom-linkek** — tiszta, hálózat nélkül tesztelhető kód.
///
/// MIÉRT (a tulajdonos választotta a használat-növelő csomagból a *„megosztható
/// kártyák"* pontot): a legolcsóbb növekedési út az, ha a tagok **maguk viszik**
/// a tartalmat — egy hír, egy buli, egy kiadvány vagy egy DJ-adatlap linkje a
/// Messengerben/Facebookon. A megosztott szöveg ezért **három** dolgot tartalmaz:
/// a tartalom címét, a **kanonikus webes linket** (hogy app nélkül is
/// olvasható legyen) és egy sor az appról a **Play-linkkel** (ez hozza az új
/// telepítést).
///
/// ⚠️ **MÉRT HELYZET (2026-09-28):** az App Links **be van állítva** — a
/// `https://hungarianhardstyle.hu/.well-known/assetlinks.json` **HTTP 200**,
/// `handle_all_urls` viszonnyal, a `hu.hungarianhardstyle.app` csomagra és a
/// **Play-aláíró kulcs** lenyomatára. Az app viszont a
/// `AndroidManifest.xml`-ben **csak a `/invite` útvonalat** fogja el, ezért a
/// megosztott cikk-/esemény-link egyelőre a **böngészőt** nyitja (a tartalom ott
/// is olvasható). Az appon belüli megnyitás (útvonal-fogás + belső
/// útvonalválasztás) **külön kör** — ez a modul szándékosan nem ígér többet.
///
/// ⚠️ **A LINKEK MÉRVE (nem tippelve):** a hír és a DJ **saját `link` mezőt** ad
/// (`/posts` → `…/2026/09/26/hard-bass-2026-himnusz/`, `/artists` →
/// `…/djs/adam-bass/`), az **esemény** és a **kiadvány** végpont viszont **nem**
/// (mért mezőlista: csak `facebook_event_url` / `ticket_url`, illetve
/// `links` / `presave_url` / `free_external_link`). Ezekre a WordPress
/// **kanonikus rövidlinkje** a helyes út (`?p={id}`), amit a WordPress a szép
/// permalinkre irányít — **mérve**: `?p=12505` → `200 …/events/hard-base-classic…`,
/// `?p=12699` → `200 …/releases/goze-change-of-pace/`.
library;

import '../core/i18n/app_strings.dart';

/// A Play-áruházi hivatkozás — a megosztott szövegben ez hozza az új telepítést.
const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app';

/// A magyar oldal gyökere (a kanonikus rövidlinkhez).
const String siteBaseUrl = 'https://hungarianhardstyle.hu';

/// A megosztott üzenet záró sora — **ez a szótár kulcsa**, ezért fordul.
///
/// Szándékosan rövid: a címzett egy sorban megtudja, mi az app, és hol tölti le.
const String shareAppLineKey =
    'Hungarian Hardstyle app — hírek, bulik, DJ-k egy helyen: {store}';

/// Kanonikus **webes** link egy tartalomhoz.
///
/// * ha a végpont ad `link` mezőt (hír, DJ), azt használjuk — az a WordPress
///   saját permalinkje;
/// * egyébként a **rövidlink** (`?p={id}`), amit a WordPress magától a szép
///   permalinkre irányít (mérve: esemény és kiadvány).
String contentShareUrl({required int id, String? canonicalLink}) {
  final canonical = (canonicalLink ?? '').trim();
  if (canonical.isNotEmpty) return canonical;
  if (id <= 0) return siteBaseUrl;
  return '$siteBaseUrl/?p=$id';
}

/// A megosztás **tárgya** (e-mailben ez lesz a tárgy): a tartalom címe.
///
/// Ha nincs cím (hiányos adat), az app neve marad — így a megosztás sosem lesz
/// üres tárgyú.
String shareSubject(String title) {
  final clean = title.trim();
  return clean.isEmpty ? 'Hungarian Hardstyle' : clean;
}

/// A megosztott **üzenet**: cím → link → egy sor az appról.
///
/// A sorok szándékosan külön sorba kerülnek, mert a legtöbb üzenetküldő az első
/// linket kattinthatóvá teszi, a Play-link pedig így is látható marad.
String buildShareMessage({required String title, required String url}) {
  final cleanTitle = title.trim();
  final cleanUrl = url.trim();
  final appLine = AppStrings.trArgs(shareAppLineKey, {'store': playStoreUrl});
  final lines = <String>[
    if (cleanTitle.isNotEmpty) cleanTitle,
    if (cleanUrl.isNotEmpty) cleanUrl,
    if (appLine.trim().isNotEmpty) appLine,
  ];
  return lines.join('\n\n');
}

/// Megosztandó szöveg egy **tartalomhoz** (a link feloldásával együtt).
String buildContentShareMessage({
  required String title,
  required int id,
  String? canonicalLink,
}) {
  return buildShareMessage(
    title: title,
    url: contentShareUrl(id: id, canonicalLink: canonicalLink),
  );
}
