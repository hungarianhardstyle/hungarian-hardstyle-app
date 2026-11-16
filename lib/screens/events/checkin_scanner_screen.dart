import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/tr.dart';
import '../../services/event_checkin_service.dart';
import '../../widgets/app_text.dart';

/// A bulis **QR-becsekkolás** beolvasója.
///
/// A kamera a bejáratnál kitett QR-t olvassa; a **szerver** dönt (titkos kód +
/// a buli időablaka + fiókonként egyszer), az app csak megmutatja az eredményt.
/// Egyszerre egy beolvasás fut (a kamera percenként tucatszor ismétel).
class CheckinScannerScreen extends StatefulWidget {
  const CheckinScannerScreen({super.key, this.service, this.initialQr});

  final EventCheckinService? service;

  /// Linkből (az app megnyitása a QR-ral) indulva már ismert a tartalom.
  final String? initialQr;

  @override
  State<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends State<CheckinScannerScreen> {
  late final EventCheckinService _service =
      widget.service ?? EventCheckinService();
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;
  EventCheckinResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQr;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _process(initial));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _result != null) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;
    await _process(raw);
  }

  Future<void> _process(String raw) async {
    if (_busy || _result != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.checkIn(raw);
      if (!mounted) return;
      setState(() => _result = result);
    } on EventCheckinException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'A becsekkolás most nem sikerült, próbáld újra.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const AppText('Becsekkolás')),
      body: result != null ? _success(context, result) : _scanner(context),
    );
  }

  Widget _scanner(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'A kamera nem érhető el. Engedélyezd a kamerát a telefon beállításaiban.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        AppText('Ellenőrzés…'),
                      ],
                    )
                  : _error != null
                  ? Text(
                      tr(context, _error!),
                      key: const Key('checkin-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    )
                  : const AppText(
                      'Olvasd be a bejáratnál kitett QR-kódot.',
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _success(BuildContext context, EventCheckinResult result) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result.badgeUrl.isNotEmpty)
              Image.network(
                result.badgeUrl,
                width: 140,
                height: 140,
                errorBuilder: (_, _, _) => _badgeIcon(theme),
              )
            else
              _badgeIcon(theme),
            const SizedBox(height: 16),
            AppText(
              result.alreadyCheckedIn
                  ? 'Erre a bulira már becsekkoltál.'
                  : 'Becsekkoltál!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.badgeName,
              key: const Key('checkin-badge-name'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (result.points > 0) ...[
              const SizedBox(height: 8),
              Text(
                trArgs(context, '+{n} pont jár a becsekkolásért.', {
                  'n': '${result.points}',
                }),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(result),
              child: const AppText('Kész'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon(ThemeData theme) =>
      Icon(Icons.verified, size: 96, color: theme.colorScheme.primary);
}
