import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/newsletter_plan.dart';

/// A hírlevél-válasz tiszta feldolgozása.
///
/// A tulajdonos jelzése: *„ugyanazt az email címet bármennyiszer be tudják
/// küldeni és kimegy az ellenőrző mail is"* — a szerver oldali védelem
/// (`includes/newsletter.php`, e-mailenkénti várakozás) adja a választ, és azt
/// itt dolgozzuk fel. Ez a fájl azt méri, hogy a **három sikeres** válaszból a
/// felhasználó a helyes szöveget kapja.
void main() {
  group('newsletterResultFromResponse', () {
    test('az új kérésre kiment a megerősítő e-mail', () {
      final result = newsletterResultFromResponse({
        'subscribed': true,
        'already_requested': false,
        'double_opt_in': true,
        'state': 'confirmation_sent',
      });
      expect(result.outcome, NewsletterOutcome.confirmationSent);
      expect(result.retryAfterSeconds, isNull);
    });

    test('a már feliratkozott cím: nincs mit megerősíteni', () {
      final result = newsletterResultFromResponse({
        'subscribed': true,
        'already_subscribed': true,
        'double_opt_in': false,
        'state': 'subscribed',
      });
      expect(result.outcome, NewsletterOutcome.alreadySubscribed);
    });

    test('a várakozó cím: már kiment, ezért NEM küldjük ki újra', () {
      final result = newsletterResultFromResponse({
        'subscribed': true,
        'already_requested': true,
        'double_opt_in': false,
        'state': 'confirmation_pending',
        'retry_after': 754,
      });
      expect(result.outcome, NewsletterOutcome.confirmationPending);
      expect(result.retryAfterSeconds, 754);
    });

    test('a `state` mező nélküli (régi plugin) válaszból is jó a kimenetel', () {
      expect(
        newsletterResultFromResponse({'already_subscribed': true}).outcome,
        NewsletterOutcome.alreadySubscribed,
      );
      expect(
        newsletterResultFromResponse({
          'already_requested': true,
          'retry_after': 600,
        }).outcome,
        NewsletterOutcome.confirmationPending,
      );
      expect(
        newsletterResultFromResponse({'double_opt_in': true}).outcome,
        NewsletterOutcome.confirmationSent,
      );
    });

    test('üres vagy hiányzó törzs: a kérés sikeres volt, megerősítő levél jön', () {
      expect(
        newsletterResultFromResponse(null).outcome,
        NewsletterOutcome.confirmationSent,
      );
      expect(
        newsletterResultFromResponse(const {}).outcome,
        NewsletterOutcome.confirmationSent,
      );
    });

    test('a hibás `retry_after` nem lesz negatív/ nulla', () {
      for (final value in <Object?>[0, -5, 'abc', '', null, 0.4]) {
        final result = newsletterResultFromResponse({
          'state': 'confirmation_pending',
          'retry_after': value,
        });
        expect(result.retryAfterSeconds, isNull, reason: 'érték: $value');
      }
      expect(
        newsletterResultFromResponse({
          'state': 'confirmation_pending',
          'retry_after': 90.6,
        }).retryAfterSeconds,
        91,
        reason: 'a tört másodperc egészre kerekül',
      );
      expect(
        newsletterResultFromResponse({
          'state': 'confirmation_pending',
          'retry_after': '600',
        }).retryAfterSeconds,
        600,
        reason: 'a szöveges szám is elfogadott',
      );
    });
  });

  group('newsletterMessage', () {
    test('a megerősítő levélre szólító szöveg a postaládára irányít', () {
      final message = newsletterMessage(
        const NewsletterResult(outcome: NewsletterOutcome.confirmationSent),
      );
      expect(message, contains('megerősítő e-mailt'));
      expect(message, contains('spam'));
    });

    test('a már feliratkozott címnél nem ígérünk új levelet', () {
      final message = newsletterMessage(
        const NewsletterResult(outcome: NewsletterOutcome.alreadySubscribed),
      );
      expect(message, contains('már fel van iratkozva'));
      expect(
        message,
        isNot(contains('Elküldtük')),
        reason: 'nem küldtünk semmit, ezt nem is állíthatjuk',
      );
    });

    test('a várakozásnál megmondjuk, mennyit kell várni (felfelé kerekítve)', () {
      final message = newsletterMessage(
        const NewsletterResult(
          outcome: NewsletterOutcome.confirmationPending,
          retryAfterSeconds: 901,
        ),
      );
      expect(message, contains('nem küldtük ki újra'));
      expect(
        message,
        contains('16 perc'),
        reason: '901 másodperc felfelé kerekítve 16 perc',
      );
    });

    test('a várakozás hiányában sem ígérünk 0 percet', () {
      final message = newsletterMessage(
        const NewsletterResult(
          outcome: NewsletterOutcome.confirmationPending,
        ),
      );
      expect(message, contains('1 perc múlva'));
    });
  });
}
