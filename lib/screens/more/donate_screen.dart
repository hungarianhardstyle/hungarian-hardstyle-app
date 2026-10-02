import '../../widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  /// A támogatás linkje — **egy helyen** (a Twitch-oldal is ezt használja).
  ///
  /// A tulajdonos válasza (2026-10-01): *„ott van az appban a támogatásnál”* —
  /// ezért nem kérünk külön linket a stream alá, hanem ugyanezt a PayPal-célt.
  static final Uri donateUri = Uri.parse(
    'https://www.paypal.com/donate/?business=djdeeroy%40gmail.com&currency_code=EUR',
  );

  /// A támogatás indítása (a Twitch-oldal gombja is ezt hívja).
  static Future<void> openDonate() =>
      launchUrl(donateUri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Támogatás')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(Icons.favorite, color: Colors.redAccent, size: 68),
          const SizedBox(height: 18),
          const AppText(
            'Segítsd a munkánkat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const AppText(
            'A támogatás hozzájárul a Hungarian Hardstyle app és közösség fejlesztéséhez.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: openDonate,
            icon: const Icon(Icons.payment),
            label: const AppText('Támogatás PayPallal'),
          ),
        ],
      ),
    );
  }
}
