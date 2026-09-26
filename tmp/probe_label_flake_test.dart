import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/label_release_availability.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SZONDA (2026-09-26): miért villog a `label_release_availability` „ismételt
/// megjelölés" tesztje a CI-n?
///
/// A CI-n a várt 1 helyett **2** találat volt a tárolt JSON-ban. Ez a szonda
/// **ugyanazt a sorozatot** futtatja 30-szor, és kiírja a nyers tárolót, amikor
/// eltérés van — így a hiba **oka** látszik, nem csak a tünete.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('30 kör: hányszor duplázódik a jelölés, és milyen a nyers tároló?', () async {
    var duplicates = 0;
    for (var round = 1; round <= 30; round++) {
      SharedPreferences.setMockInitialValues({});
      final store = LabelReleaseAvailability();
      await store.markMissing(305);
      await store.markMissing(305);
      await store.markMissing(305);
      final preferences = await SharedPreferences.getInstance();
      final payload = preferences.getString('huhs.release.missing') ?? '(nincs)';
      final matches = '305'.allMatches(payload).length;
      if (matches != 1) {
        duplicates += 1;
        // ignore: avoid_print
        print('KÖR $round: találat=$matches tároló=$payload');
      }
    }
    // ignore: avoid_print
    print('duplázódó körök: $duplicates / 30');
    expect(duplicates, 0);
  });
}
