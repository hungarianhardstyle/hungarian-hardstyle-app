import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forrás-lint: a hírlevél-feliratkozás bekötése.
///
/// A tulajdonos jelzése: *„ugyanazt az email címet bármennyiszer be tudják
/// küldeni és kimegy az ellenőrző mail is"*. A védelem **két oldalon** áll:
///  - a szerveren (`includes/newsletter.php`, e-mailenkénti várakozás),
///  - a felületen, amely a szerver háromféle **sikeres** válaszát megkülönbözteti.
/// A tiszta logika tesztje (`newsletter_plan_test.dart`) a feldolgozást fedi;
/// ez a fájl a **bekötést** őrzi (a 351-es tanulság: a szabály lehet helyes, a
/// bekötés hibás).
void main() {
  String readFile(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('forrás-lint: hírlevél-feliratkozás', () {
    late String screen;
    late String service;
    late String voting;

    setUpAll(() {
      screen = readFile('lib/screens/more/newsletter_screen.dart');
      service = readFile('lib/services/wordpress_service.dart');
      voting = readFile('lib/services/voting_service.dart');
    });

    test('a szolgáltatás a tiszta modullal dolgozza fel a választ', () {
      expect(service, contains("import 'newsletter_plan.dart';"));
      expect(service, contains('newsletterResultFromResponse('));
      expect(
        service,
        contains('Future<NewsletterResult> subscribeNewsletter('),
        reason: 'a hívó félnek látnia kell a kimenetelt, nem elég a void',
      );
    });

    test('a képernyő a kimenetelhez tartozó szöveget mutatja', () {
      expect(screen, contains("import '../../services/newsletter_plan.dart';"));
      expect(screen, contains('newsletterMessage(result)'));
      expect(
        screen,
        isNot(contains("'Ellenőrizd az e-mail-fiókodat a megerősítéshez.'")),
        reason: 'a régi, mindig egyforma szöveg nem maradhat bent',
      );
    });

    test('a képernyő csak akkor törli a címet, ha tényleg kiment a levél', () {
      expect(screen, contains('NewsletterOutcome.confirmationSent'));
      expect(
        screen.indexOf('_emailController.clear()'),
        greaterThan(screen.indexOf('result.outcome ==')),
        reason: 'a törlés a kimenetel-ellenőrzés után van',
      );
    });

    test('a szavazás nem veszhet el a hírlevél hibáján', () {
      expect(
        voting,
        contains('await wordpress.subscribeNewsletter('),
        reason: 'a feliratkozás továbbra is megtörténik hozzájárulásnál',
      );
      final callIndex = voting.indexOf('await wordpress.subscribeNewsletter(');
      final tryIndex = voting.lastIndexOf('try {', callIndex);
      expect(
        tryIndex,
        greaterThan(-1),
        reason: 'a hívás try blokkban van (különben a szavazat elszáll)',
      );
      final catchIndex = voting.indexOf('} catch (_) {', callIndex);
      expect(catchIndex, greaterThan(callIndex));
      expect(
        voting.substring(callIndex, catchIndex),
        contains('subscribeNewsletter'),
      );
    });
  });
}
