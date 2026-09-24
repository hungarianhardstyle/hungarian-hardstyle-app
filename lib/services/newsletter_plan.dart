/// A hírlevél-feliratkozás **válaszának tiszta** feldolgozása.
///
/// Miért külön modul: a szerver három különböző, **mind sikeres** választ adhat
/// ugyanarra a kérésre, és a felhasználónak nem ugyanazt kell látnia:
///  1. **kiment a megerősítő e-mail** (új, vagy lejárt a várakozás),
///  2. **ez a cím már fel van iratkozva** — nincs mit megerősíteni,
///  3. **erre a címre már kiment a megerősítő e-mail** — szándékosan nem
///     küldtük ki újra (ez a spam-elleni védelem a szerveren).
/// A régi szerver (2.9.0) nem küld `state` mezőt, ezért a hiányzó/üres válasz
/// az 1. eset — így a frissítés előtti pluginnal is helyes a szöveg.
library;

/// A feliratkozás kimenetele a felhasználó szempontjából.
enum NewsletterOutcome {
  /// Kiment (vagy kimegy) a megerősítő e-mail.
  confirmationSent,

  /// A cím már megerősített feliratkozó.
  alreadySubscribed,

  /// Már kiment a megerősítő e-mail, ezért most nem küldtük ki újra.
  confirmationPending,
}

/// A feldolgozott válasz: a kimenetel és — várakozás esetén — a hátralévő idő.
class NewsletterResult {
  const NewsletterResult({required this.outcome, this.retryAfterSeconds});

  final NewsletterOutcome outcome;

  /// Mennyi idő múlva érdemes újra próbálni (másodperc). Csak a
  /// [NewsletterOutcome.confirmationPending] esetben értelmezett.
  final int? retryAfterSeconds;

  @override
  bool operator ==(Object other) =>
      other is NewsletterResult &&
      other.outcome == outcome &&
      other.retryAfterSeconds == retryAfterSeconds;

  @override
  int get hashCode => Object.hash(outcome, retryAfterSeconds);

  @override
  String toString() =>
      'NewsletterResult(${outcome.name}, retryAfter: $retryAfterSeconds)';
}

/// A szerver válaszából kiolvasott eredmény.
///
/// [data] hiányában (üres törzs, régi plugin) a biztonságos alapérték az
/// „elküldtük a megerősítő e-mailt”, mert a kérés 2xx-szel tért vissza.
NewsletterResult newsletterResultFromResponse(Map<String, dynamic>? data) {
  if (data == null) {
    return const NewsletterResult(
      outcome: NewsletterOutcome.confirmationSent,
    );
  }

  final retryAfter = _positiveSeconds(data['retry_after']);
  final state = data['state'];
  if (state is String) {
    switch (state.trim()) {
      case 'subscribed':
        return const NewsletterResult(
          outcome: NewsletterOutcome.alreadySubscribed,
        );
      case 'confirmation_pending':
        return NewsletterResult(
          outcome: NewsletterOutcome.confirmationPending,
          retryAfterSeconds: retryAfter,
        );
      case 'confirmation_sent':
        return const NewsletterResult(
          outcome: NewsletterOutcome.confirmationSent,
        );
    }
  }

  // Régi plugin: csak a logikai mezők vannak meg.
  if (data['already_subscribed'] == true) {
    return const NewsletterResult(
      outcome: NewsletterOutcome.alreadySubscribed,
    );
  }
  if (data['already_requested'] == true) {
    return NewsletterResult(
      outcome: NewsletterOutcome.confirmationPending,
      retryAfterSeconds: retryAfter,
    );
  }
  return const NewsletterResult(outcome: NewsletterOutcome.confirmationSent);
}

/// A felhasználónak mutatott magyar szöveg.
String newsletterMessage(NewsletterResult result) {
  switch (result.outcome) {
    case NewsletterOutcome.confirmationSent:
      return 'Elküldtük a megerősítő e-mailt — nézd meg a postaládádat '
          '(a spam mappát is), és kattints a benne lévő linkre.';
    case NewsletterOutcome.alreadySubscribed:
      return 'Ez az e-mail-cím már fel van iratkozva a hírlevélre, '
          'nem kell újra megerősíteni.';
    case NewsletterOutcome.confirmationPending:
      return 'Erre a címre már kiment a megerősítő e-mail, ezért most nem '
          'küldtük ki újra. Nézd meg a postaládádat (a spam mappát is); '
          'ha nem találod, ${_retryHint(result.retryAfterSeconds)}';
  }
}

/// „körülbelül 15 perc múlva próbáld újra.” — a másodpercekből felfelé
/// kerekített percek, legalább 1.
String _retryHint(int? seconds) {
  final safe = seconds == null || seconds <= 0 ? 60 : seconds;
  final minutes = (safe / 60).ceil();
  return 'körülbelül $minutes perc múlva próbáld újra.';
}

int? _positiveSeconds(Object? value) {
  if (value is int) return value > 0 ? value : null;
  if (value is num) {
    final rounded = value.round();
    return rounded > 0 ? rounded : null;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}
