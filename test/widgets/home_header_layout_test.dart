import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/models/poll.dart';
import 'package:hungarian_hardstyle_app/models/prize.dart';
import 'package:hungarian_hardstyle_app/models/voting.dart';
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
import 'package:hungarian_hardstyle_app/widgets/language_switch_button.dart';

/// A főoldali fejléc a HU/EN kapcsolóval.
///
/// **MÉRT ALAPHELYZET (2026-09-25, 400 px-es tesztfelület):** avatar 52,
/// frissítés 48, értesítés 48, „Közösség" gomb 178,8, nyelvkapcsoló 71,2 →
/// **414 px**, a rendelkezésre álló hely 364 px. Vagyis a kapcsoló bekerülése
/// **50 px túlcsordulást** okozott a valós (400 px-es) telefon-szélességen — ez
/// nem teszt-hiba volt, hanem a felület hibája. A javítás: adaptív fejléc.
/// Ez a fájl **minden** gyakori készülékszélességen megköveteli, hogy ne
/// csorduljon túl semmi (a „ne törjön el az app" elv).
class _RegisteredUser extends Fake implements User {
  @override
  bool get isAnonymous => false;

  @override
  String get uid => 'test-uid';
}

class _PollStub extends PollService {
  @override
  Future<HuhsPoll?> activePoll({bool forceRefresh = false, bool bypassCache = false}) async => null;

  @override
  Future<bool> hasVoted(int pollId) async => false;
}

class _PrizeStub extends PrizeService {
  @override
  Future<HuhsPrize?> activePrize({bool forceRefresh = false, bool bypassCache = false}) async => null;
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

Widget _app() => ProviderScope(
      overrides: [
        newsProvider.overrideWith((ref) async => const [_news]),
        eventsProvider.overrideWith((ref) async => const []),
        activeGameProvider.overrideWith((ref) async => null),
        latestGameResultsProvider.overrideWith((ref) async => null),
        votingProvider.overrideWith((ref) async => const VotingSeason.inactive()),
        pollServiceProvider.overrideWithValue(_PollStub()),
        prizeServiceProvider.overrideWithValue(_PrizeStub()),
        communityAuthProvider.overrideWith((ref) => Stream<User?>.value(_RegisteredUser())),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: HomeScreen(onShowMoreNews: () {}),
      ),
    );

/// A gyakori készülékszélességek (logikai px): Galaxy A 360, iPhone SE 375,
/// Pixel 393/412, nagy telefon 430.
const List<double> _widths = [320, 360, 375, 393, 400, 412, 430];

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 3, 2600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish({'Közösség': 'Community', 'Nyelv': 'Language'});
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  for (final width in _widths) {
    testWidgets('${width.toInt()} px: a fejléc nem csordul túl', (tester) async {
      await _pumpAt(tester, width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'a fejléc (avatar + frissítés + értesítés + Közösség + nyelv) '
            '${width.toInt()} px-en nem fér ki',
      );
      expect(find.byKey(const Key('language-switch-button')), findsOneWidget);
      expect(find.byType(LanguageSwitchButton), findsOneWidget);
    });
  }

  testWidgets('a kapcsoló a fejléc JOBB szélén van', (tester) async {
    await _pumpAt(tester, 412);
    final switchRect = tester.getRect(find.byType(LanguageSwitchButton));
    expect(switchRect.center.dx, greaterThan(412 / 2));
    // A jobb széltől érdemben nem lóghat ki.
    expect(switchRect.right, lessThanOrEqualTo(412));
  });

  testWidgets('szűk készüléken a Közösség gomb ikonná válik (nem tűnik el)', (tester) async {
    await _pumpAt(tester, 360);
    expect(find.byKey(const Key('community-hub-button')), findsOneWidget);
    expect(find.text('Közösség'), findsNothing, reason: 'szűk módban csak az ikon');
    // A nyelvkapcsoló felirata ilyenkor is látszik.
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('szélesebb készüléken marad a Közösség felirat', (tester) async {
    await _pumpAt(tester, 412);
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('angolos módban a fejléc feliratai is angolul vannak', (tester) async {
    AppStrings.setLanguage(AppLanguage.en);
    await _pumpAt(tester, 412);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('HU'), findsOneWidget);
  });
}
