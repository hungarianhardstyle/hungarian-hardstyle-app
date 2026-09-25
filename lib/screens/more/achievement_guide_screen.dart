import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_strings.dart';
import '../../providers/achievement_provider.dart';
import '../../services/achievement_service.dart';
import '../../core/i18n/tr.dart';
import '../../widgets/app_text.dart';

/// `Több → Achievementek`: hogyan működik a pontrendszer.
///
/// **A szövegek a valós működést írják le** — ezt a
/// `tools/verify-achievement-guide.mjs` kapu köti a szerver kódjához
/// (`functions/index.js`), hogy ne avulhasson el újra csendben. A korábbi
/// változat még azt írta, hogy a lájk visszavonásakor elvész a pont (ez már nem
/// igaz), hogy a kommentért naponta **5** jár (valójában **3**), és szerepelt
/// benne két olyan sor, ami mögött nem volt szabály.
class AchievementGuideScreen extends ConsumerWidget {
  const AchievementGuideScreen({super.key});

  /// A pontforrások. A `points` a jobb oldali kiemelt érték.
  static final activities = <({String title, String points, String detail})>[
    (
      title: AppStrings.tr('Eseményen ott leszek'),
      points: AppStrings.tr('+10 pont'),
      detail:
          AppStrings.tr('Eseményenként egyszer jár. Amíg jelentkezve vagy rá, addig érvényes: ha lemondod, a pont elvész, visszajelentkezésnél újra jár.'),
    ),
    (
      title: AppStrings.tr('Meetup jelzés'),
      points: AppStrings.tr('+5 pont'),
      detail:
          AppStrings.tr('Meetuponként egyszer jár. Ha lemondod a jelzést, ez a pont is elvész, visszajelzésnél újra jár.'),
    ),
    (
      title: AppStrings.tr('Kölcsönös kapcsolat meetupolóval'),
      points: AppStrings.tr('+15 pont'),
      detail:
          AppStrings.tr('Eseményenként és kapcsolatonként jár, ha valódi, kölcsönös kapcsolat születik. Ha a kapcsolat megszűnik, a pont is elvész.'),
    ),
    (
      title: AppStrings.tr('Esemény utáni értékelés'),
      points: AppStrings.tr('+10 pont'),
      detail: AppStrings.tr('Eseményenként egyszer adható.'),
    ),
    (
      title: AppStrings.tr('Hír kedvelése'),
      points: AppStrings.tr('+2 pont'),
      detail:
          AppStrings.tr('Naponta legfeljebb 3 hír kedveléséért jár pont. A pont végleges: ha kiveszed a lájkot, megmarad, de újralájk sem ad újat.'),
    ),
    (
      title: AppStrings.tr('Napi aktivitási pont'),
      points: AppStrings.tr('+1–5 pont'),
      detail:
          AppStrings.tr('Ha aznap hozzászólsz egy cikkhez vagy írsz a chatbe, a következő napon a szerver kiszámolja, mennyit voltál aktív, és 1–5 pontot ad érte. Naponta egyszer.'),
    ),
    (
      title: AppStrings.tr('Cikk kommentelése'),
      points: AppStrings.tr('+1 pont'),
      detail: AppStrings.tr('Naponta legfeljebb 3 elküldött cikkkommentért jár pont.'),
    ),
    (
      title: AppStrings.tr('Éves HUHS szavazás'),
      points: AppStrings.tr('+10 pont'),
      detail:
          AppStrings.tr('A teljes, minden kötelező kategóriát tartalmazó szavazólap után jár (bejelentkezve).'),
    ),
    (
      title: AppStrings.tr('Kiadvány megvásárlása'),
      points: AppStrings.tr('+20 pont'),
      detail:
          AppStrings.tr('Minden megvásárolt változatért (MP3/WAV) jár. A vásárlást a Google Play ellenőrzi, ezért nem lehet hamisítani.'),
    ),
    (
      title: AppStrings.tr('Jóváhagyott beküldés'),
      points: AppStrings.tr('+10 pont'),
      detail:
          AppStrings.tr('Eseményt szervező, DJ-t DJ, szervezőt szervező küldhet be; a pont a jóváhagyáskor jár a beküldőnek. Naponta legfeljebb 3 jóváhagyott beküldésért.'),
    ),
    (
      title: AppStrings.tr('Profil kitöltése'),
      points: AppStrings.tr('+30 pont'),
      detail: AppStrings.tr('Egyszeri jóváírás a teljes profilért (név, bemutatkozás, egyező e-mail).'),
    ),
    (
      title: AppStrings.tr('Meghívott regisztrációja'),
      points: AppStrings.tr('+50 pont'),
      detail: AppStrings.tr('Új regisztráció után, szerveroldali ellenőrzéssel.'),
    ),
    (
      title: AppStrings.tr('HUHS játékok'),
      points: AppStrings.tr('a játék jutalma'),
      detail:
          AppStrings.tr('A játékhoz beállított jutalom: kvíznél a helyes válaszok aránya szerint sávokban, más játéktípusnál csak teljes pontszámért.'),
    ),
  ];

  /// A szabályok, érthetően (technikai zsargon nélkül).
  static const rules = <String>[
    'Ugyanazért a tevékenységért egyszer jár pont — a rendszer mindig a szerveren ellenőrzi.',
    'A hír kedveléséért és a cikkkommentért naponta legfeljebb 3-3 alkalommal jár pont, a jóváhagyott beküldésekért szintén 3.',
    'A napi aktivitási pont (1–5) a lezárt nap után, naponta egyszer jár: a szerver a cikkhez írt hozzászólásaidból és a chat-üzeneteidből számolja.',
    'A lájkpont végleges: ha kiveszed a lájkot, a pont megmarad, de az újralájk sem ad újat.',
    'Az esemény- és meetup-pont eseményenként (meetuponként) egyszer jár, és a jelentkezésedhez igazodik: lemondásnál elvész, visszajelentkezésnél újra jár.',
    'A rangod mindig a legmagasabb elért szinted jelvénye.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A szintek a szerverről (WordPress-katalógus) jönnek; hálózat nélkül a
    // beépített tartalék lista jelenik meg, ezért ez a képernyő nem tud üres
    // lenni.
    final levels = ref.watch(achievementLevelsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const AppText('Achievement rendszer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),
          _SectionTitle(tr(context, 'Szintek és jelvények')),
          const SizedBox(height: 8),
          ...?levels?.map((level) => _LevelTile(level: level)),
          const SizedBox(height: 18),
          _SectionTitle(tr(context, 'Miért jár pont?')),
          const SizedBox(height: 8),
          ...activities.map((activity) => _ActivityTile(activity: activity)),
          const SizedBox(height: 18),
          _SectionTitle(tr(context, 'Fontos szabályok')),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      // ⚠️ A szabály a `const` listában magyar kulcs; a fordítás a
                      // MEGJELENÍTÉS helyén történik (a `const` listában nem lehet
                      // függvényt hívni), ezért itt fordítjuk a szöveget.
                      child: AppText(
                        '•  ${AppStrings.tr(rule)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const AppText('Megjelenés'),
              subtitle: const AppText(
                'A jelvényed a profilodon látható. A chatben a neve mellett is megjeleníthető, ha ezt a Beállításokban engedélyezed.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const AppText('Jelvénygrafikák'),
              subtitle: const AppText(
                'A jelvények grafikáit és a szintek pontszámait a HUHS adminisztrátora kezeli, ezért itt mindig a jelenlegi állapot látszik.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: AppText(
        'Az achievement rendszerben a HUHS közösségben végzett valódi aktivitásért pontokat szerezhetsz. A pontszámod alapján rangot és grafikus jelvényt kapsz.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _LevelTile extends StatelessWidget {
  final AchievementLevel level;
  const _LevelTile({required this.level});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE53935),
        child: Text(
          '${level.minPoints}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      title: AppText(
        level.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: AppText(
        level.description.isEmpty
            ? trArgs(context, '{n} ponttól', {'n': '${level.minPoints}'})
            : trArgs(context, '{n} pont • {d}', {
                'n': '${level.minPoints}',
                'd': level.description,
              }),
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  final ({String title, String points, String detail}) activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: AppText(activity.title),
      subtitle: AppText(activity.detail),
      trailing: AppText(
        activity.points,
        style: const TextStyle(
          color: Color(0xFFF03A37),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
