import 'package:flutter/material.dart';

class AchievementGuideScreen extends StatelessWidget {
  const AchievementGuideScreen({super.key});

  static const _levels = <({int points, String name, String description})>[
    (
      points: 0,
      name: 'Kezdő ütem',
      description: 'Alapjelvény minden regisztrált felhasználónak.',
    ),
    (
      points: 100,
      name: 'Első lépés',
      description: 'Az első közösségi mérföldkő.',
    ),
    (
      points: 300,
      name: 'Rendszeres látogató',
      description: 'Rendszeresen jelen van a közösségben.',
    ),
    (
      points: 700,
      name: 'Hardstyle arc',
      description: 'Láthatóan aktív HUHS-közösségi tag.',
    ),
    (
      points: 1500,
      name: 'Közösségi ember',
      description: 'Sokat tesz a közösségi jelenlétért.',
    ),
    (
      points: 3000,
      name: 'Scene veteran',
      description: 'Hosszú távon aktív színtértag.',
    ),
    (
      points: 6000,
      name: 'HUHS legenda',
      description: 'Kiemelkedő, tartós közösségi aktivitás.',
    ),
  ];

  static const _activities = <({String title, String points, String detail})>[
    (
      title: 'Eseményen ott leszek',
      points: '+10 pont',
      detail: 'Egy eseményre egyszer jár pont.',
    ),
    (
      title: 'Meetup jelzés',
      points: '+5 pont',
      detail: 'A meetupot csak egyszer számítjuk.',
    ),
    (
      title: 'Kölcsönös kapcsolat meetupolóval',
      points: '+15 pont',
      detail: 'Csak valódi, kölcsönös kapcsolat után jár.',
    ),
    (
      title: 'Esemény utáni értékelés',
      points: '+10 pont',
      detail: 'Egy eseményhez egyszer adható jóváírás.',
    ),
    (
      title: 'Hír kedvelése',
      points: '+2 pont',
      detail: 'A saját reakciód visszavonásakor a pont is visszavonódik.',
    ),
    (
      title: 'Közösségi aktivitás',
      points: '+5–20 pont',
      detail: 'Az ellenőrzött, hasznos aktivitás típusától függ.',
    ),
    (
      title: 'Profil kitöltése',
      points: '+30 pont',
      detail: 'Egyszeri jóváírás a teljes profilért.',
    ),
    (
      title: 'Meghívott regisztrációja',
      points: '+50 pont',
      detail: 'Új regisztráció után, szerveroldali ellenőrzéssel.',
    ),
    (
      title: 'Kiadvány megvásárlása',
      points: '+20 pont',
      detail: 'A vásárlást a szerver ellenőrzi.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievement rendszer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),
          const _SectionTitle('Szintek és jelvények'),
          const SizedBox(height: 8),
          ..._levels.map((level) => _LevelTile(level: level)),
          const SizedBox(height: 18),
          const _SectionTitle('Miért jár pont?'),
          const SizedBox(height: 8),
          ..._activities.map((activity) => _ActivityTile(activity: activity)),
          const SizedBox(height: 18),
          const _SectionTitle('Fontos szabályok'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'A pontokat a rendszer szerveroldalon ellenőrzi és idempotensen könyveli. '
                'Ugyanazt a tevékenységet nem lehet ismételten farmolni, a visszavont aktivitás pontja is visszavonható. '
                'A rangodhoz mindig a legmagasabb elért szint jelvénye tartozik.',
                style: Theme.of(context).textTheme.bodyLarge,
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
                'A jelvények grafikáit a HUHS adminisztrátora tölti fel és kezeli. Az alkalmazás nem generál véletlenszerű vagy AI-jelvényeket.',
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
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _LevelTile extends StatelessWidget {
  final ({int points, String name, String description}) level;
  const _LevelTile({required this.level});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE53935),
        child: Text(
          '${level.points}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      title: Text(
        level.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${level.points} pont • ${level.description}'),
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
