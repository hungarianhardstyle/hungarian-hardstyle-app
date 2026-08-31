import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/community_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late final Future<String> _codeFuture = CommunityService().getMyReferralCode();

  String _inviteUrl(String code) => Uri.https(
        'play.google.com',
        '/store/apps/details',
        <String, String>{
          'id': 'hu.hungarianhardstyle.app',
          'referrer': 'referral_code=$code',
        },
      ).toString();

  String _inviteText(String code) =>
      'Csatlakozz a HUHS közösséghez! Regisztrálj az ajánlólinkkel: ${_inviteUrl(code)}';

  Future<void> _copy(String code) async {
    await Clipboard.setData(
      ClipboardData(
        text: _inviteText(code),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Az ajánlószöveg a vágólapra másolva.')),
      );
    }
  }

  Future<void> _share(String code) async {
    await Share.share(
      _inviteText(code),
      subject: 'Hungarian Hardstyle meghívó',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajánlás')),
      body: FutureBuilder<String>(
        future: _codeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Az ajánlókód nem tölthető be.'));
          }
          final code = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Icon(Icons.group_add_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Hívd meg az ismerőseidet a HUHS appba!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Másold ki az alábbi szöveget, küldd el az ismerősödnek, és ő a regisztrációnál megadhatja az ajánlókódot. Ha az új felhasználó regisztrál, 50 achievement pontot kapsz.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('A te ajánlókódod'),
                      const SizedBox(height: 8),
                      SelectableText(
                        _inviteUrl(code),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        code,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copy(code),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Ajánlás másolása'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _share(code),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Megosztás…'),
              ),
              const SizedBox(height: 12),
              const Text(
                'A link a Play Áruházba vezet, a meghívókód telepítés után automatikusan bekerül a regisztrációba. Egy új felhasználó csak egyszer használhat ajánlókódot. Saját kód nem használható, és a pontot a szerver írja jóvá.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          );
        },
      ),
    );
  }
}
