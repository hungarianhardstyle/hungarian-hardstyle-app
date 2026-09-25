import '../../widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static final _donateUri = Uri.parse(
    'https://www.paypal.com/donate/?business=djdeeroy%40gmail.com&currency_code=EUR',
  );

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
            onPressed: () =>
                launchUrl(_donateUri, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.payment),
            label: const AppText('Támogatás PayPallal'),
          ),
        ],
      ),
    );
  }
}
