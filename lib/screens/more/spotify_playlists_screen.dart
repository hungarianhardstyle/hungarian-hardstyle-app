import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/in_app_browser.dart';

class SpotifyPlaylistsScreen extends StatelessWidget {
  const SpotifyPlaylistsScreen({super.key});

  static const _playlists = [
    ('Hungarian Hardstyle playlist', 'Csak magyar zenékkel', 'https://open.spotify.com/playlist/18nyNuPKpXRtl8YmA3lBIa'),
    ('Hardstyle Revolution – Daily Hardstyle', 'Vegyes hardstyle playlist', 'https://open.spotify.com/playlist/7L8vYEHycijxgzM1XM3Dg2'),
    ('Hardstyle Revolution – Daily Rawstyle', 'Rawstyle zenékkel', 'https://open.spotify.com/playlist/2KatMAyQhJx9ZtuYxOequl'),
    ('Hardstyle Revolution – Hard Base classics', 'Classic hardstyle lista', 'https://open.spotify.com/playlist/2prgLcrUuLFXK3UkpjuSMw'),
    ('Hardstyle Revolution label lista', 'A kiadó zenéi egy helyen', 'https://open.spotify.com/playlist/4vVJzpuRoQJ7nG817swK2l'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spotify playlisták')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: _playlists.length,
          itemBuilder: (context, index) {
            final playlist = _playlists[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 30),
                title: Text(playlist.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(playlist.$2),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openSpotify(context, playlist.$3),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSpotify(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (context.mounted) {
      await openInAppBrowser(context, url, title: 'Spotify');
    }
  }
}
