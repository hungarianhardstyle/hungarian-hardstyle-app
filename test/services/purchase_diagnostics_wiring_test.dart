import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A vásárlási diagnosztika **bekötésének** bizonyítása (forrás-lint).
///
/// MIÉRT: a 2026-09-22-i ország-hibánál a valódi baj az volt, hogy **nem láttuk**,
/// mit válaszol a Play. Ha a diagnosztika bekötése csendben eltűnik (egy
/// refaktor, egy képernyő-átírás), akkor visszakerülünk a találgatásba — és azt
/// nem venné észre egyetlen futásidejű teszt sem. Ezért ezt **forrásból** mérjük,
/// a szolgáltatás és a képernyő szövegéből.
///
/// ⚠️ A kommenteket kiszűrjük: a fejléc szándékosan **idézi** a hibás mintákat,
/// és a magyarázó szövegekben szerepelhetnek olyan szavak, amiket tiltunk.
void main() {
  String codeOnly(String source) {
    final withoutBlocks = source.replaceAll(
      RegExp(r'/\*[\s\S]*?\*/', multiLine: true),
      '',
    );
    return withoutBlocks
        .split('\n')
        .map((line) {
          final index = line.indexOf('//');
          return index >= 0 ? line.substring(0, index) : line;
        })
        .join('\n');
  }

  String readFile(String relativePath) {
    final file = File(relativePath);
    expect(file.existsSync(), isTrue, reason: '$relativePath létezik');
    // A fájlok CRLF-fel vannak a lemezen, ezért normalizáljuk a sorvéget.
    return file.readAsStringSync().replaceAll('\r\n', '\n');
  }

  String slice(String source, String from, String to) {
    final start = source.indexOf(from);
    expect(start, greaterThanOrEqualTo(0), reason: 'megvan: $from');
    final end = source.indexOf(to, start);
    expect(end, greaterThan(start), reason: 'megvan utána: $to');
    return source.substring(start, end);
  }

  test('FORRÁS-LINT: a szolgáltatás rögzíti a Play NYERS hibakódját', () {
    final service = codeOnly(
      readFile('lib/services/label_purchase_service.dart'),
    );

    expect(service, contains('lastPurchaseErrorCode'));
    expect(service, contains('lastPurchaseErrorMessage'));
    expect(service, contains('lastPurchaseErrorProductId'));

    // A rögzítés a valódi purchase-streamben történik (nem egy külön ágban).
    final listenBody = slice(
      service,
      'void listen()',
      'Future<bool> completePurchase(',
    );
    expect(
      listenBody,
      contains('_recordPurchaseError(purchase)'),
      reason: 'a hibát a purchase-streamből mentjük',
    );

    final recordBody = slice(
      service,
      'void _recordPurchaseError(',
      'Future<PurchaseDiagnosticsInput> diagnose(',
    );
    expect(recordBody, contains('PurchaseStatus.error'));
    expect(
      recordBody,
      contains('purchase.error?.code'),
      reason: 'a nyers kód kell, nem egy saját üzenet',
    );
  });

  test('FORRÁS-LINT: a diagnosztika friss Play-választ kér, és NEM vásárol', () {
    final service = codeOnly(
      readFile('lib/services/label_purchase_service.dart'),
    );
    final diagnoseBody = slice(
      service,
      'Future<PurchaseDiagnosticsInput> diagnose(',
      'Future<bool> buy(',
    );

    expect(diagnoseBody, contains('_store.queryProductDetails('));
    expect(
      diagnoseBody,
      isNot(contains('buyNonConsumable')),
      reason: 'a diagnosztika SOHA nem indít vásárlást',
    );
    expect(
      diagnoseBody,
      isNot(contains('_catalogCache')),
      reason: 'a gyorsítótár megkerülése a lényeg: a friss választ kérjük',
    );
    expect(
      diagnoseBody,
      contains('notFoundIds'),
      reason: 'azt is jelentjük, amit a Play NEM adott vissza',
    );
  });

  test('FORRÁS-LINT: az „Az appról" képernyőn megvan a diagnosztika', () {
    final screen = codeOnly(readFile('lib/screens/more/about_screen.dart'));

    expect(screen, contains('Vásárlási diagnosztika'));
    expect(screen, contains('_PurchaseDiagnostics'));
    expect(screen, contains('LabelPurchaseService.shared.diagnose('));
    expect(
      screen,
      contains('purchaseDiagnosticsText('),
      reason: 'a jelentés másolható szövegként készül',
    );
    expect(
      screen,
      contains('Clipboard.setData'),
      reason: 'a jelentést el kell tudni küldeni (vágólap)',
    );
    expect(
      screen,
      contains('releasesProvider'),
      reason: 'a termék-azonosítók a kiadvány-katalógusból jönnek',
    );
  });

  test('FORRÁS-LINT: a diagnosztika a tiszta modulból kapja a szöveget', () {
    final screen = codeOnly(readFile('lib/screens/more/about_screen.dart'));
    expect(
      screen,
      contains('purchaseDiagnosticsVerdictText('),
      reason: 'a verdikt magyarázata a tiszta modulban él',
    );
    expect(
      screen,
      isNot(contains('Play-hiba a lekérdezésben')),
      reason: 'a jelentés szövege NE a képernyőn legyen (egy helyen éljen)',
    );
  });
}
