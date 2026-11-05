import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:hungarian_hardstyle_app/core/legal/legal_links.dart';
import 'package:hungarian_hardstyle_app/screens/more/about_screen.dart';

/// **A jogi linkek a Névjegy alatt** (build 406) — a tulajdonos kérdése:
/// *„hol az app ÁSZF linkje?”*
///
/// A mért helyzet: az ÁSZF és az adatkezelési tájékoztató **él** a WordPressben
/// (HTTP 200), de az appban **semmilyen hivatkozás** nem volt rájuk. Ez a mérés
/// azt kéri számon, hogy a Névjegy alatt mindkettő ott legyen, a helyes URL-lel.
///
/// A két URL a `lib/core/legal/legal_links.dart`-ban él (egy forrás).
PackageInfo _info() {
  return PackageInfo(
    appName: 'Hungarian Hardstyle',
    packageName: 'hu.hungarianhardstyle.app',
    version: '1.0.0',
    buildNumber: '406',
    installTime: null,
    updateTime: null,
  );
}

void main() {
  test('az ÁSZF és az adatkezelési tájékoztató URL-je a valódi oldalra mutat', () {
    expect(
      legalTermsOfServiceUrl,
      'https://hungarianhardstyle.hu/altalanos-szerzodesi-feltetelek-aszf/',
    );
    expect(
      legalPrivacyPolicyUrl,
      'https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/',
    );
    // A Play/App Store csak HTTPS-t fogad el, és a gyökérre mutató link nem elég.
    for (final url in [legalTermsOfServiceUrl, legalPrivacyPolicyUrl]) {
      expect(url.startsWith('https://'), isTrue, reason: url);
      expect(url.length, greaterThan('https://hungarianhardstyle.hu/'.length));
      expect(url.endsWith('/'), isTrue, reason: url);
    }
    expect(legalTermsOfServiceUrl, isNot(legalPrivacyPolicyUrl));
  });

  testWidgets('a Névjegy alatt mindkét jogi link látszik (ÁSZF + adatkezelés)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: AboutScreen(packageInfo: _info())));
    await tester.pumpAndSettle();

    // A feliratok (magyar felületen).
    expect(find.text('Felhasználási feltételek (ÁSZF)'), findsOneWidget);
    expect(find.text('Adatkezelési tájékoztató'), findsOneWidget);

    // …és a megjelenített címek is a valódi oldalak (a `https://` nélkül).
    expect(
      find.text(
        legalTermsOfServiceUrl
            .replaceFirst('https://', '')
            .replaceFirst(RegExp(r'/$'), ''),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        legalPrivacyPolicyUrl
            .replaceFirst('https://', '')
            .replaceFirst(RegExp(r'/$'), ''),
      ),
      findsOneWidget,
    );
  });
}
