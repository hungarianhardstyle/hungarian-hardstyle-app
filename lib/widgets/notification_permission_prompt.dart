import 'package:flutter/material.dart';

import '../services/notification_permission_gate.dart';
import 'app_text.dart';

/// A **rövid magyar ismertető** az OS értesítés-engedély kérése ELŐTT.
///
/// MIÉRT KELL (2026-09-28): az OS-ablak eddig induláskor, minden felhasználói
/// művelet előtt jelent meg — így sok volt az elutasítás, és Android 13+ utánna
/// már **nem is kérdez**. A döntési logika a
/// `lib/services/notification_permission_gate.dart`-ban él (tesztelt, tiszta
/// kód); ez a fájl csak a **felugró lapot** adja hozzá, és a kaput hívja.
///
/// A hívó helyek (mind az **első** értelmes művelet):
///   * kedvenc mentése (`widgets/favorite_button.dart`,
///     `screens/organizers/organizer_detail_screen.dart`),
///   * „Ott leszek" egy eseményen (`screens/events/event_detail_screen.dart`),
///   * sikeres regisztráció (`screens/community/community_screen.dart`).
class NotificationPermissionPrompt {
  NotificationPermissionPrompt._();

  /// Az értesítési engedély kérése az első értelmes művelet után.
  ///
  /// ⚠️ **SOHA nem dob és nem blokkol**: a hívó `unawaited`-tel indíthatja, a
  /// kapu pedig minden hibát elnyel. Ha az engedély már megvan, **nem jelenik
  /// meg semmi** — csak a token-útvonal fut le (a meglévő működés változatlan).
  static Future<void> requestAfterAction(BuildContext context) async {
    try {
      await NotificationPermissionGate.requestAfterAction(
        showExplainer: () => _showExplainer(context),
      );
    } catch (_) {
      // Az engedélykérés kényelmi funkció: egy kedvenc mentése, egy részvétel
      // vagy egy regisztráció soha nem eshet el miatta.
    }
  }

  /// Az ismertető lap: rövid magyarázat, majd „Értesítések engedélyezése" vagy
  /// „Most nem". Visszaadja, hogy a felhasználó az engedélyezést választotta-e.
  static Future<bool> _showExplainer(BuildContext context) async {
    if (!context.mounted) return false;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1213),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFFFF3D43),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      'Ne maradj le semmiről',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const AppText(
                'Az értesítésekkel szólunk az új hírekről, a közelgő '
                'eseményekről és a közösségi üzenetekről. A telefonod most '
                'engedélyt kér ehhez — bármikor kikapcsolhatod a '
                'Beállításokban.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  icon: const Icon(Icons.notifications_active),
                  label: const AppText('Értesítések engedélyezése'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const AppText('Most nem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return accepted ?? false;
  }
}
