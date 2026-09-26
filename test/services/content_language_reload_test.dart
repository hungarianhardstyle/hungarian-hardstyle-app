import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/core/i18n/content_language_reload.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

/// A **nyelvváltás a megnyitott adatlapokon** (a tulajdonos kérése,
/// 2026-09-26: *„csináld"*).
///
/// **A mért hiba:** a listák már átálltak a választott nyelvre, a **már
/// megnyitott** cikk-/esemény-/kiadvány-adatlap viszont a betöltött (régi
/// nyelvű) példányt tartotta: a *feliratok* átfordultak (`tr`), a **tartalom**
/// (cím, szöveg, leírás) nem — újra kellett nyitni a képernyőt.
///
/// Ez a fájl a **döntést** méri (a hálózat nélkül mérhető részt): a képernyő
/// nyelvváltáskor **egyszer** újratölt, tartalom-frissülésre **nem**, és a
/// lebontás után **nem** marad figyelő. A képernyők bekötését forrás-lint őrzi.
void main() {
  late AppLanguage original;

  setUp(() {
    original = AppStrings.language;
  });

  tearDown(() {
    AppStrings.setLanguage(original);
  });

  Future<GlobalKey<_ProbeState>> pumpProbe(WidgetTester tester) async {
    final key = GlobalKey<_ProbeState>();
    await tester.pumpWidget(MaterialApp(home: _Probe(key: key)));
    return key;
  }

  testWidgets('nyelvváltáskor EGYSZER tölt újra', (tester) async {
    final key = await pumpProbe(tester);
    final live = key.currentState!;
    expect(live.reloads, 0, reason: 'nyitáskor nincs újratöltés');

    AppStrings.setLanguage(AppLanguage.en);
    WordpressService.publicContentRefreshGeneration.value++;
    await tester.pump();
    await tester.pump();

    expect(
      live.reloads,
      1,
      reason: 'a nyelvváltás után a betöltött tartalmat újra kell kérni',
    );
    expect(live.lastLanguage, AppLanguage.en);
  });

  testWidgets('tartalom-frissülésre (nyelvváltás nélkül) NEM tölt újra', (
    tester,
  ) async {
    final key = await pumpProbe(tester);
    final live = key.currentState!;

    WordpressService.publicContentRefreshGeneration.value++;
    WordpressService.publicContentRefreshGeneration.value++;
    await tester.pump();
    await tester.pump();

    expect(
      live.reloads,
      0,
      reason:
          'a jelzés a tartalom frissülésénél is felhúz — ilyenkor nem '
          'indítunk felesleges kérést',
    );
  });

  testWidgets('a lebontott képernyő nem tölt többé (nincs figyelő-szivárgás)', (
    tester,
  ) async {
    final key = await pumpProbe(tester);
    final live = key.currentState!;

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    AppStrings.setLanguage(AppLanguage.en);
    WordpressService.publicContentRefreshGeneration.value++;
    await tester.pump();

    expect(live.reloads, 0, reason: 'lebontás után nem indul kérés');
  });

  group('forrás-lint: a három adatlap be van kötve', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a cikk, az esemény és a kiadvány adatlapja a mixint használja', () {
      const screens = {
        'lib/screens/news/news_detail_screen.dart': 'NewsDetailScreen',
        'lib/screens/events/event_detail_screen.dart': 'EventDetailScreen',
        'lib/screens/releases/release_detail_screen.dart': 'ReleaseDetailScreen',
      };
      for (final entry in screens.entries) {
        final source = read(entry.key);
        expect(
          source,
          contains("import '../../core/i18n/content_language_reload.dart';"),
          reason: '${entry.key}: hiányzó import',
        );
        expect(
          source,
          contains('with ContentLanguageReload<${entry.value}>'),
          reason: '${entry.key}: a mixin nincs a State-en',
        );
        expect(
          source,
          matches(
            RegExp(r'Future<void> reloadForLanguage\(\) => _loadFull\w+\(\);'),
          ),
          reason:
              '${entry.key}: a nyelvváltás egy létező betöltő utat hívjon '
              '(ne legyen külön másolat)',
        );
      }
    });

    test('a DJ- és szervező-adatlap a provideren át már átáll', () {
      // Ezek `ConsumerWidget`-ek, és a részlet-providerük figyeli a jelzést
      // (`ref.listen(publicContentRefreshProvider, … invalidateSelf())`), ezért
      // ott nem kell mixin — ezt a lint rögzíti, hogy ne maradjon ki egy hely.
      for (final path in const [
        'lib/providers/artists_provider.dart',
        'lib/providers/organizers_provider.dart',
      ]) {
        final source = read(path);
        expect(
          source,
          contains('ref.listen(publicContentRefreshProvider'),
          reason: '$path: a részlet-provider nem figyeli a jelzést',
        );
      }
    });
  });
}

/// Szonda-képernyő a mixin méréséhez (nincs hálózat, nincs valódi adat).
class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ContentLanguageReload<_Probe> {
  int reloads = 0;
  AppLanguage? lastLanguage;

  @override
  Future<void> reloadForLanguage() async {
    reloads += 1;
    lastLanguage = AppStrings.language;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
