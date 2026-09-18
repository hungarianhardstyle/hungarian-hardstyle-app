import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:hungarian_hardstyle_app/data/app_changelog.dart';
import 'package:hungarian_hardstyle_app/screens/more/about_screen.dart';

/// A Névjegy képernyő kiadási jegyzete.
///
/// A tulajdonos kérése: *„az appról részbe legyen changelog is"*, illetve
/// *„a Névjegy alatt legyen aktuális changelog verziószámmal"*.
///
/// A `PackageInfo`-t a képernyő paraméterként is elfogadja, ezért a teszt nem
/// függ a platformcsatornától.
PackageInfo _info(String version, String buildNumber) {
  return PackageInfo(
    appName: 'Hungarian Hardstyle',
    packageName: 'hu.hungarianhardstyle.app',
    version: version,
    buildNumber: buildNumber,
    installTime: null,
    updateTime: null,
  );
}

Widget _app(PackageInfo info) =>
    MaterialApp(home: AboutScreen(packageInfo: info));

void main() {
  final newest = sortedChangelog(appChangelog).first;

  testWidgets('a Névjegy alatt ott a changelog a verziószámmal', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(_info(newest.version, '${newest.build}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Újdonságok'), findsOneWidget);
    // A verzio a fejlecben es a changelog kartyan is latszik.
    expect(find.text('${newest.version}+${newest.build}'), findsWidgets);
    expect(find.text(newest.changes.first), findsOneWidget);
  });

  testWidgets('az aktuális kiadás meg van jelölve, a régiek külön szekcióban', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(_info(newest.version, '${newest.build}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ez a verzió'), findsOneWidget);
    expect(find.text('Korábbi kiadások'), findsOneWidget);

    // Az aktualis kiadas kartyaja FELJEBB van, mint a „Korábbi kiadások" fejlec.
    final currentY = tester.getTopLeft(find.text('Ez a verzió')).dy;
    final olderY = tester.getTopLeft(find.text('Korábbi kiadások')).dy;
    expect(currentY, lessThan(olderY));
  });

  testWidgets('régi buildnél a saját kiadás van kiemelve, nem a legfrissebb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final older = sortedChangelog(appChangelog)[1];
    await tester.pumpWidget(_app(_info(older.version, '${older.build}')));
    await tester.pumpAndSettle();

    // Pontosan EGY kiemelt kartya van, es az a telepitett build.
    expect(find.text('Ez a verzió'), findsOneWidget);
    expect(find.text(older.changes.first), findsOneWidget);

    final badgeY = tester.getTopLeft(find.text('Ez a verzió')).dy;
    final olderSectionFinder = find.text('Korábbi kiadások');
    // A frissebb kiadas ilyenkor a „Korábbi kiadások" reszbe kerul (mert nem a
    // telepitett build), tehat a jelveny a szekcio fejléce FÖLÖTT van.
    expect(olderSectionFinder, findsOneWidget);
    expect(
      badgeY,
      lessThan(tester.getTopLeft(olderSectionFinder).dy),
      reason: 'a telepitett kiadas kartyaja legfelul van',
    );
  });

  testWidgets('ismeretlen buildnél jelzi, hogy ehhez nincs jegyzet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_info('1.0.0', '999999')));
    await tester.pumpAndSettle();

    expect(find.textContaining('még nincs kiadási jegyzet'), findsOneWidget);
    // A korabbi kiadasok ilyenkor is latszanak.
    expect(find.text('Korábbi kiadások'), findsOneWidget);
  });

  testWidgets('a verzió és a kapcsolat adatok megmaradtak', (tester) async {
    await tester.pumpWidget(_app(_info(newest.version, '${newest.build}')));
    await tester.pumpAndSettle();

    expect(find.text('Verzió'), findsOneWidget);
    expect(find.text('Weboldal'), findsOneWidget);
    expect(find.text('hungarianhardstyle.hu'), findsOneWidget);
    expect(find.text('info@hungarianhardstyle.hu'), findsOneWidget);
  });
}
