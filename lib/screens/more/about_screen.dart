import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/in_app_browser.dart';
import '../../data/app_changelog.dart';

/// Az app adatai és a kiadási jegyzet (changelog).
///
/// A tulajdonos kérése: *„az appról részbe legyen changelog is"*. A szöveg
/// forrása a `lib/data/app_changelog.dart`, amit a
/// `docs/RELEASE_CHANGELOG_CHECKLIST.md` szerint a Play-jegyzettel együtt kell
/// vezetni.
///
/// A verziót a `package_info_plus` adja (a `pubspec.yaml`-ból), ezért a
/// changelogban **nem** a verziót, hanem a **buildszámot** használjuk a
/// párosításhoz: az a Play verziókódja, és pontosan azonosítja a kiadást.
///
/// [packageInfo] csak a teszteléshez van: élesben a `PackageInfo.fromPlatform()`
/// fut, de a platformcsatorna nélküli widget-teszt így tudja beadni az adatot.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.packageInfo});

  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Az appról')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<PackageInfo>(
            future: packageInfo == null
                ? PackageInfo.fromPlatform()
                : Future<PackageInfo>.value(packageInfo),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? 'Verzió betöltése…'
                  : '${info.version}+${info.buildNumber}';
              final currentBuild = info == null
                  ? null
                  : int.tryParse(info.buildNumber);

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    size: 72,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hungarian Hardstyle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Magyar hardstyle és hardcore közösségi app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _InfoTile(
                    icon: Icons.info_outline,
                    label: 'Verzió',
                    value: version,
                  ),
                  _InfoTile(
                    icon: Icons.language,
                    label: 'Weboldal',
                    value: 'hungarianhardstyle.hu',
                    onTap: () => openInAppBrowser(
                      context,
                      'https://hungarianhardstyle.hu',
                    ),
                  ),
                  _InfoTile(
                    icon: Icons.mail_outline,
                    label: 'Kapcsolat',
                    value: 'info@hungarianhardstyle.hu',
                    onTap: () => launchUrl(
                      Uri(scheme: 'mailto', path: 'info@hungarianhardstyle.hu'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Changelog(
                    currentBuild: currentBuild,
                    currentVersion: info?.version,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A kiadási jegyzet: az aktuális kiadás kiemelve, alatta a korábbiak.
class _Changelog extends StatelessWidget {
  const _Changelog({required this.currentBuild, required this.currentVersion});

  final int? currentBuild;
  final String? currentVersion;

  @override
  Widget build(BuildContext context) {
    final notes = sortedChangelog(appChangelog);
    final current = currentBuild == null
        ? null
        : releaseNotesForBuild(notes, currentBuild!);
    final older = notes
        .where((note) => note.build != current?.build)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Újdonságok',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (current == null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                currentBuild == null
                    ? 'A kiadási jegyzet betöltése…'
                    : 'Ehhez a verzióhoz ($currentBuild) még nincs kiadási jegyzet.',
              ),
            ),
          )
        else
          _ReleaseCard(note: current, current: true),
        if (older.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Korábbi kiadások',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          for (final note in older) _ReleaseCard(note: note, current: false),
        ],
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.note, required this.current});

  final AppReleaseNotes note;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: current
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${note.version}+${note.build}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: current ? 16 : 14,
                    ),
                  ),
                ),
                if (current)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ez a verzió',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final change in note.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(child: Text(change)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap == null ? null : const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}
