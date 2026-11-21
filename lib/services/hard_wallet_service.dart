import 'dart:convert';
import 'dart:typed_data';

import 'package:solana_mobile_client/solana_mobile_client.dart';

import '../core/firebase/firebase_callable.dart';
import 'hard_wallet_plan.dart';

/// HARD-tárca: a tárcaapp csak aláír (nem tranzakció), minden döntést a szerver hoz.
class HardWalletService {
  const HardWalletService();

  Future<HardWalletStatus> status() async {
    final result = await callFirebaseCallable<Map<Object?, Object?>>(
      'hardGetBalance',
    );
    return HardWalletStatus.fromMap(result.data);
  }

  Future<void> disconnect() =>
      callFirebaseCallable<Object?>('hardWalletDisconnect');

  /// A szerver összeállítja az aláíratlan átutalást (a címzett címét is ő oldja
  /// fel); az aláírás és a beküldés a feladó tárcájában történik.
  Future<HardTransferQuote> prepareTransfer({
    required String recipientUid,
    required String amount,
  }) async {
    final result = await callFirebaseCallable<Map<Object?, Object?>>(
      'hardPrepareTransfer',
      parameters: {'recipientUid': recipientUid, 'amount': amount},
    );
    return HardTransferQuote.fromMap(result.data);
  }

  /// Aláírás és beküldés a Solana Mobile Wallet Adapterrel (Phantom, Solflare).
  /// Visszaadja a tranzakció aláírását (base58).
  Future<String> sendTransfer(HardTransferQuote quote) async {
    if (!await LocalAssociationScenario.isAvailable()) {
      throw const HardWalletException(
        'Nincs telepítve Solana-tárca az eszközön (például Phantom vagy Solflare).',
      );
    }
    final session = await LocalAssociationScenario.create();
    try {
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      final auth = await client.authorize(
        identityUri: Uri.parse('https://hungarianhardstyle.hu'),
        iconUri: Uri.parse('favicon.ico'),
        identityName: 'Hungarian Hardstyle',
        cluster: 'devnet',
      );
      if (auth == null) {
        throw const HardWalletException(
          'A tárca nem engedélyezte a kapcsolódást.',
        );
      }
      if (base58Encode(auth.publicKey) != quote.sender) {
        throw const HardWalletException(
          'Ez nem az összekötött tárca. Válaszd ki azt a tárcát, amelyet a fiókodhoz kötöttél.',
        );
      }
      final sent = await client.signAndSendTransactions(
        transactions: [base64.decode(quote.transaction)],
      );
      if (sent.signatures.isEmpty) {
        throw const HardWalletException(
          'Az átutalás megszakadt vagy elutasítva.',
        );
      }
      return base58Encode(sent.signatures.first);
    } finally {
      await session.close();
    }
  }

  /// Tárca kiválasztása → cím → szerver-kihívás → aláírás a tárcával → szerver-ellenőrzés.
  Future<void> connect() async {
    if (!await LocalAssociationScenario.isAvailable()) {
      throw const HardWalletException(
        'Nincs telepítve Solana-tárca az eszközön (például Phantom vagy Solflare).',
      );
    }
    final session = await LocalAssociationScenario.create();
    try {
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      final auth = await client.authorize(
        identityUri: Uri.parse('https://hungarianhardstyle.hu'),
        iconUri: Uri.parse('favicon.ico'),
        identityName: 'Hungarian Hardstyle',
        cluster: 'devnet',
      );
      if (auth == null) {
        throw const HardWalletException(
          'A tárca nem engedélyezte a kapcsolódást.',
        );
      }
      final address = base58Encode(auth.publicKey);
      final challenge = await callFirebaseCallable<Map<Object?, Object?>>(
        'hardWalletChallenge',
        parameters: {'address': address},
      );
      final message = challenge.data['message'] as String;
      final signed = await client.signMessages(
        messages: [Uint8List.fromList(utf8.encode(message))],
        addresses: [auth.publicKey],
      );
      final signatures = signed.signedMessages.isEmpty
          ? <Uint8List>[]
          : signed.signedMessages.first.signatures;
      if (signatures.isEmpty) {
        throw const HardWalletException(
          'Az aláírás megszakadt vagy elutasítva.',
        );
      }
      await retryOnUnavailable(
        () => callFirebaseCallable<Object?>(
          'hardWalletVerify',
          parameters: {
            'challengeId': challenge.data['challengeId'],
            'signature': base64.encode(signatures.first),
          },
        ),
      );
    } finally {
      await session.close();
    }
  }
}
