import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

const _alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Solana-cím: a 32 bájtos nyilvános kulcs base58-kódolása (a tárcától jön).
String base58Encode(Uint8List bytes) {
  var zeros = 0;
  while (zeros < bytes.length && bytes[zeros] == 0) {
    zeros++;
  }
  final digits = <int>[];
  for (final byte in bytes.skip(zeros)) {
    var carry = byte;
    for (var i = 0; i < digits.length; i++) {
      carry += digits[i] << 8;
      digits[i] = carry % 58;
      carry ~/= 58;
    }
    while (carry > 0) {
      digits.add(carry % 58);
      carry ~/= 58;
    }
  }
  return '1' * zeros + digits.reversed.map((d) => _alphabet[d]).join();
}

/// A HARD-tárca állapota a `hardGetBalance` válaszából.
class HardWalletStatus {
  const HardWalletStatus({
    required this.enabled,
    required this.linked,
    this.address,
    this.amount,
    this.cluster,
  });

  final bool enabled;
  final bool linked;
  final String? address;
  final String? amount;
  final String? cluster;

  factory HardWalletStatus.fromMap(Map<Object?, Object?> map) {
    return HardWalletStatus(
      enabled: map['enabled'] == true,
      linked: map['linked'] == true,
      address: map['address'] as String?,
      amount: map['amount'] as String?,
      cluster: map['cluster'] as String?,
    );
  }
}

/// Rövidített cím a kijelzéshez: `CzTZ…R5UV`.
String shortAddress(String address) =>
    address.length <= 10 ? address : '${address.substring(0, 4)}…${address.substring(address.length - 4)}';

/// A szerver hibakódjainak érthető magyar üzenete (a szerver üzenete az irányadó,
/// ha van; a kódok csak a tartalék).
String hardWalletErrorMessage(Object error) {
  if (error is HardWalletException) return error.message;
  if (error is FirebaseFunctionsException) {
    final message = error.message;
    if (message != null && message.trim().isNotEmpty) return message;
    switch (error.code) {
      case 'permission-denied':
        return 'A HARD-tárca csak 18 éves kortól érhető el.';
      case 'unavailable':
        return 'Az egyenleg most nem kérdezhető le, próbáld újra később.';
      case 'resource-exhausted':
        return 'Túl sok próbálkozás, várj egy percet.';
    }
  }
  return 'Nem sikerült, próbáld újra később.';
}

class HardWalletException implements Exception {
  const HardWalletException(this.message);
  final String message;
  @override
  String toString() => message;
}
