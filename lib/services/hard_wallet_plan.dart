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

/// A szerver által összeállított, aláíratlan HARD-átutalás (`hardPrepareTransfer`).
class HardTransferQuote {
  const HardTransferQuote({
    required this.transaction,
    required this.sender,
    required this.recipient,
    required this.amount,
  });

  /// Aláíratlan tranzakció, base64.
  final String transaction;
  final String sender;
  final String recipient;

  /// Az összeg tizedes szövegként (pl. `1.5`).
  final String amount;

  factory HardTransferQuote.fromMap(Map<Object?, Object?> map) {
    String text(String key) => map[key] is String ? map[key] as String : '';
    final quote = HardTransferQuote(
      transaction: text('transaction'),
      sender: text('sender'),
      recipient: text('recipient'),
      amount: text('amount'),
    );
    if (quote.transaction.isEmpty ||
        quote.sender.isEmpty ||
        quote.recipient.isEmpty) {
      throw const FormatException('Invalid transfer quote');
    }
    return quote;
  }
}

/// Rövidített cím a kijelzéshez: `CzTZ…R5UV`.
String shortAddress(String address) => address.length <= 10
    ? address
    : '${address.substring(0, 4)}…${address.substring(address.length - 4)}';

/// A szerver hibakódjainak érthető magyar üzenete (a szerver üzenete az irányadó,
/// ha van; a kódok csak a tartalék).
String hardWalletErrorMessage(Object error) {
  if (error is HardWalletException) return error.message;
  if (error is FirebaseFunctionsException) {
    // A hálózati 'unavailable' üzenete nyers angol kód ("UNAVAILABLE"): azt nem mutatjuk.
    final message = error.code == 'unavailable' ? null : error.message;
    if (message != null && message.trim().isNotEmpty) return message;
    switch (error.code) {
      case 'permission-denied':
        return 'A HARD-tárca csak 18 éves kortól érhető el.';
      case 'unavailable':
        return 'Nincs kapcsolat a szerverrel, próbáld újra.';
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

/// A tárcaapp után az app a háttérből tér vissza, és a hálózat néhány másodpercig
/// nem elérhető lehet: az 'unavailable' hibát ezért néhányszor újrapróbáljuk.
Future<T> retryOnUnavailable<T>(
  Future<T> Function() call, {
  int attempts = 4,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unavailable' || attempt >= attempts) rethrow;
      await Future<void>.delayed(delay * attempt);
    }
  }
}

/// A [base58Encode] párja: a WalletConnect-tárcák az aláírást base58-ban adják vissza.
Uint8List base58Decode(String text) {
  var zeros = 0;
  while (zeros < text.length && text[zeros] == '1') {
    zeros++;
  }
  final bytes = <int>[];
  for (final char in text.substring(zeros).split('')) {
    final value = _alphabet.indexOf(char);
    if (value < 0) throw const FormatException('Invalid base58 character');
    var carry = value;
    for (var i = 0; i < bytes.length; i++) {
      carry += bytes[i] * 58;
      bytes[i] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.add(carry & 0xff);
      carry >>= 8;
    }
  }
  return Uint8List.fromList([...List.filled(zeros, 0), ...bytes.reversed]);
}
