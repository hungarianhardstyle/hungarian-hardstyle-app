import 'package:flutter/material.dart';

import '../artists/artists_screen.dart';
import '../organizers/organizers_screen.dart';
import '../submissions/artist_submission_screen.dart';
import '../submissions/organizer_submission_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
                onTap: () =>
                    _open(context, const OrganizerSubmissionScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => screen),
    );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
