import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/data/app_changelog.dart';

/// Az app kiadási jegyzete (changelog).
///
/// A tulajdonos kérése: *„az appról részbe legyen changelog is"*. A szöveg
/// forrása a `docs/RELEASE_CHANGELOG_CHECKLIST.md`, amit a Play-jegyzettel
/// együtt kell vezetni — ez a teszt ezt a fegyelmet kényszeríti ki, mert
/// enélkül a következő kiadásnál könnyen elmaradna a bejegyzés.
void main() {
  test('a pubspec verziójához TARTOZIK changelog bejegyzés', () {
    // Ez a lényegi védelem: ha valaki megemeli a verziókódot és elfelejti a
    // changelogot, a felhasználó üres „Újdonságok" részt látna a frissítés
    // után. Inkább itt hasaljon el.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\+(\d+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'a pubspec.yaml-ban legyen version: x.y.z+N');

    final version = match!.group(1)!;
    final build = int.parse(match.group(2)!);

    final note = releaseNotesForBuild(appChangelog, build);
    expect(
      note,
      isNotNull,
      reason:
          'a pubspec verziója $version+$build, de ehhez nincs changelog bejegyzés '
          'a lib/data/app_changelog.dart-ban',
    );
    expect(note!.version, version);
    expect(note.changes, isNotEmpty);
  });

  test('a kiadások a legfrissebbel kezdve, csökkenő buildszámmal jönnek', () {
    final sorted = sortedChangelog(appChangelog);
    for (var index = 1; index < sorted.length; index += 1) {
      expect(
        sorted[index].build,
        lessThan(sorted[index - 1].build),
        reason: 'a changelog legyen idorendben, a legfrissebbel elol',
      );
    }
  });

  test('nincs kétszer ugyanaz a buildszám', () {
    final builds = appChangelog.map((note) => note.build).toList();
    expect(builds.toSet().length, builds.length);
  });

  test('az aktuális buildhez a saját bejegyzése jön vissza', () {
    final newest = sortedChangelog(appChangelog).first;
    expect(releaseNotesForBuild(appChangelog, newest.build)?.build, newest.build);
  });

  test('ismeretlen buildhez nincs bejegyzés (a felület ilyenkor jelzi)', () {
    expect(releaseNotesForBuild(appChangelog, 999999), isNull);
  });

  test('a régebbi kiadásokat meg tudjuk különböztetni az aktuálistól', () {
    final newest = sortedChangelog(appChangelog).first;
    final older = sortedChangelog(appChangelog)[1];
    expect(isOlderRelease(older, newest.build), isTrue);
    expect(isOlderRelease(newest, newest.build), isFalse);
  });

  test('minden bejegyzésnek van legalább egy, nem üres pontja', () {
    for (final note in appChangelog) {
      expect(note.changes, isNotEmpty, reason: 'build ${note.build}');
      for (final change in note.changes) {
        expect(change.trim(), isNotEmpty, reason: 'build ${note.build}');
        // A felhasznalonak szolo szoveg: ne maradjon benne fejlesztoi jeloles.
        expect(change.startsWith('- '), isFalse, reason: 'build ${note.build}');
        expect(change.contains('TODO'), isFalse, reason: 'build ${note.build}');
      }
    }
  });

  test('a legfrissebb bejegyzés a mostani build (nem maradt le)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final build = int.parse(
      RegExp(r'^version:\s*\S+\+(\d+)\s*$', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!,
    );
    expect(
      sortedChangelog(appChangelog).first.build,
      build,
      reason: 'a changelog elso bejegyzese az aktualis kiadas legyen',
    );
  });
}
