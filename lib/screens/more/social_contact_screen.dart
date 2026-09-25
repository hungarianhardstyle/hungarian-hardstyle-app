import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/tr.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../widgets/app_text.dart';

class SocialContactScreen extends StatelessWidget {
  const SocialContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Social és kapcsolat')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080808), Color(0xFF220000), Color(0xFF080808)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const AppText(
              'Kövess minket',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _LinkTile(
              icon: Icons.facebook,
              label: tr(context, 'Facebook'),
              value: 'Hungarian Hardstyle',
              onTap: () => openSocialLink(
                context,
                'https://www.facebook.com/Hunstyle',
                title: tr(context, 'Facebook'),
              ),
            ),
            _LinkTile(
              icon: Icons.camera_alt_outlined,
              label: tr(context, 'Instagram'),
              value: '@hungarianhardstyle',
              onTap: () => openSocialLink(
                context,
                'https://www.instagram.com/hungarianhardstyle/',
                title: tr(context, 'Instagram'),
              ),
            ),
            _LinkTile(
              icon: Icons.music_note,
              label: 'TikTok',
              value: '@hungarianhardstyle',
              onTap: () => openSocialLink(
                context,
                'https://www.tiktok.com/@hungarianhardstyle',
                title: 'TikTok',
              ),
            ),
            _LinkTile(
              icon: Icons.smart_display_outlined,
              label: 'YouTube',
              value: 'Hungarian Hardstyle',
              onTap: () => openSocialLink(
                context,
                'https://www.youtube.com/@HungarianHardstyle',
                title: 'YouTube',
              ),
            ),
            const SizedBox(height: 20),
            const AppText(
              'Kapcsolat',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _LinkTile(
              icon: Icons.language,
              label: tr(context, 'Weboldal'),
              value: 'hungarianhardstyle.hu',
              onTap: () =>
                  openInAppBrowser(context, 'https://hungarianhardstyle.hu'),
            ),
            _LinkTile(
              icon: Icons.mail_outline,
              label: 'E-mail',
              value: 'info@hungarianhardstyle.hu',
              onTap: () => launchUrl(
                Uri(scheme: 'mailto', path: 'info@hungarianhardstyle.hu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE53935)),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}
