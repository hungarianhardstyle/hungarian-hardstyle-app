import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/community_provider.dart';
import '../artists/artists_screen.dart';
import '../organizers/organizers_screen.dart';
import 'about_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'social_contact_screen.dart';
import 'spotify_playlists_screen.dart';
import 'newsletter_screen.dart';
import '../submissions/artist_submission_screen.dart';
import '../submissions/organizer_submission_screen.dart';
import 'radio_provider_screen.dart';
import 'privacy_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(communityServiceProvider);
    final user = ref.watch(communityAuthProvider).valueOrNull;
    final registered = user != null && !user.isAnonymous;
    final role = service.cachedAccountRole;
    final canSubmitArtist = registered && (service.isAdmin || role == 'dj');
    final canSubmitOrganizer = registered &&
        (service.isAdmin || role == 'organizer');
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
              if (canSubmitArtist)
                _SubmissionCard(
                icon: Icons.person_add_alt_1,
                title: 'DJ beküldése',
                subtitle: 'Új DJ-adatlap jóváhagyásra',
                onTap: () => _open(context, const ArtistSubmissionScreen()),
              ),
              if (canSubmitArtist && canSubmitOrganizer)
                const SizedBox(height: 8),
              if (canSubmitOrganizer)
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
                icon: Icons.radio,
                title: 'Rádió szolgáltató',
                subtitle: 'Real Hardstyle FM',
                onTap: () => _open(context, const RadioProviderScreen()),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.mark_email_unread_outlined,
                title: 'Hírlevél',
                subtitle: 'Iratkozz fel a Hungarian Hardstyle híreire',
                onTap: () => _open(context, const NewsletterScreen()),
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
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.privacy_tip_outlined,
                title: 'Adatvédelem és GDPR',
                subtitle: 'Adatkezelés, megőrzés és felhasználói jogok',
                onTap: () => _open(context, const PrivacyScreen()),
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
