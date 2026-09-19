import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/news_reaction_service.dart';
import 'package:hungarian_hardstyle_app/widgets/news_reaction_button.dart';

/// A widget a valódi `NewsReactionService`-t használja, ami Firebase-t és
/// hálózatot is igényel. A teszt ezért a szűk szeletet hamisítja: ugyanaz a
/// viselkedés, csak Firebase nélkül.
class _FakeReactionService extends NewsReactionService {
  _FakeReactionService({this.dailyPoints, this.liked = false});

  final DailyLikePoints? dailyPoints;
  bool liked;
  int toggleCalls = 0;

  @override
  Stream<NewsReactionState> watchState(int postId) =>
      Stream.value(NewsReactionState(count: liked ? 1 : 0, liked: liked));

  @override
  Stream<DailyLikePoints?> watchDailyLikePoints() => Stream.value(dailyPoints);

  @override
  Future<NewsReactionState> toggle(int postId) async {
    toggleCalls++;
    liked = !liked;
    return NewsReactionState(count: liked ? 1 : 0, liked: liked);
  }
}

Future<void> _pumpButton(
  WidgetTester tester,
  _FakeReactionService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: NewsReactionButton(postId: 42, service: service),
        ),
      ),
    ),
  );
  // A hamis stream-ek `Stream.value`-val jönnek, ezért egy extra frame kell.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dailyLikePointsOf (tiszta logika)', () {
    final now = DateTime(2026, 9, 19, 12);

    Map<String, Object?> profile({
      Object? kind = 'newsLike',
      Object? date = '2026-09-19',
      Object? count = 2,
      Object? limit = 3,
    }) => <String, Object?>{
      'achievementDailyLimit': <String, Object?>{
        'kind': kind,
        'date': date,
        'count': count,
        'limit': limit,
      },
    };

    test('a mai hír-lájk keretet felismeri', () {
      final points = dailyLikePointsOf(profile(), now: now);
      expect(points, isNotNull);
      expect(points!.count, 2);
      expect(points.limit, 3);
      expect(points.date, '2026-09-19');
      expect(points.exhausted, isFalse);
      expect(points.label, 'Ma 2/3 lájkpont jár.');
    });

    test('elfogyott keretnél a jelzés egyértelmű', () {
      final points = dailyLikePointsOf(profile(count: 3), now: now)!;
      expect(points.exhausted, isTrue);
      expect(points.label, 'A mai lájkpontod elfogyott.');
    });

    test('a 3 feletti számláló is elfogyottnak számít', () {
      expect(dailyLikePointsOf(profile(count: 4), now: now)!.exhausted, isTrue);
    });

    test('más pontforrás (komment) nem lájkpont', () {
      expect(
        dailyLikePointsOf(profile(kind: 'articleComment'), now: now),
        isNull,
      );
    });

    test('a régi (nem mai) nap nem érvényes', () {
      expect(
        dailyLikePointsOf(profile(date: '2026-09-18'), now: now),
        isNull,
      );
    });

    test('hiányzó vagy hibás adat nem hazudik keretet', () {
      expect(dailyLikePointsOf(null, now: now), isNull);
      expect(dailyLikePointsOf(<String, Object?>{}, now: now), isNull);
      expect(
        dailyLikePointsOf(<String, Object?>{
          'achievementDailyLimit': 'valami',
        }, now: now),
        isNull,
      );
      expect(dailyLikePointsOf(profile(limit: 0), now: now), isNull);
      // A `null` limit nem jelenti azt, hogy végtelen a keret — semmit sem
      // állítunk, amit nem tudunk.
      expect(dailyLikePointsOf(profile(limit: null), now: now), isNull);
    });
  });

  group('NewsReactionButton — a napi keret jelzése', () {
    testWidgets('elfogyott keretnél a lájk megmondja, miért nincs pont', (
      tester,
    ) async {
      final service = _FakeReactionService(
        dailyPoints: const DailyLikePoints(
          count: 3,
          limit: 3,
          date: '2026-09-19',
        ),
      );
      await _pumpButton(tester, service);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('A mai lájkpontod elfogyott.'),
        findsOneWidget,
      );
      // A limitet is kimondja, különben a felhasználó nem tudja, mennyi lenne.
      expect(
        find.textContaining('naponta 3 alkalommal jár pont'),
        findsOneWidget,
      );
      // A jelzés nem akadályozza meg a reakciót magát.
      expect(service.toggleCalls, 1);
    });

    testWidgets('maradék keretnél nincs figyelmeztetés', (tester) async {
      final service = _FakeReactionService(
        dailyPoints: const DailyLikePoints(
          count: 1,
          limit: 3,
          date: '2026-09-19',
        ),
      );
      await _pumpButton(tester, service);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(service.toggleCalls, 1);
    });

    testWidgets('vendégnél (nincs profil-adat) nincs figyelmeztetés', (
      tester,
    ) async {
      final service = _FakeReactionService(dailyPoints: null);
      await _pumpButton(tester, service);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a lájk VISSZAVONÁSA nem figyelmeztet, hiszen nem pontot kér', (
      tester,
    ) async {
      final service = _FakeReactionService(
        liked: true,
        dailyPoints: const DailyLikePoints(
          count: 3,
          limit: 3,
          date: '2026-09-19',
        ),
      );
      await _pumpButton(tester, service);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(service.toggleCalls, 1);
    });
  });
}
