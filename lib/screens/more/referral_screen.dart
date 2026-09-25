import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<String> _codeFuture;

  @override
  void initState() {
    super.initState();
    _codeFuture = _loadCode();
  }

  Future<String> _loadCode() async {
    await FirebaseAuth.instance.authStateChanges().first;
    return CommunityService().getMyReferralCode();
  }

  void _retry() {
    setState(() => _codeFuture = _loadCode());
  }

  String _inviteUrl(String code) =>
      Uri.https('play.google.com', '/store/apps/details', <String, String>{
        'id': 'hu.hungarianhardstyle.app',
        'referrer': 'referral_code=$code',
      }).toString();

  String _inviteText(String code) =>
      'Csatlakozz a HUHS közösséghez! Regisztrálj az ajánlólinkkel: ${_inviteUrl(code)}';

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: _inviteText(code)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Az ajánlószöveg a vágólapra másolva.')),
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
      appBar: AppBar(title: const AppText('Ajánlás')),
      body: FutureBuilder<String>(
        future: _codeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.hasError
                        ? userFacingError(snapshot.error)
                        : 'Az ajánlókód nem tölthető be.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const AppText('Újrapróbálás'),
                  ),
                ],
              ),
            );
          }
          final code = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Icon(Icons.group_add_outlined, size: 64),
              const SizedBox(height: 16),
              const AppText(
                'Hívd meg az ismerőseidet a HUHS appba!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const AppText(
                'Másold ki az alábbi szöveget, küldd el az ismerősödnek, és ő a regisztrációnál megadhatja az ajánlókódot. Ha az új felhasználó regisztrál, 50 achievement pontot kapsz.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const AppText('A te ajánlókódod'),
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
                label: const AppText('Ajánlás másolása'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _share(code),
                icon: const Icon(Icons.share_outlined),
                label: const AppText('Megosztás…'),
              ),
              const SizedBox(height: 12),
              const AppText(
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
