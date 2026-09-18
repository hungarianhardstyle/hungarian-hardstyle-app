import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/poll.dart';

void main() {
  test('beolvassa a nyitott kerdőívet', () {
    final poll = HuhsPoll.fromJson({
      'id': 42,
      'question': 'Melyik a kedvenc alstilusod?',
      'options': [
        {'index': 0, 'label': 'Rawstyle'},
        {'index': 1, 'label': 'Euphoric'},
      ],
    });

    expect(poll, isNotNull);
    expect(poll!.id, 42);
    expect(poll.question, 'Melyik a kedvenc alstilusod?');
    expect(poll.options.map((option) => option.index), [0, 1]);
    expect(poll.options.first.label, 'Rawstyle');
  });

  test('nincs kerdőív, ha a szerver null-t ad', () {
    // A WordPress csak a beallitott időablakban ad kerdőívet, ezert a null
    // valasz teljesen normalis, nem hiba.
    expect(HuhsPoll.fromJson(null), isNull);
  });

  test('ervénytelen vagy tul kevés valasszal nem indul a szavazas', () {
    // Egy kerdőívhez legalabb ket ertelmes valasz kell; enelkul nincs mit
    // szavazni, es a kartya sem jelenik meg.
    expect(HuhsPoll.fromJson({'id': 1, 'question': 'Kérdés?', 'options': []}), isNull);
    expect(
      HuhsPoll.fromJson({
        'id': 1,
        'question': 'Kérdés?',
        'options': [
          {'index': 0, 'label': 'Csak egy'},
        ],
      }),
      isNull,
    );
    expect(HuhsPoll.fromJson({'id': 0, 'question': 'Kérdés?', 'options': [1, 2]}), isNull);
  });

  test('a rossz formatumu valaszokat kihagyja, nem hasal el', () {
    final poll = HuhsPoll.fromJson({
      'id': 7,
      'question': 'Kérdés?',
      'options': [
        {'index': 0, 'label': 'Jó'},
        {'index': 1, 'label': '   '},
        'nem objektum',
        {'index': 2, 'label': 'Másik jó'},
      ],
    });

    expect(poll, isNotNull);
    expect(poll!.options.map((option) => option.label), ['Jó', 'Másik jó']);
  });
}
