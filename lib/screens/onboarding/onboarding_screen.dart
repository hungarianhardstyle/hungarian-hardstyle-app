import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/tr.dart';
import '../../services/onboarding_state.dart';
import '../../widgets/notification_permission_prompt.dart';

/// **Onboarding — 3 lépés** (a használat-növelő csomag 2. pontja).
///
/// MIÉRT: a mért szakadék a **regisztrált profilok (45)** és a **push-ra
/// regisztrált eszközök (1016)** között van. Ez a folyamat egy menetben teszi meg
/// a két dolgot, ami ezt zárja: (1) rövid bemutató, (2) **kedvenc DJ(k)**
/// kiválasztása — ebből lesz a személyes értesítés —, (3) **értesítési engedély**
/// a jó pillanatban (a meglévő kapun át).
///
/// ⚠️ Egyszer fut és **átugorható**; a „Kész" és a „Kihagyás" is lezárja
/// (`markOnboardingCompleted`). A döntés a tiszta `onboarding_state.dart`-ben van
/// (mélylinkről nyitva például **nem** indul).
///
/// ⚠️ A feliratok **közvetlenül** a `tr(context, '…')` hívásban állnak: az i18n
/// extraktor csak így látja őket (segédfüggvénybe adott szöveg „fordítatlan"
/// maradna a gépi kapun).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const String routeName = '/onboarding';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.welcome;

  Future<void> _finish() async {
    markOnboardingCompleted(await SharedPreferences.getInstance());
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _next() async {
    final next = nextOnboardingStep(_step);
    if (next == null) {
      await _finish();
      return;
    }
    setState(() => _step = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Üdv a Hungarian Hardstyle appban')),
        actions: [
          TextButton(onPressed: _finish, child: Text(tr(context, 'Kihagyás'))),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: onboardingStepNumber(_step) / onboardingStepCount,
          ),
          Expanded(child: _buildStep(context)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _step == OnboardingStep.notifications
                        ? tr(context, 'Kész')
                        : tr(context, 'Tovább'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case OnboardingStep.welcome:
        return _centered(
          context,
          title: tr(context, 'Minden, ami a színtéren történik'),
          body: tr(
            context,
            'Hírek, bulik, kiadványok, DJ-k és a rádió — egy helyen. A következő két lépésben személyessé tesszük.',
          ),
        );
      case OnboardingStep.favoriteArtists:
        // ⚠️ MÉRT DÖNTÉS (2026-09-28): az `artistsProvider` egy **család**
        // (`ArtistListQuery` paraméterrel), ezért az onboarding nem hívja közvetlenül
        // — a lépés **oda irányítja** a felhasználót, ahol a szív ikon van (a DJ-lista),
        // a kedvencelés pedig onnantól magától szinkronizál a plugin felé. Így a
        // folyamat nem függ egy szűrő-objektum felépítésétől.
        return _centered(
          context,
          title: tr(context, 'Kövesd a kedvenc DJ-jeidet'),
          body: tr(
            context,
            'Nyisd meg a DJ-k listáját, és a szív ikonnal követheted őket.',
          ),
        );
      case OnboardingStep.notifications:
        return _centered(
          context,
          title: tr(context, 'Ne maradj le semmiről'),
          body: tr(
            context,
            'Szólunk, ha a kedvelt DJ-d új kiadványt tesz közzé, ha közelgő buli van, és vasárnap a hét összefoglalójával.',
          ),
          action: OutlinedButton.icon(
            onPressed: () =>
                NotificationPermissionPrompt.requestAfterAction(context),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(tr(context, 'Értesítések engedélyezése')),
          ),
        );
    }
  }

  /// A lépés elrendezése — a **szövegek már fordítva** érkeznek (a `tr` hívás a
  /// hívó helyén van, ezért az extraktor látja őket).
  Widget _centered(
    BuildContext context, {
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}
