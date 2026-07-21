import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RadioProviderScreen extends StatelessWidget {
  const RadioProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rádió szolgáltató')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Image.asset('assets/logos/real_hardstyle_fm.png', height: 110),
          const SizedBox(height: 24),
          const Text(
            'Real Hardstyle FM',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('A rádiót a Real Hardstyle FM szolgáltatja.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('https://realhardstyle.nl'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('realhardstyle.nl megnyitása'),
          ),
        ],
      ),
    );
  }
}
