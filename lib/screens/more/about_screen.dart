import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/tr.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../data/app_changelog.dart';
import '../../models/release.dart';
import '../../providers/releases_provider.dart';
import '../../services/label_purchase_service.dart';
import '../../services/purchase_diagnostics_plan.dart';
import '../../widgets/app_text.dart';

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
      appBar: AppBar(title: const AppText('Az appról')),
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
                  ? tr(context, 'Verzió betöltése…')
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
                  const AppText(
                    'Hungarian Hardstyle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Magyar hardstyle és hardcore közösségi app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _InfoTile(
                    icon: Icons.info_outline,
                    label: tr(context, 'Verzió'),
                    value: version,
                  ),
                  _InfoTile(
                    icon: Icons.language,
                    label: tr(context, 'Weboldal'),
                    value: 'hungarianhardstyle.hu',
                    onTap: () => openInAppBrowser(
                      context,
                      'https://hungarianhardstyle.hu',
                    ),
                  ),
                  _InfoTile(
                    icon: Icons.mail_outline,
                    label: tr(context, 'Kapcsolat'),
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
                  const SizedBox(height: 18),
                  _PurchaseDiagnostics(
                    currentVersion: info == null
                        ? ''
                        : '${info.version}+${info.buildNumber}',
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
        const AppText(
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
                    ? tr(context, 'A kiadási jegyzet betöltése…')
                    : 'Ehhez a verzióhoz ($currentBuild) még nincs kiadási jegyzet.',
              ),
            ),
          )
        else
          _ReleaseCard(note: current, current: true),
        if (older.isNotEmpty) ...[
          const SizedBox(height: 18),
          AppText(
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
                    child: AppText(
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

/// **Vásárlási diagnosztika** — mit válaszol a Google Play **ezen a készüléken**?
///
/// MIÉRT VAN EZ: a 2026-09-22-i ország-hibánál („A tétel nem áll rendelkezésre az
/// adott országban") a hibaüzenetet a **Play saját ablaka** írta ki, a kódunk
/// pedig **nem látta** sem a nyers hibakódot, sem azt, hogy a Play egyáltalán
/// visszaadta-e a terméket. Emiatt több körön át **következtetni** kellett —
/// és pont a lényeg maradt láthatatlan. Ez a szakasz azt a hiányzó műszert adja:
/// egy gomb megmutatja a friss, nyers Play-választ (hány termék, milyen áron és
/// **pénznemben**), és a legutóbbi vásárlási hiba **kódját** — a szöveget pedig
/// egy mozdulattal a vágólapra lehet tenni és elküldeni.
///
/// ⚠️ Nem indít vásárlást és nem ír semmit: kizárólag olvas.
class _PurchaseDiagnostics extends ConsumerStatefulWidget {
  const _PurchaseDiagnostics({required this.currentVersion});

  final String currentVersion;

  @override
  ConsumerState<_PurchaseDiagnostics> createState() =>
      _PurchaseDiagnosticsState();
}

class _PurchaseDiagnosticsState extends ConsumerState<_PurchaseDiagnostics> {
  bool _running = false;
  String? _problem;
  PurchaseDiagnosticsInput? _result;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _problem = null;
    });
    try {
      List<HuhsRelease> releases;
      try {
        releases = await ref.read(
          releasesProvider((search: '', artistId: 0)).future,
        );
      } catch (_) {
        releases = const <HuhsRelease>[];
      }
      final ids = releases
          .expand((release) => release.products.map((product) => product.id))
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      if (ids.isEmpty) {
        if (mounted) {
          setState(
            () => _problem =
                'A kiadvány-katalógus nem töltődött be, ezért nincs mit '
                'lekérdezni. Ellenőrizd az internetkapcsolatot, és próbáld újra.',
          );
        }
        return;
      }
      final result = await LabelPurchaseService.shared.diagnose(
        ids,
        platform: defaultTargetPlatform.name,
        appVersion: widget.currentVersion,
        accountEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      );
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _copy() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(
      ClipboardData(text: purchaseDiagnosticsText(result)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: AppText('A diagnosztika a vágólapra került.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final verdict = result == null
        ? null
        : purchaseDiagnosticsVerdict(result);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Vásárlási diagnosztika',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            AppText(
              'Ha a vásárlás nem indul el, ez megmutatja, mit válaszol a Google '
              'Play ezen a készüléken: hány terméket ad vissza, milyen áron és '
              'pénznemben, és mi volt a legutóbbi vásárlási hiba kódja.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                  label: Text(
                    _running ? 'Mérés…' : tr(context, 'Diagnosztika futtatása'),
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const AppText('Másolás'),
                  ),
                ],
              ],
            ),
            if (_problem != null) ...[
              const SizedBox(height: 12),
              Text(
                _problem!,
                style: const TextStyle(color: Color(0xFFFFB74D)),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              AppText(
                purchaseDiagnosticsVerdictText(verdict!),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SelectableText(
                    purchaseDiagnosticsText(result),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
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
