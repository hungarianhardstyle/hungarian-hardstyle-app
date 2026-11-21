import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../core/firebase/firebase_callable.dart';
import 'hard_wallet_plan.dart';

/// Nem-nyilvános kulcs: a Reown (WalletConnect) projektazonosító az appban úgyis látszik.
const reownProjectId = String.fromEnvironment(
  'HUHS_REOWN_PROJECT_ID',
  defaultValue: '8988baf790c5c00d51449eab377dd06f',
);

const _solanaDevnet = 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1';

/// Bármely WalletConnect-tárca (Trust, Backpack, Bitget, OKX stb.): a tárcaválasztót
/// a Reown adja, az app csak a szokásos kihívást írja alá — a szerver-ellenőrzés
/// ugyanaz, mint az MWA-s (Solflare/Phantom) útnál.
class HardWalletConnect {
  const HardWalletConnect();

  /// A tárcaválasztó modal, csak a Solana devnetre szűkítve (a HARD jelenleg
  /// devneten van, más lánc nem kell).
  ReownAppKitModal _createModal(BuildContext context, String description) {
    for (final namespace
        in ReownAppKitModalNetworks.getAllSupportedNamespaces()) {
      if (namespace != 'solana') {
        ReownAppKitModalNetworks.removeSupportedNetworks(namespace);
      }
    }
    ReownAppKitModalNetworks.removeSupportedNetworks(
      'solana',
      chainIds: [
        for (final n in ReownAppKitModalNetworks.getAllSupportedNetworks(
          namespace: 'solana',
        ))
          // A tárolt azonosító előtag nélküli, a lista előtaggal adja vissza.
          if (n.chainId.split(':').last != _solanaDevnet)
            n.chainId.split(':').last,
      ],
    );
    return ReownAppKitModal(
      context: context,
      projectId: reownProjectId,
      metadata: PairingMetadata(
        name: 'Hungarian Hardstyle',
        description: description,
        url: 'https://hungarianhardstyle.hu',
        icons: const ['https://hardtoken.hungarianhardstyle.hu/logo.png'],
      ),
      disconnectOnDispose: false,
    );
  }

  /// Megnyitja a tárcaválasztót, és visszaadja a kapcsolt tárca (Solana) címét.
  Future<(ReownAppKitModalSession, String)> _open(
    BuildContext context,
    ReownAppKitModal modal,
  ) async {
    await modal.init();
    await modal.selectChain(
      ReownAppKitModalNetworks.getNetworkInfo('solana', _solanaDevnet),
    );
    if (!context.mounted) {
      throw const HardWalletException('A tárca nem kapcsolódott.');
    }
    await modal.openModalView();
    final session = modal.session;
    final address = session?.getAddress('solana');
    if (session == null || address == null) {
      throw const HardWalletException('A tárca nem kapcsolódott.');
    }
    return (session, address);
  }

  /// A kapcsolat csak a műveletig kell: nem hagyunk nyitott munkamenetet.
  Future<void> _close(ReownAppKitModal modal) async {
    try {
      await modal.disconnect();
    } catch (_) {}
    await modal.dispose();
  }

  Future<void> connect(BuildContext context) async {
    final modal = _createModal(
      context,
      'HARD-tárca összekapcsolása (csak aláírás)',
    );
    try {
      final (session, address) = await _open(context, modal);
      final challenge = await callFirebaseCallable<Map<Object?, Object?>>(
        'hardWalletChallenge',
        parameters: {'address': address},
      );
      final message = challenge.data['message'] as String;
      final result = await modal.request(
        topic: session.topic,
        chainId: 'solana:$_solanaDevnet',
        request: SessionRequestParams(
          method: 'solana_signMessage',
          // A WalletConnect-szabvány szerint az üzenet base58-kódolt UTF-8.
          params: {
            'pubkey': address,
            'message': base58Encode(Uint8List.fromList(utf8.encode(message))),
          },
        ),
      );
      final signature = result is Map ? result['signature'] : null;
      if (signature is! String || signature.isEmpty) {
        throw const HardWalletException(
          'Az aláírás megszakadt vagy elutasítva.',
        );
      }
      await retryOnUnavailable(
        () => callFirebaseCallable<Object?>(
          'hardWalletVerify',
          parameters: {
            'challengeId': challenge.data['challengeId'],
            'signature': base64.encode(base58Decode(signature)),
          },
        ),
      );
    } finally {
      await _close(modal);
    }
  }

  /// A szerver által összeállított HARD-átutalás aláírása és beküldése a
  /// WalletConnect-tárcával; a tranzakció aláírását és beküldését a tárca végzi.
  /// Visszaadja a tranzakció aláírását (base58). Csak a kötött tárcával engedett.
  Future<String> sendTransfer(
    BuildContext context, {
    required String transactionBase64,
    required String expectedAddress,
  }) async {
    final modal = _createModal(context, 'HARD küldése másik felhasználónak');
    try {
      final (session, address) = await _open(context, modal);
      if (address != expectedAddress) {
        throw const HardWalletException(
          'Ez nem az összekötött tárca. Válaszd ki azt a tárcát, amelyet a fiókodhoz kötöttél.',
        );
      }
      final result = await modal.request(
        topic: session.topic,
        chainId: 'solana:$_solanaDevnet',
        request: SessionRequestParams(
          method: 'solana_signAndSendTransaction',
          params: {'transaction': transactionBase64},
        ),
      );
      final signature = result is Map ? result['signature'] : null;
      if (signature is! String || signature.isEmpty) {
        throw const HardWalletException(
          'Az átutalás megszakadt vagy elutasítva.',
        );
      }
      return signature;
    } finally {
      await _close(modal);
    }
  }
}
