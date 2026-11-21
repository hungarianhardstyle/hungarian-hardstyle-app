import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/hard_wallet_plan.dart';

void main() {
  test('base58: a rendszercím 32 nulla bájt = 32 darab 1-es', () {
    expect(base58Encode(Uint8List(32)), '1' * 32);
  });

  test('base58: ismert cím oda-vissza a szerver-oldali mintával egyezik', () {
    // A devnet-tárca nyilvános kulcsa (32 bájt) és a base58 címe.
    const address = 'CzTZMUrBiUf6qgyMrM4Jg76K9G1fX2sm8tjF8zmUR5UV';
    final bytes = _decode(address);
    expect(bytes.length, 32);
    expect(base58Encode(bytes), address);
  });

  test('állapot: kikapcsolt és nem kötött tárca', () {
    final off = HardWalletStatus.fromMap({'enabled': false, 'linked': false});
    expect(off.enabled, isFalse);
    final linked = HardWalletStatus.fromMap({
      'enabled': true,
      'linked': true,
      'address': 'ABCDEFGHIJKL',
      'amount': '1000',
      'cluster': 'devnet',
    });
    expect(linked.linked, isTrue);
    expect(linked.amount, '1000');
  });

  test('cím rövidítése', () {
    expect(shortAddress('CzTZMUrBiUf6qgyMrM4Jg76K9G1fX2sm8tjF8zmUR5UV'), 'CzTZ…R5UV');
    expect(shortAddress('rövid'), 'rövid');
  });

  test('hibaüzenet: a saját kivétel üzenete marad, ismeretlen hiba általános', () {
    expect(hardWalletErrorMessage(const HardWalletException('X')), 'X');
    expect(hardWalletErrorMessage(Exception('titok')), isNot(contains('titok')));
  });
}

// Teszt-segéd: base58 dekódolás (csak az oda-vissza ellenőrzéshez).
Uint8List _decode(String s) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  var value = BigInt.zero;
  for (final c in s.split('')) {
    value = value * BigInt.from(58) + BigInt.from(alphabet.indexOf(c));
  }
  final out = <int>[];
  while (value > BigInt.zero) {
    out.insert(0, (value & BigInt.from(255)).toInt());
    value >>= 8;
  }
  final zeros = s.length - s.replaceFirst(RegExp('^1+'), '').length;
  return Uint8List.fromList([...List.filled(zeros, 0), ...out]);
}
