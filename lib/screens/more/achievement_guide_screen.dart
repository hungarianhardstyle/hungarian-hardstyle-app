import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/achievement_provider.dart';
import '../../services/achievement_service.dart';

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
  static const activities = <({String title, String points, String detail})>[
    (
      title: 'Eseményen ott leszek',
      points: '+10 pont',
      detail:
          'Eseményenként egyszer jár. Amíg jelentkezve vagy rá, addig érvényes: ha lemondod, a pont elvész, visszajelentkezésnél újra jár.',
    ),
    (
      title: 'Meetup jelzés',
      points: '+5 pont',
      detail:
          'Meetuponként egyszer jár. Ha lemondod a jelzést, ez a pont is elvész, visszajelzésnél újra jár.',
    ),
    (
      title: 'Kölcsönös kapcsolat meetupolóval',
      points: '+15 pont',
      detail:
          'Eseményenként és kapcsolatonként jár, ha valódi, kölcsönös kapcsolat születik. Ha a kapcsolat megszűnik, a pont is elvész.',
    ),
    (
      title: 'Esemény utáni értékelés',
      points: '+10 pont',
      detail: 'Eseményenként egyszer adható.',
    ),
    (
      title: 'Hír kedvelése',
      points: '+2 pont',
      detail:
          'Naponta legfeljebb 3 hír kedveléséért jár pont. A pont végleges: ha kiveszed a lájkot, megmarad, de újralájk sem ad újat.',
    ),
    (
      title: 'Napi aktivitási pont',
      points: '+1–5 pont',
      detail:
          'Ha aznap hozzászólsz egy cikkhez vagy írsz a chatbe, a következő napon a szerver kiszámolja, mennyit voltál aktív, és 1–5 pontot ad érte. Naponta egyszer.',
    ),
    (
      title: 'Cikk kommentelése',
      points: '+1 pont',
      detail: 'Naponta legfeljebb 3 elküldött cikkkommentért jár pont.',
    ),
    (
      title: 'Éves HUHS szavazás',
      points: '+10 pont',
      detail:
          'A teljes, minden kötelező kategóriát tartalmazó szavazólap után jár (bejelentkezve).',
    ),
    (
      title: 'Kiadvány megvásárlása',
      points: '+20 pont',
      detail:
          'Minden megvásárolt változatért (MP3/WAV) jár. A vásárlást a Google Play ellenőrzi, ezért nem lehet hamisítani.',
    ),
    (
      title: 'Jóváhagyott beküldés',
      points: '+10 pont',
      detail:
          'Beküldött esemény, DJ vagy szervező: a pont a jóváhagyáskor jár. Naponta legfeljebb 3 jóváhagyott beküldésért.',
    ),
    (
      title: 'Profil kitöltése',
      points: '+30 pont',
      detail: 'Egyszeri jóváírás a teljes profilért (név, bemutatkozás, egyező e-mail).',
    ),
    (
      title: 'Meghívott regisztrációja',
      points: '+50 pont',
      detail: 'Új regisztráció után, szerveroldali ellenőrzéssel.',
    ),
    (
      title: 'HUHS játékok',
      points: 'a játék jutalma',
      detail:
          'A játékhoz beállított jutalom: kvíznél a helyes válaszok aránya szerint sávokban, más játéktípusnál csak teljes pontszámért.',
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
      appBar: AppBar(title: const Text('Achievement rendszer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),
          const _SectionTitle('Szintek és jelvények'),
          const SizedBox(height: 8),
          ...?levels?.map((level) => _LevelTile(level: level)),
          const SizedBox(height: 18),
          const _SectionTitle('Miért jár pont?'),
          const SizedBox(height: 8),
          ...activities.map((activity) => _ActivityTile(activity: activity)),
          const SizedBox(height: 18),
          const _SectionTitle('Fontos szabályok'),
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
                      child: Text(
                        '•  $rule',
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
              title: const Text('Megjelenés'),
              subtitle: const Text(
                'A jelvényed a profilodon látható. A chatben a neve mellett is megjeleníthető, ha ezt a Beállításokban engedélyezed.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Jelvénygrafikák'),
              subtitle: const Text(
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
      child: Text(
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
      title: Text(
        level.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        level.description.isEmpty
            ? '${level.minPoints} ponttól'
            : '${level.minPoints} pont • ${level.description}',
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
      title: Text(activity.title),
      subtitle: Text(activity.detail),
      trailing: Text(
        activity.points,
        style: const TextStyle(
          color: Color(0xFFF03A37),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
