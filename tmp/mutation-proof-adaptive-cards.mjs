#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a SZÉLES NÉZETŰ KÁRTYÁKHOZ és a Twitch-kártya képéhez (397, 2026-10-03).
 *
 * MIÉRT: a tulajdonos jelzése — *„Fekvő módban és tableten fekvő módban a friss
 * hírek kártya és a twitch beharangozó túl nagy. Álló módban jó!”* — és a kérése:
 * *„ha elindul egy twitch stream, akkor a beharangozó kép helyett mehetne a
 * stream mozgóképe a főoldalon.”*
 *
 * Ez a bizonyíték azt méri, hogy az új kapuk **tényleg elkapják** a régi (hibás)
 * viselkedést — a bukó teszt nevével, nem csak a „nem fut le” ténnyel.
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-adaptive-cards.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

// ⚠️ MÉRT ESZKÖZ-HIBA: `execFileSync('flutter')` = ENOENT, `'flutter.bat'` =
// EINVAL → a helyes út a `cmd /c flutter test …`.
const FLUTTER = 'cmd';
const NEWS = 'lib/widgets/news_card.dart';
const TWITCH_CARD = 'lib/widgets/twitch_live_card.dart';
const TWITCH_LIVE = 'lib/services/twitch_live.dart';
const LAYOUT = 'lib/services/adaptive_card_layout.dart';
const HOME = 'lib/screens/home/home_screen.dart';
const FEATURED = 'lib/widgets/featured_news_card.dart';

const SERVICE_TEST = 'test/services/adaptive_card_layout_test.dart';
const CARD_TEST = 'test/widgets/twitch_live_card_test.dart';
const HOME_TEST = 'test/widgets/home_landscape_cards_test.dart';

const WIDE_NEWS_TEST = 'tablet állóban (800 px) legfeljebb 760 px széles';
const PHONE_NEWS_TEST = 'álló telefonon teljes szélességű marad (ez volt jó)';
const PURE_TABLET_TEST = 'tablet ÁLLÓBAN is széles — ez maradt ki a régi szabályból';
const TWITCH_WIDTH_TEST = 'széles (fekvő/tablet) nézetben a kártya legfeljebb 760 px széles';
const MOVING_IMAGE_TEST = 'élő adásnál a MOZGÓ streamkép megy a beharangozó kép HELYETT';
const NEWS_LINT = 'a hírkártya a szélesség alapján dönt (nem a tájolás szerint)';
const HERO_LANDSCAPE_TEST = 'FEKVŐ iPhone: a kiemelt hír nem lehet a teljes képernyőmagasság';
const HERO_DENSE_TEST = 'fekvő (alacsony) nézetben kevesebb cím-sor jut a kiemelt hírre';
const TABLET_TEST = 'FEKVŐ tablet: a kártyák középre igazítva, korlátozottan';
const PORTRAIT_TEST = 'ÁLLÓ iPhone: változatlan (a tulajdonos szerint ez jó)';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [NEWS, TWITCH_CARD, TWITCH_LIVE, LAYOUT, HOME, FEATURED, SERVICE_TEST, CARD_TEST, HOME_TEST];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések ([mit cserélünk, mire]), melyik teszt bukjon] */
const mutations = [
  [
    'a hírkártya megint a TÁJOLÁSRA dönt (a tablet álló nézete kimarad — a régi hiba)',
    NEWS,
    [[
      '    final maxWidth = cardMaxWidthFor(MediaQuery.sizeOf(context));',
      '    final maxWidth = MediaQuery.orientationOf(context) == Orientation.landscape\n'
      + '        ? wideCardMaxWidth\n'
      + '        : double.infinity;',
    ]],
    WIDE_NEWS_TEST,
  ],
  [
    'a hírkártya MINDIG teljes szélességű (a széles nézet korlátja elvéve)',
    NEWS,
    [['    final maxWidth = cardMaxWidthFor(MediaQuery.sizeOf(context));', '    const double maxWidth = double.infinity;']],
    WIDE_NEWS_TEST,
  ],
  [
    'a hírkártya széles nézetben is a NAGY (nem sávos) változat (compact elvéve)',
    NEWS,
    [['compact: maxWidth != double.infinity', 'compact: false']],
    NEWS_LINT,
  ],
  [
    'a Twitch-kártya MAGASSÁG-KORLÁTJA elvéve (fekvő/tablet nézetben óriási)',
    TWITCH_CARD,
    [['        constraints: BoxConstraints(maxWidth: maxWidth),', '        constraints: const BoxConstraints(maxWidth: double.infinity),']],
    TWITCH_WIDTH_TEST,
  ],
  [
    'a Twitch-kártya NEM a tiszta képi döntést használja (élő adásnál is a beharangozó kép)',
    TWITCH_CARD,
    [[
      `    final imageUrl = twitchCardImageUrl(
      isLive: isLive,
      liveThumbnailUrl: live?.thumbnailUrl ?? '',
      overrideImageUrl: override?.displayImageUrl ?? '',
      tick: _imageTick,
    );`,
      '    final imageUrl = override?.displayImageUrl ?? \'\';',
    ]],
    MOVING_IMAGE_TEST,
  ],
  [
    'a képi döntés MINDIG a beharangozó képet adja (a mozgó streamkép elveszne)',
    TWITCH_LIVE,
    [[
      `  final live = liveThumbnailUrl.trim();
  if (isLive && live.isNotEmpty) {
    final separator = live.contains('?') ? '&' : '?';
    return '$live\${separator}tick=$tick';
  }
  return overrideImageUrl.trim();`,
      '  return overrideImageUrl.trim();',
    ]],
    MOVING_IMAGE_TEST,
  ],
  [
    'a szélesség-küszöb 900 px (a 800 px-es tablet álló nézete kimarad)',
    LAYOUT,
    [['const double wideLayoutMinWidth = 700;', 'const double wideLayoutMinWidth = 900;']],
    PURE_TABLET_TEST,
  ],
  [
    'álló telefonon is korlátozott a kártya (a tulajdonos szerint az álló nézet JÓ volt)',
    LAYOUT,
    [['    isWideCardLayout(size) ? wideCardMaxWidth : double.infinity;', '    wideCardMaxWidth;']],
    PHONE_NEWS_TEST,
  ],
  // ——— 2026-10-03: a főoldali kiemelt hír és a Twitch-kártya fekvő nézetben -——
  [
    'a kiemelt hír MEGINT a saját (régi) méretét használja — a teljes képernyőmagasság',
    HOME,
    [[
      `        final card = heroCardSizeFor(
          viewport: viewport,
          availableWidth: constraints.maxWidth,
        );`,
      `        final cardWidth = constraints.maxWidth.clamp(0.0, 820.0);
        final cardHeight = (cardWidth * 9 / 16).clamp(250.0, 460.0);
        final card = (width: cardWidth, height: cardHeight);`,
    ]],
    HERO_LANDSCAPE_TEST,
  ],
  [
    'a MAGASSÁG-korlát elvéve (a kártya újra a képernyő magasságát veszi fel)',
    LAYOUT,
    [['const double wideCardHeightFraction = 0.55;', 'const double wideCardHeightFraction = 1.0;']],
    HERO_LANDSCAPE_TEST,
  ],
  [
    'a Twitch-kártya fekvő nézetben is az ÁLLÓ (nagy) elrendezést kapja',
    TWITCH_CARD,
    [['    final wide = isWideCardLayout(viewport);', '    const wide = false;']],
    HERO_LANDSCAPE_TEST,
  ],
  [
    'a kiemelt hír címére széles nézetben is 4 sor jut (kifutna a kártyából)',
    FEATURED,
    [['                      maxLines: dense ? 2 : 4,', '                      maxLines: 4,']],
    HERO_DENSE_TEST,
  ],
  [
    'a tablet kártyáit is a képernyő magassága korlátozza (a méret nem lehet kicsi)',
    HOME,
    [[
      `        final card = heroCardSizeFor(
          viewport: viewport,
          availableWidth: constraints.maxWidth,
        );`,
      `        final natural = heroCardSizeFor(
          viewport: viewport,
          availableWidth: constraints.maxWidth,
        );
        final card = (
          width: natural.width,
          height: wide ? natural.height * 0.4 : natural.height,
        );`,
    ]],
    TABLET_TEST,
  ],
  [
    'a MAGASSÁG-korlát az ÁLLÓ nézetre is bekapcsol (a tulajdonos szerint az jó volt)',
    LAYOUT,
    [[
      `double wideCardMaxHeightFor(Size size) => isWideCardLayout(size)
    ? size.height * wideCardHeightFraction
    : double.infinity;`,
      'double wideCardMaxHeightFor(Size size) => size.height * wideCardHeightFraction;',
    ]],
    PORTRAIT_TEST,
  ],
];

const failures = [];
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

let caught = 0;
for (const [index, [title, file, steps, expectedFailure]] of mutations.entries()) {
  const source = fs.readFileSync(file, 'utf8');
  let mutated = source;
  let applies = true;
  for (const [from, to] of steps) {
    if (!mutated.includes(from)) {
      applies = false;
      break;
    }
    mutated = mutated.replace(from, to);
  }
  if (!applies) {
    say(`ELTÉR  ${title} — a minta nem illik a forrásra (a bizonyíték érvénytelen)`);
    failures.push(title);
    continue;
  }
  fs.writeFileSync(file, mutated, 'utf8');
  let output = '';
  let failed = false;
  try {
    output = execFileSync(FLUTTER, ['/c', 'flutter', 'test', SERVICE_TEST, CARD_TEST, HOME_TEST], {
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  } finally {
    fs.writeFileSync(file, source, 'utf8');
  }
  const named = output.includes(expectedFailure);
  if (failed && named) {
    caught += 1;
    say(`OK     ${title} → a kapu elcsípte («${expectedFailure}»)`);
  } else {
    failures.push(title);
    say(`ELTÉR  ${title} → NEM bukott el a várt teszt («${expectedFailure}»), failed=${failed}`);
    for (const line of output.split(/\r?\n/).filter((entry) => /\[E\]|Expected:|Actual:/.test(entry)).slice(0, 4)) {
      say(`       ${line.trim().slice(0, 160)}`);
    }
  }
  if (index === 0) say('       (az első futás felmelegíti a fordítót, ezért lassabb)');
}

const after = Object.fromEntries(targets.map((file) => [file, digest(file)]));
const untouched = targets.every((file) => before[file] === after[file]);
say(`\n${caught}/${mutations.length} mutáció ELKAPVA`);
say(`a források ${untouched ? 'BÁJTAZONOSAK (érintetlenek)' : 'MEGVÁLTOZTAK — HIBA!'}`);
fs.writeFileSync('tmp/mutation-adaptive-cards-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
