import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/purchase_diagnostics_plan.dart';

/// A vásárlási diagnosztika bizonyítása.
///
/// MIÉRT: a 2026-09-22-i ország-hibánál („A tétel nem áll rendelkezésre az adott
/// országban") **több körön át nem láttuk**, mit válaszol a Play Billing az adott
/// készüléken — emiatt csak következtetni lehetett. A diagnosztika értéke az,
/// hogy a **nyers hibakódot** és a visszaadott termékek számát kiírja, ezért a
/// teszt pont ezeket rögzíti: a jelentés **nem szépítheti el** a kódot, és a
/// verdikt nem mondhat „rendben"-t, ha nem jött vissza termék.
void main() {
  PurchaseDiagnosticsInput input({
    bool storeAvailable = true,
    List<String> queriedIds = const ['huhs_release_12466_extended_mp3_320'],
    List<PurchaseDiagnosticProduct> products = const [],
    List<String> notFoundIds = const [],
    String? queryError,
    String? lastErrorCode,
    String? lastErrorMessage,
    String? lastErrorProductId,
    String platform = 'Android',
    String appVersion = '1.0.0+352',
    String accountEmail = 'teszt@example.com',
  }) {
    return PurchaseDiagnosticsInput(
      storeAvailable: storeAvailable,
      queriedIds: queriedIds,
      products: products,
      notFoundIds: notFoundIds,
      queryError: queryError,
      lastErrorCode: lastErrorCode,
      lastErrorMessage: lastErrorMessage,
      lastErrorProductId: lastErrorProductId,
      platform: platform,
      appVersion: appVersion,
      accountEmail: accountEmail,
    );
  }

  PurchaseDiagnosticProduct product({
    String id = 'huhs_release_12466_extended_mp3_320',
    String title = 'Goze - TikaTika',
    String price = '550,00 Ft',
    String currencyCode = 'HUF',
  }) {
    return PurchaseDiagnosticProduct(
      id: id,
      title: title,
      price: price,
      currencyCode: currencyCode,
    );
  }

  test('a Play Billing hiánya a legerősebb verdikt (nem lehet „rendben")', () {
    final verdict = purchaseDiagnosticsVerdict(
      input(storeAvailable: false, products: const []),
    );
    expect(verdict, PurchaseDiagnosticsVerdict.storeUnavailable);
    expect(
      purchaseDiagnosticsVerdictText(verdict),
      contains('frissítsd'),
      reason: 'a szöveg megmondja, mit kell tenni',
    );
  });

  test('a lekérdezés hibája és az üres válasz KÜLÖN verdikt', () {
    expect(
      purchaseDiagnosticsVerdict(input(queryError: 'BillingClient: error 5')),
      PurchaseDiagnosticsVerdict.queryFailed,
    );
    expect(
      purchaseDiagnosticsVerdict(input()),
      PurchaseDiagnosticsVerdict.noProducts,
    );
  });

  test('a részleges katalógus is eltérés (nem „rendben")', () {
    expect(
      purchaseDiagnosticsVerdict(
        input(
          products: [product()],
          notFoundIds: const ['huhs_release_12466_extended_wav'],
        ),
      ),
      PurchaseDiagnosticsVerdict.partialCatalog,
    );
  });

  test('csak akkor „rendben", ha MINDEN kért termék visszajött', () {
    expect(
      purchaseDiagnosticsVerdict(input(products: [product()])),
      PurchaseDiagnosticsVerdict.catalogReady,
    );
  });

  test('a NYERS hibakód és a Play üzenete benne van a jelentésben', () {
    // ⚠️ EZ A LÉNYEG: enélkül a diagnosztika sem érne semmit.
    final lines = purchaseDiagnosticsLines(
      input(
        products: [product()],
        lastErrorCode: 'itemUnavailable',
        lastErrorMessage: 'Ez a tétel nem áll rendelkezésedre az országodban',
        lastErrorProductId: 'huhs_release_12466_extended_mp3_320',
      ),
    ).join('\n');

    expect(lines, contains('itemUnavailable'));
    expect(lines, contains('Ez a tétel nem áll rendelkezésedre az országodban'));
    expect(lines, contains('huhs_release_12466_extended_mp3_320'));
  });

  test('a jelentés kiírja, hány terméket adott vissza a Play', () {
    final lines = purchaseDiagnosticsLines(
      input(
        queriedIds: const ['a', 'b'],
        products: [product()],
        notFoundIds: const ['b'],
      ),
    );
    expect(lines, contains('lekérdezett termék: 2 db'));
    expect(lines, contains('a Play visszaadta: 1 db'));
    expect(lines, contains('a Play NEM adta vissza: b'));
  });

  test('a visszaadott termék ára és pénzneme is látszik (forint vagy euró)', () {
    // ⚠️ Ez azért fontos, mert a Play az **országot** a pénznemben is elárulja:
    // ha a táblán euró jelenik meg, akkor a Play más országba teszi a fiókot.
    final forint = purchaseDiagnosticsLines(
      input(products: [product()]),
    ).join('\n');
    expect(forint, contains('550,00 Ft'));
    expect(forint, contains('HUF'));

    final euro = purchaseDiagnosticsLines(
      input(
        products: [
          product(price: '1,49 €', currencyCode: 'EUR'),
        ],
      ),
    ).join('\n');
    expect(euro, contains('1,49 €'));
    expect(euro, contains('EUR'));
  });

  test('vásárlási hiba nélkül is érthető a jelentés (nem hazudik mérést)', () {
    final lines = purchaseDiagnosticsLines(
      input(products: [product()]),
    ).join('\n');
    expect(lines, contains('nincs rögzített vásárlási hiba'));
    expect(lines, contains('katalógus ezen a készüléken rendben van'));
  });

  test('a hiányzó adatok helyére „(nincs)" kerül (nem üres a jelentés)', () {
    final lines = purchaseDiagnosticsLines(
      input(
        appVersion: '',
        platform: '',
        accountEmail: '',
        queriedIds: const [],
      ),
    ).join('\n');
    expect(lines, contains('verzió: (nincs)'));
    expect(
      lines.contains('HUHS-fiók'),
      isFalse,
      reason: 'üres fióknál nem írunk sort',
    );
    expect(lines, contains('Play-hiba a lekérdezésben: (nincs)'));
  });

  test('a másolható szöveg a sorok összefűzése (egyetlen blokk)', () {
    final value = input(products: [product()]);
    expect(
      purchaseDiagnosticsText(value),
      purchaseDiagnosticsLines(value).join('\n'),
    );
    expect(purchaseDiagnosticsText(value), contains('ÖSSZEGZÉS:'));
  });

  test('a termék címkéje üres címnél csak az ár', () {
    expect(
      product(title: '   ').label,
      '550,00 Ft',
    );
    expect(product(title: 'Cím').label, 'Cím — 550,00 Ft');
  });
}
