import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/events_provider.dart';
import 'package:hungarian_hardstyle_app/providers/games_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/providers/prize_provider.dart';
import 'package:hungarian_hardstyle_app/providers/voting_provider.dart';
import 'package:hungarian_hardstyle_app/screens/home/home_screen.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';
import 'package:hungarian_hardstyle_app/services/prize_service.dart';
import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/models/voting.dart';
import 'package:hungarian_hardstyle_app/models/prize.dart';

/// A főoldal „További hírek" sora.
///
/// **A tulajdonos jelzése:** *„a TOVÁBBI hírek gomb a főoldalon lehetne olyan
/// mint a kérdőív meg a nyereményjáték kártya, egységesen"*.
///
/// Ezért a sor a **`HomeActionCard`**-ot használja — ugyanazt, amit a kérdőív, a
/// nyereményjáték és az éves szavazás. A teszt azt méri, hogy **ugyanolyan széles**,
/// mint azok, mert pontosan ez volt a kérés lényege (korábban egy keskeny,
/// tartalomhoz igazodó `OutlinedButton` volt).
class _RegisteredUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'test-uid';
}

/// A híreket és az eseményeket provider szinten adjuk meg, ezért a WordPress
/// szolgáltatást nem is kell helyettesíteni: az nem hívódik meg.
class _PollStub extends PollService {
  @override
  Future<HuhsPoll?> activePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async => null;

  @override
  Future<bool> hasVoted(int pollId) async => false;
}

class _PrizeStub extends PrizeService {
  @override
  Future<HuhsPrize?> activePrize({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async => null;
}

const _news = Post(
  id: 1,
  title: 'Friss hír a tesztből',
  excerpt: 'Rövid kivonat.',
  content: 'Tartalom.',
  imageUrl: '',
  date: '2026-09-18T10:00:00',
  link: 'https://hungarianhardstyle.hu/teszt',
  isSticky: false,
  categoryIds: <int>[],
  categories: <String>[],
  tags: <String>[],
  galleryId: 0,
  galleryImages: <GalleryImage>[],
  embeds: <PostEmbed>[],
  relatedPosts: <Post>[],
);

Widget _app(List<Post> news) {
  return ProviderScope(
    overrides: [
      newsProvider.overrideWith((ref) async => news),
      eventsProvider.overrideWith((ref) async => const []),
      activeGameProvider.overrideWith((ref) async => null),
      latestGameResultsProvider.overrideWith((ref) async => null),
      votingProvider.overrideWith((ref) async => const VotingSeason.inactive()),
      pollServiceProvider.overrideWithValue(_PollStub()),
      prizeServiceProvider.overrideWithValue(_PrizeStub()),
      communityAuthProvider.overrideWith(
        (ref) => Stream<User?>.value(_RegisteredUser()),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: HomeScreen(onShowMoreNews: () {}),
    ),
  );
}

void main() {
  testWidgets('a „További hírek" sor ugyanolyan széles, mint a hero kártya', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const [_news]));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('more-news'));
    expect(row, findsOneWidget, reason: 'a sor megjelenik, ha van hír');

    // A főoldali tartalom belső szélessége: ehhez kell igazodnia minden
    // hero-sornak (a kérdőívnek, a nyereményjátéknak és ennek is).
    final slider = tester.getRect(find.byType(PageView).first);
    final card = tester.getRect(row);

    expect(card.left, moreOrLessEquals(slider.left, epsilon: 0.5));
    expect(card.width, moreOrLessEquals(slider.width, epsilon: 0.5));
  });

  testWidgets('a sor a közös kártyaformát használja (HÍREK felirat + nyíl)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const [_news]));
    await tester.pumpAndSettle();

    // Az eyebrow ugyanaz a stílus, mint a KÉRDŐÍV / NYEREMÉNYJÁTÉK / SZAVAZÁS
    // sorokon — ez adja az egységes megjelenést.
    expect(find.text('HÍREK'), findsOneWidget);
    expect(find.text('További hírek'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
  });

  testWidgets('a sor koppintásra továbblép', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsProvider.overrideWith((ref) async => const [_news]),
          eventsProvider.overrideWith((ref) async => const []),
          activeGameProvider.overrideWith((ref) async => null),
          latestGameResultsProvider.overrideWith((ref) async => null),
          votingProvider.overrideWith(
            (ref) async => const VotingSeason.inactive(),
          ),
          pollServiceProvider.overrideWithValue(_PollStub()),
          prizeServiceProvider.overrideWithValue(_PrizeStub()),
          communityAuthProvider.overrideWith(
            (ref) => Stream<User?>.value(_RegisteredUser()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: HomeScreen(onShowMoreNews: () => tapped += 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-news')));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('nincs hír -> nincs „További hírek" sor', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('more-news')), findsNothing);
    expect(find.text('Nincs hír.'), findsOneWidget);
  });
}
