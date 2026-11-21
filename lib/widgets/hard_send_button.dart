import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../screens/more/hard_wallet_screen.dart';
import '../services/hard_wallet_plan.dart';
import 'app_text.dart';

/// „HARD küldése" egy másik felhasználónak. Csak akkor látszik, ha a HARD
/// funkció be van kapcsolva és a saját tárcád össze van kötve; a címzett címét a
/// szerver oldja fel (és szól, ha neki még nincs tárcája).
class HardSendButton extends ConsumerWidget {
  const HardSendButton({
    super.key,
    required this.recipientUid,
    required this.recipientName,
  });

  final String recipientUid;
  final String recipientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hardWalletStatusProvider).valueOrNull;
    if (status == null || !status.enabled || !status.linked) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _SendDialog(
          recipientUid: recipientUid,
          recipientName: recipientName,
        ),
      ),
      icon: const Icon(Icons.send_outlined),
      label: const AppText('HARD küldése'),
    );
  }
}

class _SendDialog extends ConsumerStatefulWidget {
  const _SendDialog({required this.recipientUid, required this.recipientName});

  final String recipientUid;
  final String recipientName;

  @override
  ConsumerState<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends ConsumerState<_SendDialog> {
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _send({required bool walletConnect}) async {
    final amount = _amount.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (amount.isEmpty) {
      setState(() => _error = 'Add meg az összeget.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = await hardWalletService.prepareTransfer(
        recipientUid: widget.recipientUid,
        amount: amount,
      );
      if (!mounted) return;
      final signature = walletConnect
          ? await hardWalletConnect.sendTransfer(
              context,
              transactionBase64: quote.transaction,
              expectedAddress: quote.sender,
            )
          : await hardWalletService.sendTransfer(quote);
      ref.invalidate(hardWalletStatusProvider);
      if (!mounted) return;
      final text = trArgs(
        context,
        'Elküldve: {amount} HARD. Tranzakció: {sig}',
        {'amount': quote.amount, 'sig': shortAddress(signature)},
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (error) {
      if (mounted) setState(() => _error = hardWalletErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AppText('HARD küldése'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trArgs(context, 'Címzett: {name}', {'name': widget.recipientName}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, 'Összeg (HARD)'),
            ),
          ),
          const SizedBox(height: 12),
          const AppText(
            'Az átutalás nem visszavonható. A hálózati díjat a te tárcád fizeti, '
            'az aláírást és a beküldést a tárcád végzi.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, _error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const AppText('Mégse'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _send(walletConnect: true),
          child: const AppText('Más tárca (WalletConnect)'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _send(walletConnect: false),
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const AppText('Küldés a tárcával'),
        ),
      ],
    );
  }
}
