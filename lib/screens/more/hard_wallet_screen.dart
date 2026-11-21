import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/layout/scroll_bottom_inset.dart';
import '../../services/hard_wallet_connect.dart';
import '../../services/hard_wallet_plan.dart';
import '../../services/hard_wallet_service.dart';
import '../../widgets/app_text.dart';

const hardWalletService = HardWalletService();
const hardWalletConnect = HardWalletConnect();

/// A tárca állapota és a HARD-egyenleg. Hiba (pl. 18 év alatt) vagy kikapcsolt
/// funkció esetén a menüpont el is tűnik (lásd a Közösség menüt).
final hardWalletStatusProvider = FutureProvider.autoDispose<HardWalletStatus>(
  (ref) => hardWalletService.status(),
);

class HardWalletScreen extends ConsumerStatefulWidget {
  const HardWalletScreen({super.key});

  @override
  ConsumerState<HardWalletScreen> createState() => _HardWalletScreenState();
}

class _HardWalletScreenState extends ConsumerState<HardWalletScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, {bool connecting = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(hardWalletStatusProvider);
    } catch (error) {
      // A tárcából visszalépve a válasz elveszhet, miközben a szerver a kötést
      // már rögzítette: friss állapotot kérünk, és ha a kötés megvan, nincs hiba.
      var linked = false;
      try {
        linked = (await ref.refresh(hardWalletStatusProvider.future)).linked;
      } catch (_) {}
      final lostReply = connecting &&
          linked &&
          error is FirebaseFunctionsException &&
          error.code == 'unavailable';
      if (mounted && !lostReply) setState(() => _error = hardWalletErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(hardWalletStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('HARD tárca')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(hardWalletStatusProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const AppText(
              'A tárca összekapcsolása csak egy aláírás: nem költ és nem utal el semmit. '
              'Az egyenleget a szerver a blokkláncról kérdezi le.',
            ),
            const SizedBox(height: 16),
            status.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppText(hardWalletErrorMessage(error)),
              data: _body,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                tr(context, _error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const ScrollBottomInset(),
          ],
        ),
      ),
    );
  }

  Widget _body(HardWalletStatus status) {
    if (!status.enabled) {
      return const AppText('A HARD-tárca jelenleg nem érhető el.');
    }
    if (!status.linked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(hardWalletService.connect, connecting: true),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet_outlined),
            label: const AppText('Tárca összekapcsolása'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => hardWalletConnect.connect(context), connecting: true),
            icon: const Icon(Icons.qr_code_2),
            label: const AppText('Más tárca (WalletConnect)'),
          ),
          const SizedBox(height: 20),
          const _SupportedWallets(),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('Egyenleg'),
            const SizedBox(height: 4),
            Text(
              '${status.amount ?? '0'} HARD',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(shortAddress(status.address ?? '')),
            if (status.cluster == 'devnet')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: AppText('Teszthálózat (devnet): a token nem valódi érték.'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(hardWalletService.disconnect),
              child: const AppText('Tárca leválasztása'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A legismertebb összekapcsolható tárcák logóval. A logókat a WalletConnect
/// tárcaregisztere adja; ha nem tölthető be, a tárca neve látszik.
class _SupportedWallets extends StatelessWidget {
  const _SupportedWallets();

  static const _wallets = <(String, String)>[
    ('Phantom', 'b6ec7b81-bb4f-427d-e290-7631e6e50d00'),
    ('Solflare', '34c0e38d-66c4-470e-1aed-a6fabe2d1e00'),
    ('Backpack', '71ca9daf-a31e-4d2a-fd01-f5dc2dc66900'),
    ('Trust Wallet', '7677b54f-3486-46e2-4e37-bf8747814f00'),
    ('Bitget Wallet', '2b569b7f-e6c6-4faa-8e5a-ecd4dec8cf00'),
    ('OKX Wallet', '45f2f08e-fc0c-4d62-3e63-404e72170500'),
  ];

  static const _headers = {
    'x-project-id': reownProjectId,
    'x-sdk-type': 'appkit',
    'x-sdk-version': 'flutter-1.9.0',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('Ezekkel a tárcákkal kapcsolhatod össze (és még sok mással):'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final (name, imageId) in _wallets)
              SizedBox(
                width: 72,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: 'https://api.web3modal.org/getWalletImage/$imageId',
                        httpHeaders: _headers,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
