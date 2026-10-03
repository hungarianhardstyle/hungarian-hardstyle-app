import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/models/prize.dart';
import 'package:hungarian_hardstyle_app/models/voting.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/providers/events_provider.dart';
import 'package:hungarian_hardstyle_app/providers/games_provider.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/providers/poll_provider.dart';
import 'package:hungarian_hardstyle_app/providers/prize_provider.dart';
import 'package:hungarian_hardstyle_app/providers/twitch_live_provider.dart';
import 'package:hungarian_hardstyle_app/providers/voting_provider.dart';
import 'package:hungarian_hardstyle_app/screens/home/home_screen.dart';
import 'package:hungarian_hardstyle_app/services/poll_service.dart';
import 'package:hungarian_hardstyle_app/services/prize_service.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';
import 'package:hungarian_hardstyle_app/widgets/featured_news_card.dart';

/// **A főoldal kártyái iPhone fekvő nézetben** — a tulajdonos jelzése
/// (2026-10-03): *„ájfónon a kiemelt hír és a twitch kártya a főoldalon
/// ugyanakkora mint eddig, fekvő nézetben”*, majd: *„pedig elugattam, hogy túl
/// nagy, bár túl kicsi se legyen”*.
///
/// A mért gyökér: a főoldali **kiemelt-hír keringő** a saját (a közös szabályt
/// nem használó) méretét adta — 667 px széles telefonon `667 × 375`, azaz a
/// **teljes képernyőmagasság** —, a Twitch-kártya pedig 16:9-es képpel **álló**
/// elrendezésben maradt (~495 px magas, több mint a képernyő).
///
/// ⚠️ Ez a kör **geometriát** mér: mindkét irányt (nem túl nagy, és nem is túl
/// kicsi), és külön a **álló** nézetet, ami a tulajdonos szerint jó volt.
class _RegisteredUser extends Fake implements User {}

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
  id: 7,
  title: 'Kiemelt hír a tesztből, elég hosszú címmel hogy több sor is legyen',
  excerpt: 'Rövid kivonat.',
  content: 'Tartalom.',
  imageUrl: '',
  date: '2026-10-03T10:00:00',
  link: 'https://hungarianhardstyle.hu/teszt',
  isSticky: true,
  categoryIds: <int>[],
  categories: <String>[],
  tags: <String>[],
  galleryId: 0,
  galleryImages: <GalleryImage>[],
  embeds: <PostEmbed>[],
  relatedPosts: <Post>[],
);

/// Szándékosan **nagyon hosszú** cím: ezzel mérhető, hogy a széles (alacsony)
/// nézetben tényleg kevesebb sor jut a címre — különben a szöveg **kifutna** a
/// lecsökkent kártyából (a `Column` `Spacer`-e nulla alá nem megy).
const _longTitleNews = Post(
  id: 8,
  title: 'Nagyon hosszú kiemelt hírcím, amely biztos több sorba törik és kifutna '
      'a kártyából, ha nem csökkentenénk a sorok számát ebben a nézetben, '
      'mert a kártya magassága fekvő módban a képernyőhöz igazodik',
  excerpt: 'Rövid kivonat.',
  content: 'Tartalom.',
  imageUrl: '',
  date: '2026-10-03T10:00:00',
  link: 'https://hungarianhardstyle.hu/teszt',
  isSticky: true,
  categoryIds: <int>[],
  categories: <String>['Hírek'],
  tags: <String>[],
  galleryId: 0,
  galleryImages: <GalleryImage>[],
  embeds: <PostEmbed>[],
  relatedPosts: <Post>[],
);

Widget _app([List<Post> posts = const [_news]]) => ProviderScope(
      overrides: [
        newsProvider.overrideWith((ref) async => posts),
        eventsProvider.overrideWith((ref) async => const []),
        activeGameProvider.overrideWith((ref) async => null),
        latestGameResultsProvider.overrideWith((ref) async => null),
        votingProvider.overrideWith((ref) async => const VotingSeason.inactive()),
        pollServiceProvider.overrideWithValue(_PollStub()),
        prizeServiceProvider.overrideWithValue(_PrizeStub()),
        communityAuthProvider.overrideWith(
          (ref) => Stream<User?>.value(_RegisteredUser()),
        ),
        // A Twitch-kártya látszik (behirdetve, saját képpel).
        twitchLiveProvider.overrideWith((ref) async => const TwitchLiveStatus()),
        twitchCardOverrideProvider.overrideWith(
          (ref) async => const TwitchCardConfig(
            showWhenOffline: true,
            imageUrl: 'https://example.test/plakat.jpg',
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: HomeScreen(onShowMoreNews: () {}),
      ),
    );

void main() {
  /// iPhone SE (2. gen) logikai méretei — a tulajdonos készüléke.
  const iPhonePortrait = Size(375, 667);
  const iPhoneLandscape = Size(667, 375);
  const tabletLandscape = Size(1024, 768);

  Future<void> pumpAt(WidgetTester tester, Size size, [List<Post>? posts]) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(posts == null ? _app() : _app(posts));
    await tester.pumpAndSettle();
  }

  /// A Twitch-kártya a főoldal **alsó** részén van, ezért a lusta lista addig
  /// meg sem építi — odagördítünk, és utána mérünk.
  Future<Finder> scrollToTwitch(WidgetTester tester) async {
    final card = find.byKey(const Key('twitch-live-card'));
    await tester.scrollUntilVisible(
      card,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    return card;
  }

  double heightOf(WidgetTester tester, Finder finder) =>
      tester.getRect(finder).height;

  testWidgets('FEKVŐ iPhone: a kiemelt hír nem lehet a teljes képernyőmagasság', (tester) async {
    await pumpAt(tester, iPhoneLandscape);

    // ⚠️ Előbb mérünk, aztán gördülünk: a kiemelt hír a lista tetején van, és a
    // lusta lista a Twitch-kártyához gördülve már **meg sem építi**.
    final heroRect = tester.getRect(find.byType(FeaturedNewsCard).first);
    final hero = heroRect.height;
    final twitch = heightOf(tester, await scrollToTwitch(tester));
    // ignore: avoid_print
    print('MÉRÉS (fekvő 667×375): kiemelt=$hero twitch=$twitch');

    // Nem túl nagy: egyik kártya se vigye el a képernyőt.
    expect(hero, lessThanOrEqualTo(iPhoneLandscape.height * 0.60),
        reason: 'a kiemelt hír a teljes képernyőmagasságot elviszi');
    expect(twitch, lessThanOrEqualTo(iPhoneLandscape.height * 0.62),
        reason: 'a Twitch-kártya magasabb a képernyőnél');
    // …de túl kicsi se legyen: maradjon olvasható kártya.
    expect(hero, greaterThanOrEqualTo(iPhoneLandscape.height * 0.40),
        reason: 'a kiemelt hír túl kicsire zsugorodott');
    expect(twitch, greaterThan(140), reason: 'a Twitch-kártya túl kicsire zsugorodott');
    // A szélesség maradjon kiaknázva (nem lett keskeny, középre igazított csík).
    expect(heroRect.width, greaterThan(iPhoneLandscape.width * 0.9));
  });

  testWidgets('ÁLLÓ iPhone: változatlan (a tulajdonos szerint ez jó)', (tester) async {
    await pumpAt(tester, iPhonePortrait);

    final hero = heightOf(tester, find.byType(FeaturedNewsCard).first);
    final twitch = heightOf(tester, await scrollToTwitch(tester));
    // ignore: avoid_print
    print('MÉRÉS (álló 375×667): kiemelt=$hero twitch=$twitch');

    // ⚠️ A 250 a **közös legkisebb magasság** (`heroCardMinHeight`): a természetes
    // 16:9 (210,9) ennél kisebb, ezért a régi szabály is 250-et adott — a
    // változás előtt **mérve is 250,0** volt, tehát az álló nézet bitre ugyanaz.
    expect(hero, closeTo(250, 1.5),
        reason: 'álló nézetben a kiemelt hír mérete nem változhat');
    expect(twitch, closeTo(311.56, 2),
        reason: 'álló nézetben a Twitch-kártya maradjon a nagy (képes) változat');
  });

  testWidgets('FEKVŐ tablet: a kártyák középre igazítva, korlátozottan', (tester) async {
    await pumpAt(tester, tabletLandscape);

    final heroRect = tester.getRect(find.byType(FeaturedNewsCard).first);
    final twitch = heightOf(tester, await scrollToTwitch(tester));
    // ignore: avoid_print
    print('MÉRÉS (tablet fekvő 1024×768): kiemelt=${heroRect.height} '
        'szélesség=${heroRect.width} twitch=$twitch');

    expect(heroRect.width, lessThanOrEqualTo(760.01));
    expect(heroRect.height, lessThanOrEqualTo(tabletLandscape.height * 0.60));
    expect(heroRect.height, greaterThan(300),
        reason: 'tableten ne zsugorodjon össze a kiemelt hír');
    expect(twitch, lessThanOrEqualTo(300));
  });

  testWidgets('fekvő (alacsony) nézetben kevesebb cím-sor jut a kiemelt hírre', (tester) async {
    // ⚠️ A magasság-korlát miatt a kártya alacsony lehet: ilyenkor a 4 soros cím
    // + a nagy belső hézag **kifutna** (`RenderFlex overflowed`). Ezért széles
    // nézetben 2 sor a cím, állóban marad a 4 — ezt közvetlenül mérjük.
    await pumpAt(tester, iPhoneLandscape, const [_longTitleNews]);

    final wideTitle = tester.widget<Text>(find.text(_longTitleNews.title));
    expect(wideTitle.maxLines, 2, reason: 'széles nézetben kevesebb sor kell');
    expect(tester.takeException(), isNull, reason: 'a szöveg kifutott a kártyából');
    expect(find.text('KIEMELT HÍR'), findsOneWidget);

    await pumpAt(tester, iPhonePortrait, const [_longTitleNews]);
    final tallTitle = tester.widget<Text>(find.text(_longTitleNews.title));
    expect(tallTitle.maxLines, 4, reason: 'álló nézetben maradjon a régi (4 sor)');
  });
}
