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
          const SizedBox(height: 24),
          const Text(
            'Jogi információ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A Hungarian Hardstyle alkalmazásban elérhető rádiót a holland Real Hardstyle üzemelteti. A szolgáltató nyilvános tájékoztatása szerint a működéshez szükséges holland zenei jogkezelői licencekkel (Buma/Stemra és Sena) rendelkezik. A Hungarian Hardstyle nem tárol zenefájlokat saját szerverein, nem üzemeltet rádiós médiaszervert, és nem sugároz saját streamet. Az alkalmazás kizárólag a Real Hardstyle hivatalos, külső streamjét éri el és játssza le a felhasználók számára.',
          ),
        ],
      ),
    );
  }
}
