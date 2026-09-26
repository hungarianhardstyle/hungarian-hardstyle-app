import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
import '../../providers/community_provider.dart';
import '../../services/submission_rules.dart';
import '../../widgets/app_text.dart';
import '../../widgets/huhs_corner_logo.dart';
import '../artists/artists_screen.dart';
import '../organizers/organizers_screen.dart';
import '../submissions/artist_submission_screen.dart';
import '../submissions/organizer_submission_screen.dart';
import 'about_screen.dart';
import 'achievement_guide_screen.dart';
import 'achievement_leaderboard_screen.dart';
import 'donate_screen.dart';
import 'faq_screen.dart';
import 'my_music_screen.dart';
import 'privacy_screen.dart';
import 'referral_screen.dart';
import 'radio_provider_screen.dart';
import 'settings_screen.dart';
import 'social_contact_screen.dart';
import 'spotify_playlists_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final _search = TextEditingController();
  final _expanded = <String>{
    AppStrings.tr('Megvásárolt zenéim'),
    AppStrings.tr('Felfedezés'),
    AppStrings.tr('Beküldés'),
    AppStrings.tr('Kapcsolat és támogatás'),
    AppStrings.tr('Alkalmazás'),
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String title, String subtitle) {
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty || '$title $subtitle'.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(communityServiceProvider);
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final registered = user != null && !user.isAnonymous;
    final role = service.cachedAccountRole;
    // A szerepkör-szabály EGY helyen él (`SubmissionRules`), és ugyanaz, mint a
    // szerveren — így a gomb és a szerver-kapu nem tud elcsúszni.
    final canArtist = SubmissionRules.canSubmit(
      kind: 'artist',
      registered: registered,
      role: role,
      isAdmin: service.isAdmin,
    );
    final canOrganizer = SubmissionRules.canSubmit(
      kind: 'organizer',
      registered: registered,
      role: role,
      isAdmin: service.isAdmin,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            const Row(
              children: [
                Expanded(
                  child: AppText(
                    'Több',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                HuhsCornerLogo(),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: tr(context, 'Keresés a Több menüben'),
                hintText: tr(context, 'Akár egy karakterrel'),
              ),
            ),
            const SizedBox(height: 14),
            _section(tr(context, 'Megvásárolt zenéim'), [
              // A tulajdonos kérése: a megvásárolt (vagy reklámmal feloldott)
              // zenékhez **saját, fiókhoz kötött** menüpont, ahol lejátszhatók
              // (a szám végén a következőre lépve) és újra letölthetők.
              // A szakasz nyitva indul, mint a többi — különben csukott kártyaként
              // kilógna a „Több" menü megszokott kinézetéből.
              if (registered)
                _item(
                  Icons.library_music_outlined,
                  tr(context, 'Lejátszás és letöltés'),
                  tr(context, 'A megvásárolt zenéid — a fiókodhoz kötve'),
                  const MyMusicScreen(),
                )
              else
                _notice(
                  tr(context, 'A megvásárolt zenéidhez jelentkezz be — a vásárlás a '
                  'fiókodhoz tartozik.'),
                ),
            ]),
            _section(tr(context, 'Felfedezés'), [
              _item(
                Icons.graphic_eq,
                // ⚠️ A tulajdonos jelzése (2026-09-26): „a menüben a DJ-k az
                // elég magyar" — ez az EGYETLEN menüpont volt, aminek a felirata
                // nem ment át a fordítón (a szótárban már benne volt: DJ-k → DJs).
                tr(context, 'DJ-k'),
                tr(context, 'Magyar hardstyle és hardcore előadók'),
                const ArtistsScreen(),
              ),
              _item(
                Icons.groups,
                tr(context, 'Szervezők'),
                tr(context, 'Hazai eseményszervezők és sorozatok'),
                const OrganizersScreen(),
              ),
              _item(
                Icons.queue_music_outlined,
                tr(context, 'Spotify Playlistek'),
                tr(context, 'Válogatások a keményebb stílusokból'),
                const SpotifyPlaylistsScreen(),
              ),
            ]),
            _section(tr(context, 'Beküldés'), [
              if (canArtist)
                _item(
                  Icons.person_add_alt_1,
                  tr(context, 'DJ beküldése'),
                  tr(context, 'Új DJ-adatlap jóváhagyásra'),
                  const ArtistSubmissionScreen(),
                ),
              if (canOrganizer)
                _item(
                  Icons.add_business,
                  tr(context, 'Szervező beküldése'),
                  tr(context, 'Új szervező jóváhagyásra'),
                  const OrganizerSubmissionScreen(),
                ),
              if (!canArtist && !canOrganizer)
                _notice(
                  registered
                      ? SubmissionRules.notice
                      : tr(context, 'A beküldés csak regisztrált felhasználóknak érhető el.'),
                ),
            ]),
            _section(tr(context, 'Kapcsolat és támogatás'), [
              _item(
                Icons.share_outlined,
                tr(context, 'Social és kapcsolat'),
                tr(context, 'Közösségi oldalak és elérhetőségek'),
                const SocialContactScreen(),
              ),
              _item(
                Icons.favorite,
                tr(context, 'Támogatás / Donate'),
                tr(context, 'Segítsd a Hungarian Hardstyle munkáját'),
                const DonateScreen(),
              ),
              _callback(
                Icons.bug_report_outlined,
                tr(context, 'Hibajelzés'),
                tr(context, 'Hiba jelzése e-mailben, app-verzióval'),
                _sendFeedback,
              ),
              _item(
                Icons.help_outline,
                // ⚠️ A tulajdonos kérése (2026-09-26): *„az lehetne FAQ amúgy,
                // magyarba meg GYÍK"* — a magyar felirat **GYÍK**, az angol
                // fordítás **FAQ** (a szótár adja: `GYÍK → FAQ`).
                tr(context, 'GYÍK'),
                tr(context, 'Rövid válaszok az app használatához'),
                const FaqScreen(),
              ),
            ]),
            _section(tr(context, 'Alkalmazás'), [
              _item(
                Icons.leaderboard_outlined,
                tr(context, 'HUHS Legenda toplista'),
                tr(context, 'A legtöbb achievement pontot gyűjtő tagok'),
                const AchievementLeaderboardScreen(),
              ),
              _item(
                Icons.workspace_premium_outlined,
                tr(context, 'Achievementek'),
                tr(context, 'Pontok, szintek és jelvények részletesen'),
                const AchievementGuideScreen(),
              ),
              if (registered)
                _item(
                  Icons.group_add_outlined,
                  tr(context, 'Ajánlás'),
                  tr(context, 'Hívd meg ismerőseidet és szerezz 50 pontot'),
                  const ReferralScreen(),
                ),
              _item(
                Icons.settings_outlined,
                tr(context, 'Beállítások'),
                tr(context, 'Értesítések és gyorsítótár'),
                const SettingsScreen(),
              ),
              _item(
                Icons.privacy_tip_outlined,
                tr(context, 'Adatvédelem és GDPR'),
                tr(context, 'Adatkezelés, megőrzés és felhasználói jogok'),
                const PrivacyScreen(),
              ),
              _item(
                Icons.info_outline,
                tr(context, 'Az appról'),
                tr(context, 'Verzió, kapcsolat és weboldal'),
                const AboutScreen(),
              ),
              _item(
                Icons.radio,
                tr(context, 'Rádió szolgáltató'),
                tr(context, 'Real Hardstyle FM'),
                const RadioProviderScreen(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final visible = children.where((child) => child is! SizedBox).toList();
    final hasMatch = visible.any(
      (child) =>
          child is _MenuEntry && _matches(child.title, child.subtitle) ||
          child is _Notice,
    );
    if (_search.text.trim().isNotEmpty && !hasMatch) {
      return const SizedBox.shrink();
    }
    final open = _expanded.contains(title);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: open,
        onExpansionChanged: (value) => setState(
          () => value ? _expanded.add(title) : _expanded.remove(title),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        children: [
          for (final child in children)
            if (child is _MenuEntry && _matches(child.title, child.subtitle) ||
                child is _Notice)
              child,
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, String subtitle, Widget screen) =>
      _MenuEntry(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => _open(screen),
      );

  Widget _callback(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback callback,
  ) =>
      _MenuEntry(icon: icon, title: title, subtitle: subtitle, onTap: callback);

  Widget _notice(String text) => _Notice(text);

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _sendFeedback() async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';
    await launchUrl(
      Uri(
        scheme: 'mailto',
        path: 'info@hungarianhardstyle.hu',
        queryParameters: {
          'subject': 'Hibajelzés – Hungarian Hardstyle $version',
          'body': 'App verzió: $version\n\nHiba leírása:\n',
        },
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _MenuEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: Icon(icon, color: const Color(0xFFF03A37)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: AppText(text, style: const TextStyle(color: Colors.white70)),
  );
}
