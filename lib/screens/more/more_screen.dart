import 'package:flutter/material.dart';

import '../../core/navigation/in_app_browser.dart';
import '../artists/artists_screen.dart';
import '../organizers/organizers_screen.dart';
import 'about_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'social_contact_screen.dart';
import 'spotify_playlists_screen.dart';
import '../submissions/artist_submission_screen.dart';
import '../submissions/organizer_submission_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _newsletterUrl = 'https://mailchi.mp/fccf4f34b297/hunhs-app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
            children: [
              const Text(
                'Több',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 22),
              _MenuCard(
                icon: Icons.graphic_eq,
                title: 'DJ-k',
                subtitle: 'Magyar hardstyle és hardcore előadók',
                onTap: () => _open(context, const ArtistsScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.groups,
                title: 'Szervezők',
                subtitle: 'Hazai eseményszervezők és sorozatok',
                onTap: () => _open(context, const OrganizersScreen()),
              ),
              const SizedBox(height: 28),
              const Text(
                'Beküldés',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _SubmissionCard(
                icon: Icons.person_add_alt_1,
                title: 'DJ beküldése',
                subtitle: 'Új DJ-adatlap jóváhagyásra',
                onTap: () => _open(context, const ArtistSubmissionScreen()),
              ),
              const SizedBox(height: 8),
              _SubmissionCard(
                icon: Icons.add_business,
                title: 'Szervező beküldése',
                subtitle: 'Új szervező jóváhagyásra',
                onTap: () => _open(context, const OrganizerSubmissionScreen()),
              ),
              const SizedBox(height: 28),
              _MenuCard(
                icon: Icons.share_outlined,
                title: 'Social és kapcsolat',
                subtitle: 'Közösségi oldalak és elérhetőségek',
                onTap: () => _open(context, const SocialContactScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.queue_music_outlined,
                title: 'Spotify Playlistek',
                subtitle: 'Öt válogatás a keményebb stílusokból',
                onTap: () => _open(context, const SpotifyPlaylistsScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.mark_email_unread_outlined,
                title: 'Hírlevél',
                subtitle: 'Iratkozz fel a Hungarian Hardstyle híreire',
                onTap: () => openInAppBrowser(
                  context,
                  _newsletterUrl,
                  title: 'Hírlevél',
                ),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.favorite_outline,
                title: 'Kedvencek',
                subtitle: 'Mentett hírek, események és DJ-k',
                onTap: () => _open(context, const FavoritesScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.settings_outlined,
                title: 'Beállítások',
                subtitle: 'Értesítések és gyorsítótár',
                onTap: () => _open(context, const SettingsScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.info_outline,
                title: 'Az appról',
                subtitle: 'Verzió, kapcsolat és weboldal',
                onTap: () => _open(context, const AboutScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE53935),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SubmissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
