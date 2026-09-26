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
///
/// ⚠️ **A 2026-09-26-i kör (a tulajdonos jelzése: „Angolul »Community«, de
/// férjen ki"):** a küszöb korábban **fix 360 px** volt, a **magyar** feliratra
/// mérve. Angolul a „Community" hosszabb, ezért 400 px-en a sor nem fért ki, és
/// a tartalék `FittedBox` **arányosan lekicsinyítette** a fél fejlécet (a felirat
/// látszott, de zsugorodva). Mostantól a döntés a **tényleges felirat**
/// szélességéből jön (`homeHeaderFitsCommunityLabel`), ezért:
///  * a feliratos ág csak akkor fut, ha valóban kifér,
///  * **semmi nem zsugorodik** (ezt ez a fájl minden gyakori szélességen és
///    MINDKÉT nyelven megköveteli — a `FittedBox` csak végső háló),
///  * és a felirat sosem tűnik el indokolatlanul: ahol kifér, ott látszik.
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

/// A nyelvkapcsoló feliratának **kifestett** magassága.
///
/// ⚠️ MIÉRT `getRect` és nem `getSize`: a `FittedBox` **transzformációval**
/// kicsinyít, a layout-méret (`getSize`) változatlan maradna — a zsugorodást
/// csak a transzformált (globális) téglalap mutatja meg.
double _switchTextHeight(WidgetTester tester, double width, String glyph) {
  return tester.getRect(find.text(glyph)).height;
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
    testWidgets('${width.toInt()} px: a fejléc nem csordul túl (magyar)', (tester) async {
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

  for (final width in _widths) {
    testWidgets('${width.toInt()} px: a fejléc nem csordul túl (angol)', (tester) async {
      AppStrings.setLanguage(AppLanguage.en);
      await _pumpAt(tester, width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'angol felirattal („Community") sem csordulhat túl semmi',
      );
      expect(find.byType(LanguageSwitchButton), findsOneWidget);
    });
  }

  for (final scenario in [
    ('magyar', AppLanguage.hu, 'EN'),
    ('angol', AppLanguage.en, 'HU'),
  ]) {
    final (label, language, glyph) = scenario;
    testWidgets('$label: SEMMI nem zsugorodik egyetlen szélességen sem', (tester) async {
      AppStrings.setLanguage(language);
      await _pumpAt(tester, 430);
      final reference = _switchTextHeight(tester, 430, glyph);
      expect(reference, greaterThan(0));

      for (final width in _widths) {
        await _pumpAt(tester, width);
        final painted = _switchTextHeight(tester, width, glyph);
        expect(
          painted,
          closeTo(reference, 0.5),
          reason: '${width.toInt()} px-en a fejléc kicsinyítésre került '
              '($painted < $reference) — a feliratnak ki KELL férnie',
        );
      }
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

  // ⚠️ FONT-FÜGGETLEN MÉRÉS: a tesztekben az Ahem betűtípus minden karaktert
  // `fontSize` szélesre rajzol, ezért a feliratok a valóságosnál ~2× szélesebbek.
  // Ezért nem azt kérjük, hogy „412 px-en látszik a felirat" (az a valós
  // betűtípussal igaz, Ahem-mel nem), hanem azt, hogy **nagyon széles** helyen
  // látszik, és hogy a döntés a felirat szélességével együtt mozog.
  testWidgets('bőven széles helyen MINDKÉT nyelven látszik a felirat', (tester) async {
    for (final scenario in [
      ('magyar', AppLanguage.hu, 'Közösség'),
      ('angol', AppLanguage.en, 'Community'),
    ]) {
      final (label, language, expected) = scenario;
      AppStrings.setLanguage(language);
      await _pumpAt(tester, 700);
      expect(find.text(expected), findsOneWidget, reason: '$label felirat 700 px-en');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a döntés a felirat szélességével együtt mozog (angol előbb vált)', (tester) async {
    final huWidth = homeHeaderLabelWidth(
      label: 'Közösség',
      style: const TextStyle(fontSize: 14),
      textDirection: TextDirection.ltr,
    );
    final enWidth = homeHeaderLabelWidth(
      label: 'Community',
      style: const TextStyle(fontSize: 14),
      textDirection: TextDirection.ltr,
    );
    expect(enWidth, greaterThan(huWidth));
    expect(
      homeHeaderRequiredWidth(enWidth) - homeHeaderRequiredWidth(huWidth),
      closeTo(enWidth - huWidth, 0.001),
      reason: 'a különbség pontosan a feliratok szélesség-különbsége',
    );

    // Ugyanazon a szélességen: a magyar kifér, az angol már nem.
    final boundary = homeHeaderRequiredWidth(huWidth) + (enWidth - huWidth) / 2;
    expect(homeHeaderFitsCommunityLabel(available: boundary, labelWidth: huWidth), isTrue);
    expect(homeHeaderFitsCommunityLabel(available: boundary, labelWidth: enWidth), isFalse);
  });

  testWidgets('a gomb „kerete" konstans legalább a valódi méret', (tester) async {
    await _pumpAt(tester, 700);
    final button = tester.getSize(find.byKey(const Key('community-hub-button')));
    final label = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('community-hub-button')),
        matching: find.text('Közösség'),
      ),
    );
    // A felirat szélessége a teszt-betűtípusban (Ahem) szélesebb, mint a valós
    // arányos betűtípusban, a „keret" (margó + ikon + köz) viszont ugyanaz —
    // ezért ez a mérés a konstans alsó korlátja.
    final chrome = button.width - label.width;
    expect(
      homeCommunityButtonChrome,
      greaterThanOrEqualTo(chrome - 1),
      reason: 'a feltételezett keret ($homeCommunityButtonChrome) kisebb a valósnál ($chrome)',
    );
    // ⚠️ A 2026-09-26-i szűkítés (a tulajdonos képernyőképe: „mintha a gomb se
    // lenne Community") után a **valódi** követelmény ez: 360 px-es készüléken
    // (available = 360 − 36) a feliratra legalább 80 px maradjon — ennyi kell a
    // valós betűtípusú „Community" szövegnek. A teszt betűtípusa (Ahem) ~2×
    // szélesebb, ezért a mérés **font-független** (a konstansokra mérünk).
    const available360 = 360 - 36;
    final labelBudget = available360 - homeHeaderFixedWidth - homeCommunityButtonChrome;
    expect(
      labelBudget,
      greaterThanOrEqualTo(80),
      reason: 'a Community feliratra csak $labelBudget px marad 360 px-en',
    );
  });
}
