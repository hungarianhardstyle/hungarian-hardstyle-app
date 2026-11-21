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

  Future<void> connect(BuildContext context) async {
    // Csak a Solana devnet: a HARD jelenleg devneten van, más lánc nem kell.
    for (final namespace in ReownAppKitModalNetworks.getAllSupportedNamespaces()) {
      if (namespace != 'solana') {
        ReownAppKitModalNetworks.removeSupportedNetworks(namespace);
      }
    }
    ReownAppKitModalNetworks.removeSupportedNetworks(
      'solana',
      chainIds: [
        for (final n in ReownAppKitModalNetworks.getAllSupportedNetworks(namespace: 'solana'))
          // A tárolt azonosító előtag nélküli, a lista előtaggal adja vissza.
          if (n.chainId.split(':').last != _solanaDevnet) n.chainId.split(':').last,
      ],
    );

    final modal = ReownAppKitModal(
      context: context,
      projectId: reownProjectId,
      metadata: const PairingMetadata(
        name: 'Hungarian Hardstyle',
        description: 'HARD-tárca összekapcsolása (csak aláírás)',
        url: 'https://hungarianhardstyle.hu',
        icons: ['https://hardtoken.hungarianhardstyle.hu/logo.png'],
      ),
      disconnectOnDispose: false,
    );
    try {
      await modal.init();
      await modal.selectChain(
        ReownAppKitModalNetworks.getNetworkInfo('solana', _solanaDevnet),
      );
      if (!context.mounted) return;
      await modal.openModalView();
      final session = modal.session;
      final address = session?.getAddress('solana');
      if (session == null || address == null) {
        throw const HardWalletException('A tárca nem kapcsolódott.');
      }
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
        throw const HardWalletException('Az aláírás megszakadt vagy elutasítva.');
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
      // A kapcsolat csak az aláíráshoz kellett: nem hagyunk nyitott munkamenetet.
      try {
        await modal.disconnect();
      } catch (_) {}
      await modal.dispose();
    }
  }
}
