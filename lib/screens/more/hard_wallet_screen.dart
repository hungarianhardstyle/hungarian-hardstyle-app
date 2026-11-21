import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/layout/scroll_bottom_inset.dart';
import '../../services/hard_wallet_plan.dart';
import '../../services/hard_wallet_service.dart';
import '../../widgets/app_text.dart';

const hardWalletService = HardWalletService();

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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(hardWalletStatusProvider);
    } catch (error) {
      if (mounted) setState(() => _error = hardWalletErrorMessage(error));
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
      return FilledButton.icon(
        onPressed: _busy ? null : () => _run(hardWalletService.connect),
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.account_balance_wallet_outlined),
        label: const AppText('Tárca összekapcsolása'),
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
