import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/faq.dart';

/// A GYÍK-válaszok **formázás-szemete** — a tulajdonos jelzése (2026-09-26):
/// *„a help menüben bentmaradtak a formázások mint a /P stb angolul"*.
///
/// **A mért ok (éles `GET /faq?lang=…`):** a magyar válaszok **0/33**-a tartalmaz
/// HTML-t, az angolok viszont **31/33**-a `<p>…</p>` burkolással jön (a gépi
/// fordítás tette bele). A tisztítás a parse-ban történik, ezért itt mérjük —
/// hálózat nélkül, a **valódi** szerver-válaszból vett mintákkal.
void main() {
  group('faqPlainText', () {
    test('a <p> burkolás eltűnik, a bekezdés-határ megmarad', () {
      expect(
        faqPlainText('<p>Első bekezdés.</p><p>Második bekezdés.</p>'),
        'Első bekezdés.\n\nMásodik bekezdés.',
      );
    });

    test('a <br> sortörés lesz, a többi tag kiesik', () {
      expect(
        faqPlainText('Első sor<br>Második sor'),
        'Első sor\nMásodik sor',
      );
      expect(
        faqPlainText('<div><span>Szöveg</span></div>'),
        'Szöveg',
      );
    });

    test('a HTML-entitások feloldódnak', () {
      expect(
        faqPlainText('A &amp; B&nbsp;&nbsp;C &quot;idézet&quot; &#39;aposztróf&#39;'),
        'A & B C "idézet" \'aposztróf\'',
      );
    });

    test('a felesleges üres sorok és szóközök összevonódnak', () {
      expect(faqPlainText('<p>A</p>\n\n\n\n<p>B</p>'), 'A\n\nB');
      expect(faqPlainText('  sok   szóköz  '), 'sok szóköz');
    });

    test('a MAGYAR (sima) szöveg változatlan marad', () {
      const hungarian =
          'Koppints a Regisztrációra, add meg a kért adatokat, majd erősítsd meg '
          'az e-mail-címedet a kapott levélben.';
      expect(faqPlainText(hungarian), hungarian);
    });

    test('a `FaqItem` a tisztított szöveget adja (kérdés ÉS válasz)', () {
      final item = FaqItem.fromJson(const {
        'id': 7,
        'question': '<p>How can I register?</p>',
        'answer': '<p>Tap on Register.</p><p>Then verify your email.</p>',
        'category': 'Getting Started',
        'order': 3,
      });

      expect(item.question, 'How can I register?');
      expect(item.answer, 'Tap on Register.\n\nThen verify your email.');
      expect(item.category, 'Getting Started');
      expect(item.order, 3);
      expect(item.id, 7);
    });
  });
}
