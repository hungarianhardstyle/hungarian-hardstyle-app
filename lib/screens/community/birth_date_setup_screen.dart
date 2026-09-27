import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/tr.dart';
import '../../core/errors/user_facing_error.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import '../../widgets/birth_date_field.dart';

/// **Születési dátum megadása** — ide visz a „Kérjük, add meg a születési
/// dátumod" értesítés koppintása.
///
/// MIÉRT KÜLÖN KÉPERNYŐ: a szerveroldali emlékeztető (`functions/index.js` →
/// `sendBirthDateNotices`, a tulajdonos kérése: *„menjen ki notifybe mér
/// kötelező a születési dátum, mehet nekik mail is"* — *„a meglévő tagoknak
/// úgyértem"*) olyan tagokat szólít meg, akiknél a dátum hiányzik. A
/// koppintásnak oda kell vinnie, ahol a dátumot **be is tudják állítani** — a
/// Chat fül sávja erre nem mindig elég (a felhasználó máshol jár az appban), a
/// nyilvános profil pedig nem tartalmaz szerkesztést.
///
/// A mentés **ugyanazt** az egyetlen mezős utat hívja, amit a Chat fül
/// felugrója (`CommunityService.saveBirthDate`): nem küldjük újra a teljes
/// profil-űrlapot, és nem indul el a névfoglalás sem.
///
/// ⚠️ A `birthDateVisible` alapból `false` marad (a szolgáltatás állítja be a
/// profil létrehozásakor), ezért a dátum **nem** jelenik meg a nyilvános
/// profilon, amíg a felhasználó a profil-szerkesztőben be nem kapcsolja — ezt a
/// képernyő ki is mondja.
class BirthDateSetupScreen extends StatefulWidget {
  const BirthDateSetupScreen({super.key, this.initialValue});

  /// Ha a hívó már ismeri a tárolt dátumot (pl. a profilból), azt mutatjuk.
  final String? initialValue;

  @override
  State<BirthDateSetupScreen> createState() => _BirthDateSetupScreenState();
}

class _BirthDateSetupScreenState extends State<BirthDateSetupScreen> {
  String? _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  Future<void> _pick() async {
    final picked = await pickBirthDate(context, current: _value);
    if (picked == null || !mounted) return;
    setState(() => _value = picked);
  }

  Future<void> _save() async {
    final value = _value;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (value == null || uid.isEmpty || _saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CommunityService().saveBirthDate(uid, value);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: AppText(tr(context, 'A születési dátum elmentve.'))),
      );
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(userFacingError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _value == null
        ? tr(context, 'Nincs megadva')
        : MaterialLocalizations.of(context).formatMediumDate(
            DateTime.parse(_value!),
          );
    return Scaffold(
      appBar: AppBar(title: const AppText('Születési dátum')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppText(
            'Add meg a születési dátumodat. A közösségi funkciók 16 éves kortól használhatók, és a dátum a kiskorúak védelmét szolgálja.',
          ),
          const SizedBox(height: 8),
          const AppText(
            'A dátum alapból rejtve marad: a profil-szerkesztőben te dönthetsz a megjelenítéséről.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const ValueKey('birth-date-setup-value'),
              leading: const Icon(Icons.cake_outlined),
              title: const AppText('Születési dátum'),
              subtitle: Text(selected),
              trailing: TextButton(
                key: const ValueKey('birth-date-setup-pick'),
                onPressed: _saving ? null : _pick,
                child: const AppText('Dátum kiválasztása'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('birth-date-setup-save'),
            onPressed: _value == null || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const AppText('Mentés'),
          ),
        ],
      ),
    );
  }
}
