import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/prize.dart';

/// Az ÉLES szerver válasza (2026-09-18, a lezárt teszjáték után), szó szerint.
///
/// Ez azért lényeges, mert a plugin akkor még a 2.5.0 volt, ezért az `image`
/// mező MÉG benne van a válaszban — a kliens modellnek ezt el kell viselnie
/// (az ismeretlen mezőket egyszerűen figyelmen kívül hagyja), és a lényeget,
/// a `state: "drawn"` + `winner` párost fel kell ismernie.
const _liveDrawnPayload = {
  'id': 12709,
  'state': 'drawn',
  'question': 'Nem nyersz semmit ez csak teszt',
  'answers': <Object>[],
  'start': '2026-09-18T22:11',
  'end': '2026-09-18T22:17',
  'image':
      'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiMDvVOb05B0op6A2EtmiX9jPWVfYhuv1H3i2EdYx3NyX5zmOb1hKf1-fdAWDquCpfA8uSHt7dcQqomk0kktHAChG4loygmUGijVdpMjOIJvIm15HPVng_WTWDCg8vEJ-Lj5zit9hQ1v4rB/s1600/jatek.gif',
  'prize_type': 'Semmit nem nyersz',
  'prize_description': 'Ez cxsak teszt',
  'winner': {'name': 'Denoiser', 'drawn_at': '2026-09-18 20:19:04'},
};

void main() {
  test('az ELES lezart jatek valaszabol felismeri a nyertest', () {
    final prize = HuhsPrize.fromJson(_liveDrawnPayload);

    expect(prize, isNotNull, reason: 'a drawn allapotot fel kell ismerni');
    expect(prize!.isOpen, isFalse);
    expect(prize.id, 12709);
    expect(prize.question, 'Nem nyersz semmit ez csak teszt');
    expect(prize.winner, isNotNull);
    expect(prize.winner!.name, 'Denoiser');
    expect(prize.winner!.drawnAt, '2026-09-18 20:19:04');
    expect(prize.prizeType, 'Semmit nem nyersz');
    expect(prize.prizeDescription, 'Ez cxsak teszt');
    expect(prize.answers, isEmpty);
  });

  test('a megmaradt image mezo nem töri el a feldolgozast', () {
    // A 2.5.0-s plugin meg kiadja az `image` mezot, a kliens viszont mar nem
    // ismeri. Egy ismeretlen kulcs nem akadalyozhatja meg a nyertes kijelzeset.
    final withoutImage = Map<String, dynamic>.from(_liveDrawnPayload)
      ..remove('image');
    final withImage = HuhsPrize.fromJson(_liveDrawnPayload);
    final clean = HuhsPrize.fromJson(withoutImage);

    expect(withImage?.winner?.name, clean?.winner?.name);
    expect(withImage?.state, clean?.state);
  });
}
