import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/community_provider.dart';
import '../artists/artists_screen.dart';
import '../organizers/organizers_screen.dart';
import '../submissions/artist_submission_screen.dart';
import '../submissions/organizer_submission_screen.dart';
import 'about_screen.dart';
import 'community_users_screen.dart';
import 'donate_screen.dart';
import 'favorites_screen.dart';
import 'faq_screen.dart';
import 'newsletter_screen.dart';
import 'privacy_screen.dart';
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
    'Felfedezés',
    'Közösség',
    'Beküldés',
    'Kapcsolat és támogatás',
    'Alkalmazás',
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
    final canArtist = registered && (service.isAdmin || role == 'dj');
    final canOrganizer = registered && (service.isAdmin || role == 'organizer');
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            const Text(
              'Több',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Keresés a Több menüben',
                hintText: 'Akár egy karakterrel',
              ),
            ),
            const SizedBox(height: 14),
            _section('Felfedezés', [
              _item(
                Icons.graphic_eq,
                'DJ-k',
                'Magyar hardstyle és hardcore előadók',
                const ArtistsScreen(),
              ),
              _item(
                Icons.groups,
                'Szervezők',
                'Hazai eseményszervezők és sorozatok',
                const OrganizersScreen(),
              ),
              _item(
                Icons.queue_music_outlined,
                'Spotify Playlistek',
                'Válogatások a keményebb stílusokból',
                const SpotifyPlaylistsScreen(),
              ),
            ]),
            _section('Közösség', [
              _item(
                Icons.favorite_outline,
                'Kedvencek',
                'Mentett hírek, események és DJ-k',
                const FavoritesScreen(),
              ),
              _item(
                Icons.mark_email_unread_outlined,
                'Hírlevél',
                'Iratkozz fel a Hungarian Hardstyle híreire',
                const NewsletterScreen(),
              ),
              if (registered)
                _item(
                  Icons.people_outline,
                  'Felhasználók',
                  'Regisztrált felhasználók keresése és listája',
                  const CommunityUsersScreen(),
                ),
            ]),
            _section('Beküldés', [
              if (canArtist)
                _item(
                  Icons.person_add_alt_1,
                  'DJ beküldése',
                  'Új DJ-adatlap jóváhagyásra',
                  const ArtistSubmissionScreen(),
                ),
              if (canOrganizer)
                _item(
                  Icons.add_business,
                  'Szervező beküldése',
                  'Új szervező jóváhagyásra',
                  const OrganizerSubmissionScreen(),
                ),
              if (!canArtist && !canOrganizer)
                _notice(
                  registered
                      ? 'A DJ- és szervezőbeküldés a megfelelő szerepkörhöz kötött.'
                      : 'A beküldés csak regisztrált felhasználóknak érhető el.',
                ),
            ]),
            _section('Kapcsolat és támogatás', [
              _item(
                Icons.share_outlined,
                'Social és kapcsolat',
                'Közösségi oldalak és elérhetőségek',
                const SocialContactScreen(),
              ),
              _item(
                Icons.favorite,
                'Támogatás / Donate',
                'Segítsd a Hungarian Hardstyle munkáját',
                const DonateScreen(),
              ),
              _callback(
                Icons.bug_report_outlined,
                'Hibajelzés',
                'Hiba jelzése e-mailben, app-verzióval',
                _sendFeedback,
              ),
              _item(
                Icons.help_outline,
                'GYIK / FAQ',
                'Gyakori kérdések és válaszok',
                const FaqScreen(),
              ),
            ]),
            _section('Alkalmazás', [
              _item(
                Icons.settings_outlined,
                'Beállítások',
                'Értesítések és gyorsítótár',
                const SettingsScreen(),
              ),
              _item(
                Icons.privacy_tip_outlined,
                'Adatvédelem és GDPR',
                'Adatkezelés, megőrzés és felhasználói jogok',
                const PrivacyScreen(),
              ),
              _item(
                Icons.info_outline,
                'Az appról',
                'Verzió, kapcsolat és weboldal',
                const AboutScreen(),
              ),
              _item(
                Icons.radio,
                'Rádió szolgáltató',
                'Real Hardstyle FM',
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

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

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
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );
}
