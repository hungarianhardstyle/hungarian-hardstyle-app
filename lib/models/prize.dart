/// Nyeremenyjatek — a kviz modellje.
///
/// A kerdes, a valaszlehetosegek es az időablak a WordPress-bol erkezik, a
/// helyes valaszt viszont az app **soha** nem latja a jatek lezarasa elott: a
/// szerver dönt a helyessegrol, es csak a sajat valaszunkrol mondja meg, hogy
/// helyes volt-e.
///
/// A modell ket allapotot ismer:
///  * [HuhsPrizeState.open] — lehet jatszani (kerdes + valaszlehetosegek);
///  * [HuhsPrizeState.drawn] — lezarult, es a nyertes a megjelenitesi ablakban
///    van (a kerdes es a valaszok ilyenkor mar NEM jonnek le).
class HuhsPrizeAnswer {
  const HuhsPrizeAnswer({required this.index, required this.label});

  /// A valasz indexe a szerver listajaban; ezt kuldjuk vissza jatekkozkor.
  final int index;
  final String label;

  factory HuhsPrizeAnswer.fromJson(Map<String, dynamic> json) {
    return HuhsPrizeAnswer(
      index: int.tryParse('${json['index']}') ?? 0,
      label: (json['label'] ?? '').toString().trim(),
    );
  }
}

/// A kihirdetett nyertes.
class HuhsPrizeWinner {
  const HuhsPrizeWinner({required this.name, required this.drawnAt});

  final String name;
  final String drawnAt;

  static HuhsPrizeWinner? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = (json['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    return HuhsPrizeWinner(
      name: name,
      drawnAt: (json['drawn_at'] ?? '').toString().trim(),
    );
  }
}

enum HuhsPrizeState { open, drawn }

class HuhsPrize {
  const HuhsPrize({
    required this.id,
    required this.state,
    required this.question,
    required this.answers,
    required this.prizeType,
    required this.prizeDescription,
    required this.imageUrl,
    required this.winner,
  });

  final int id;
  final HuhsPrizeState state;
  final String question;

  /// Csak nyitott jateknal van kitoltve; a nyertes kihirdetese utan ures.
  final List<HuhsPrizeAnswer> answers;

  /// A nyeremeny reszletei. A jatek elott szandekosan uresek: a kartya addig
  /// csak annyit mond, hogy „Nyereményjáték".
  final String prizeType;
  final String prizeDescription;

  /// Opcionalis kep a nyeremenyjatek kartyajahoz.
  final String imageUrl;

  /// Csak [HuhsPrizeState.drawn] eseten van kitoltve.
  final HuhsPrizeWinner? winner;

  bool get isOpen => state == HuhsPrizeState.open;

  /// Null, ha nincs aktiv/lezart jatek, vagy ha a valasz ertelmezhetetlen.
  static HuhsPrize? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = int.tryParse('${json['id']}') ?? 0;
    if (id <= 0) return null;
    final rawState = (json['state'] ?? '').toString().trim().toLowerCase();
    final state = switch (rawState) {
      'open' => HuhsPrizeState.open,
      'drawn' => HuhsPrizeState.drawn,
      _ => null,
    };
    if (state == null) return null;

    final rawAnswers = json['answers'];
    final answers = rawAnswers is List
        ? rawAnswers
              .whereType<Map>()
              .map((item) => HuhsPrizeAnswer.fromJson(Map<String, dynamic>.from(item)))
              .where((answer) => answer.label.isNotEmpty)
              .toList(growable: false)
        : const <HuhsPrizeAnswer>[];
    final winner = HuhsPrizeWinner.fromJson(json['winner']);

    // Nyitott jatek valaszlehetosegek nelkul ertelmezhetetlen; kihirdetett
    // nyertes nelkul szinten (ilyenkor nincs mit mutatni).
    if (state == HuhsPrizeState.open && answers.length < 2) return null;
    if (state == HuhsPrizeState.drawn && winner == null) return null;

    return HuhsPrize(
      id: id,
      state: state,
      question: (json['question'] ?? '').toString().trim(),
      answers: answers,
      prizeType: (json['prize_type'] ?? '').toString().trim(),
      prizeDescription: (json['prize_description'] ?? '').toString().trim(),
      imageUrl: (json['image'] ?? '').toString().trim(),
      winner: winner,
    );
  }
}

/// Ez a fiok jatszott-e mar, es ha igen, helyes volt-e a valasza.
///
/// A jatekszabaly szerint egy fiok EGYSZER jatszik: ha ront, nincs javitas es
/// nincs ujraproba. Ezt a szerver zarja le, a modell csak visszajelzi.
class HuhsPrizePlay {
  const HuhsPrizePlay({
    required this.played,
    required this.correct,
    this.answerIndex,
  });

  final bool played;
  final bool correct;
  final int? answerIndex;

  static HuhsPrizePlay fromJson(Map<String, dynamic> json) {
    return HuhsPrizePlay(
      played: json['played'] == true,
      correct: json['correct'] == true,
      answerIndex: int.tryParse('${json['answerIndex']}'),
    );
  }

  /// A jatek beirasanak eredmenye (a szerver valasza).
  static HuhsPrizePlay fromEntryResult(Map<String, dynamic> json) {
    return HuhsPrizePlay(
      played: true,
      correct: json['correct'] == true,
      answerIndex: int.tryParse('${json['answerIndex']}'),
    );
  }
}
