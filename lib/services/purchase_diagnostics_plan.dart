/// A **vásárlási diagnosztika** tiszta szabálya — nulla függőség, ezért mérhető.
///
/// MIÉRT KELL: a 2026-09-22-i ország-hibánál („A tétel nem áll rendelkezésre az
/// adott országban") **végig nem láttuk**, mit válaszol a Play Billing az adott
/// készüléken. Emiatt több körön át **következtetni** kellett: a hibaüzenet a
/// Play saját ablaka volt, a kód pedig néma. Ez a modul azt a hiányzó műszert
/// adja meg: a lekérdezés eredményét **és a nyers hibakódot** egy olvasható
/// magyar jelentésbe rendezi, amit a felhasználó (a tulajdonos) el tud küldeni.
///
/// ⚠️ A LÉNYEG a **nyers kód** (`IAPError.code`) és a Play üzenete: ezek nélkül
/// csak találgatni lehet. Ezért a jelentés **soha nem szépíti el** őket, és nem
/// is fordítja le a Play saját szövegét — az bizonyíték.
library;

/// Mit lát a Play Billing ezen a készüléken? — egyetlen, kiszámítható verdikt.
enum PurchaseDiagnosticsVerdict {
  /// A Play Billing maga nem érhető el (régi/elavult Play Áruház, hiányzó
  /// szolgáltatás). Ilyenkor **egyetlen** termék sem kérdezhető le.
  storeUnavailable,

  /// A lekérdezés hibát adott (és nem jött vissza termék).
  queryFailed,

  /// A lekérdezés lefutott, de **egyetlen** termék sem jött vissza.
  noProducts,

  /// Néhány termék visszajött, néhány nem (részleges katalógus).
  partialCatalog,

  /// A kért termékek **mind** visszajöttek — a katalógus rendben van.
  catalogReady,
}

/// Egy termék, ahogy a Play visszaadta (a jelentéshez).
class PurchaseDiagnosticProduct {
  const PurchaseDiagnosticProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.currencyCode,
  });

  final String id;
  final String title;
  final String price;
  final String currencyCode;

  /// `cím — ár` alak, üres címnél csak az ár.
  String get label => title.trim().isEmpty ? price : '$title — $price';
}

/// A diagnosztika bemenete: pontosan az, amit a készüléken **mérni** tudunk.
class PurchaseDiagnosticsInput {
  const PurchaseDiagnosticsInput({
    required this.storeAvailable,
    required this.queriedIds,
    required this.products,
    this.notFoundIds = const [],
    this.queryError,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.lastErrorProductId,
    this.platform = '',
    this.appVersion = '',
    this.accountEmail = '',
  });

  final bool storeAvailable;
  final List<String> queriedIds;
  final List<PurchaseDiagnosticProduct> products;
  final List<String> notFoundIds;

  /// A **lekérdezés** hibája (ha volt).
  final String? queryError;

  /// A **legutóbbi vásárlási kísérlet** nyers hibakódja a Play-től.
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final String? lastErrorProductId;

  final String platform;
  final String appVersion;

  /// A bejelentkezett fiók (a Play-fióktól **külön** dolog — ez a HUHS-fiók).
  final String accountEmail;
}

/// A verdikt: egyetlen kérdésre egyetlen válasz, hogy ne lehessen félreolvasni.
PurchaseDiagnosticsVerdict purchaseDiagnosticsVerdict(
  PurchaseDiagnosticsInput input,
) {
  if (!input.storeAvailable) return PurchaseDiagnosticsVerdict.storeUnavailable;
  if (input.products.isEmpty) {
    return (input.queryError ?? '').trim().isEmpty
        ? PurchaseDiagnosticsVerdict.noProducts
        : PurchaseDiagnosticsVerdict.queryFailed;
  }
  if (input.notFoundIds.isNotEmpty) {
    return PurchaseDiagnosticsVerdict.partialCatalog;
  }
  return PurchaseDiagnosticsVerdict.catalogReady;
}

/// A verdikt magyar mondatban — **mit jelent**, nem csak mit mértünk.
String purchaseDiagnosticsVerdictText(PurchaseDiagnosticsVerdict verdict) {
  switch (verdict) {
    case PurchaseDiagnosticsVerdict.storeUnavailable:
      return 'A Google Play vásárlási szolgáltatása nem érhető el ezen a '
          'készüléken. Ez általában elavult Play Áruház vagy Play Szolgáltatás '
          'miatt van: frissítsd őket, majd indítsd újra a készüléket.';
    case PurchaseDiagnosticsVerdict.queryFailed:
      return 'A Play hibát adott a termékek lekérdezésekor — a kód a '
          '„Play-hiba" sorban van. Ez a készülék Play-állapotára utal.';
    case PurchaseDiagnosticsVerdict.noProducts:
      return 'A Play egyetlen kért terméket sem adott vissza. Ez azt jelenti, '
          'hogy a Play **nem** kínálja ezeket a termékeket ennek a fióknak '
          'ezen a készüléken (ország, termék-állapot vagy Play-gyorsítótár).';
    case PurchaseDiagnosticsVerdict.partialCatalog:
      return 'A Play a termékek egy részét adta vissza, néhányat nem. A '
          'hiányzó azonosítók lent látszanak — frissítés után általában magától '
          'rendbe jön.';
    case PurchaseDiagnosticsVerdict.catalogReady:
      return 'A Play **mind** a kért terméket visszaadta, árakkal együtt: a '
          'katalógus ezen a készüléken rendben van. Ha a vásárlás mégis '
          'elakad, akkor a hiba a fizetési lépésben van (a Play ablaka), és az '
          'alábbi „legutóbbi vásárlási hiba" kódja mondja meg, pontosan mit.';
  }
}

String _yesNo(bool value) => value ? 'igen' : 'nem';

String _orNone(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? '(nincs)' : text;
}

/// A jelentés sorai — **másolható** szövegként (a tulajdonos elküldheti).
List<String> purchaseDiagnosticsLines(PurchaseDiagnosticsInput input) {
  final verdict = purchaseDiagnosticsVerdict(input);
  final lines = <String>[
    'HUHS vásárlási diagnosztika',
    'verzió: ${_orNone(input.appVersion)}'
        '${input.platform.trim().isEmpty ? '' : ' (${input.platform})'}',
    if (input.accountEmail.trim().isNotEmpty)
      'HUHS-fiók: ${input.accountEmail.trim()}',
    '',
    'Play Billing elérhető: ${_yesNo(input.storeAvailable)}',
    'lekérdezett termék: ${input.queriedIds.length} db',
    'a Play visszaadta: ${input.products.length} db',
    'a Play NEM adta vissza: '
        '${input.notFoundIds.isEmpty ? '(nincs)' : input.notFoundIds.join(', ')}',
    'Play-hiba a lekérdezésben: ${_orNone(input.queryError)}',
  ];

  if (input.products.isNotEmpty) {
    lines.add('');
    lines.add('A Play által visszaadott termékek:');
    for (final product in input.products) {
      lines.add(
        '  • ${product.id} | ${product.price} ${product.currencyCode}'
        '${product.title.trim().isEmpty ? '' : ' | ${product.title.trim()}'}',
      );
    }
  }

  lines.add('');
  lines.add('Legutóbbi vásárlási hiba:');
  if ((input.lastErrorCode ?? '').trim().isEmpty &&
      (input.lastErrorMessage ?? '').trim().isEmpty) {
    lines.add('  (nincs rögzített vásárlási hiba ebben az app-indításban)');
  } else {
    lines.add('  kód: ${_orNone(input.lastErrorCode)}');
    lines.add('  termék: ${_orNone(input.lastErrorProductId)}');
    lines.add('  üzenet: ${_orNone(input.lastErrorMessage)}');
  }

  lines.add('');
  lines.add('ÖSSZEGZÉS: ${purchaseDiagnosticsVerdictText(verdict)}');
  return lines;
}

/// A jelentés egyetlen szövegként (vágólapra másoláshoz).
String purchaseDiagnosticsText(PurchaseDiagnosticsInput input) =>
    purchaseDiagnosticsLines(input).join('\n');
